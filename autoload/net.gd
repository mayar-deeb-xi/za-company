extends Node
## Online co-op's one door to the network (DESIGN.md's Multiplayer, M2): host a
## room, join one by its code, leave, and keep the party's ROSTER - who is in
## it, as which character, how far from the host and by which route - until the
## host starts the run.
##
## ## The transport is chosen here and nowhere else
##
## Everything above this file talks to Godot's MultiplayerAPI and never asks
## which wire it is on. Online is WebRTC, introduced through our signaling
## service (server/signaling) and direct-first with the relay as the fallback
## (net/rtc_link.gd); `host_local()` / `join_local()` are ENet on an address and
## a port, which is the same API with none of the internet in it - what the
## suites run on, and a LAN game if one is ever wanted. Offline - every solo run
## - is Godot's own OfflineMultiplayerPeer, which is a host with no guests.
##
## ## The host is the truth
##
## A star: guests talk to the host and to nobody else. The host keeps the
## roster and sends the whole of it to everybody whenever it changes and once a
## second besides, with each guest's ping (net/ping.gd) - four rows of it is
## nothing, and a guest that missed one has the next. A guest is in the party
## from the moment the host has its hello, which carries this file's `WIRE`:
## two builds that do not speak the same game are refused there, the way the
## signaling service refuses a client on another `PROTOCOL`.
##
## ## What it does NOT do
##
## It changes no scene and spawns nothing. `run_started` hands the roster to
## whoever listens - ui/lobby/ - and game.gd builds the party from it, so this
## file stays testable without a game, and two of it can live in one process
## (tests/test_net.gd puts each in a SubViewport with its own MultiplayerAPI,
## which is why nothing here reaches for the tree's root API by name).
##
## Preloaded by path like every other cross-feature script here - global class
## names live in an editor-written cache a fresh headless checkout does not have.

signal hosted(code: String)
## This machine is a guest in a party: the host has its hello.
signal joined
signal roster_changed
## Hosting or joining did not happen; `reason` is the signaling service's code
## (`no_such_room`, `room_full`, `started`, `version`...) or one of this
## file's (`no_server`, `unreachable`, `no_route`).
signal failed(reason: String)
## The party is over for this machine: `host_left` is the one that matters.
signal ended(reason: String)
## The host pressed START. Everybody's machine gets the same rows in the same
## order, which is the party's order.
signal run_started(rows: Array)
## The host only: a guest's game scene is up and can be spoken to (`arrived()`).
signal peer_arrived(peer: int)
## The host only: a guest has left the party, mid-run or not.
signal peer_left(peer: int)

const SignalClient := preload("res://autoload/net/signal_client.gd")
const RtcLink := preload("res://autoload/net/rtc_link.gd")
const Ping := preload("res://autoload/net/ping.gd")
const Heads := preload("res://game/heads.gd")

## The signaling service's protocol (server/signaling/main.py), which refuses
## any other with `version`.
const PROTOCOL := 2
## The game's own: what a guest says in its hello, and what the host refuses
## when it differs. Bump it with anything that changes what the two ends say to
## each other once they are connected. 2 is M3: the run itself in step
## (game/sync/), which a build from before it would join and then not follow.
const WIRE := 2
## Ours (server/README.md). The live service is what a RELEASE talks to; dev's
## own copy is what dev builds and the editor talk to - see signaling_url().
const LIVE_SIGNALING := "wss://za-company.mayar-deeb.dev"
const DEV_SIGNALING := "wss://dev.za-company.mayar-deeb.dev"
## How long the host leaves a refused guest connected, so the refusal it is
## sent arrives before the line goes.
const REFUSE_GRACE := 0.5

enum State { OFFLINE, OPENING, LOBBY, IN_RUN }

var state := State.OFFLINE
## The wire this machine says it speaks in its hello. `WIRE`, always - a var
## only so tests/test_net.gd can be a build that speaks another one.
var wire := WIRE

## peer id -> {peer, name, character, route, ping}. The host's is the truth and
## a guest's is the last copy it was sent.
var _rows := {}
## The ids in the order they came, the host's first: the party's order. Kept
## apart from the ids themselves because ENet's are random.
var _order: Array[int] = []
var _me := {"name": "", "character": ""}
var _code := ""
var _signal: SignalClient = null
var _mp: MultiplayerPeer = null
var _links := {}  # peer id -> RtcLink, online only
var _ice := {}
var _force_relay := false
var _local := false
var _clock := 0.0
var _ping: Node
## The host only: the guests whose game scene is up - see `arrived()`.
var _arrived := {}


func _ready() -> void:
	# Running whatever is paused: the pause menu stops this machine's game, not
	# the line to everybody else's.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ping = Ping.new()
	_ping.name = "Ping"
	add_child(_ping)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(delta: float) -> void:
	if _signal != null:
		_signal.poll()
	for link: RtcLink in _links.values():
		link.poll()
	if is_host() and state != State.OFFLINE:
		_clock += delta
		if _clock >= Ping.INTERVAL:
			_clock = 0.0
			var moved := false
			for id: int in _rows:
				if id != 1:
					var ms: int = _ping.call("ms", id)
					moved = moved or ms != int(_rows[id].get("ping", -1))
					_rows[id]["ping"] = ms
			# This machine's own screen too, not only everybody else's.
			if moved:
				roster_changed.emit()
			_broadcast()


# --- the questions --------------------------------------------------------------


func is_online() -> bool:
	return state != State.OFFLINE


func is_host() -> bool:
	return state != State.OFFLINE and _mp != null and multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id() if state != State.OFFLINE else 1


## The room's code, or "" when there is none (offline, or a local game).
func code() -> String:
	return _code


## The party in its order - the host first, then guests in the order they
## came - as copies, so a caller cannot edit the truth.
func roster() -> Array:
	var out := []
	for id in _order:
		if _rows.has(id):
			out.append((_rows[id] as Dictionary).duplicate())
	return out


## Where to send a second machine: the signaling's own domain, which also
## serves the web build, with the code in the address (ui/web_entry/ reads it).
## A phone cannot type into the web build, so for a phone this IS the way in.
func join_link() -> String:
	if _code == "":
		return ""
	var url := signaling_url()
	var secure := url.begins_with("wss://")
	var host := url.trim_prefix("wss://").trim_prefix("ws://").trim_suffix("/")
	return "%s://%s/#join=%s" % ["https" if secure else "http", host, _code]


## Which signaling service this build talks to, decided in one place:
##
## - `--signal=URL` on the command line, for a service run by hand;
## - a web build, the page's own host - the Caddyfile serves signaling beside
##   the game, so the live site finds the live service and the dev site dev's;
## - a RELEASE desktop build (`packaged`, and not `dev`), the live service;
## - everything else - a dev build, and the editor, which is develop - dev's.
static func signaling_url() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--signal="):
			return arg.trim_prefix("--signal=")
	if OS.has_feature("web"):
		var page := String(JavaScriptBridge.eval(
			"window.location.protocol + '//' + window.location.host", true))
		if page.begins_with("https://"):
			return "wss://" + page.trim_prefix("https://")
		return DEV_SIGNALING
	if OS.has_feature("packaged") and not OS.has_feature("dev"):
		return LIVE_SIGNALING
	return DEV_SIGNALING


# --- hosting and joining ------------------------------------------------------


## Open a room on the signaling service. `hosted` comes with its code.
func host(player_name: String, character: String) -> void:
	if not _begin(player_name, character):
		return
	_open_signaling()
	_signal.send({"op": "host", "v": PROTOCOL, "name": player_name, "max": Heads.MAX_PARTY})


## Join the room with this code. `joined` once the host has us, `failed` if it
## never does. `force_relay` skips the direct attempt - the relay, on purpose.
func join(room_code: String, player_name: String, character: String,
		force_relay := false) -> void:
	if not _begin(player_name, character):
		return
	_force_relay = force_relay
	_open_signaling()
	_signal.send({"op": "join", "v": PROTOCOL, "name": player_name,
		"code": room_code.strip_edges().to_upper()})


## Host on a port with ENet: no signaling, no code, no relay.
func host_local(port: int, player_name: String, character: String) -> Error:
	if not _begin(player_name, character):
		return ERR_ALREADY_IN_USE
	var enet := ENetMultiplayerPeer.new()
	var err := enet.create_server(port, Heads.MAX_PARTY - 1)
	if err != OK:
		_reset()
		return err
	_local = true
	_set_peer(enet)
	_open_lobby("HOST")
	hosted.emit("")
	return OK


func join_local(address: String, port: int, player_name: String, character: String) -> Error:
	if not _begin(player_name, character):
		return ERR_ALREADY_IN_USE
	var enet := ENetMultiplayerPeer.new()
	var err := enet.create_client(address, port)
	if err != OK:
		_reset()
		return err
	_local = true
	_set_peer(enet)
	return OK


## Out of the party, from either end. The host leaving ends it for everybody:
## the signaling service tells the guests, and so does the line going down.
func leave() -> void:
	if state == State.OFFLINE:
		return
	if _signal != null:
		_signal.send({"op": "leave"})
	_reset()


## The host only: everybody into the run, in the roster's order. The room is
## shut to new joins first - a party is joined in the lobby, never mid-run.
func start_run() -> void:
	if not is_host() or state != State.LOBBY:
		return
	if _signal != null:
		_signal.send({"op": "start"})
	# Only who has said hello: somebody still connecting has no character yet,
	# and arrives to be told `started` like anybody else who came too late.
	var ready := roster().filter(func(row: Dictionary) -> bool:
		return row.get("route", "...") != "..." and row.get("character", "") != "")
	_begin_run.rpc(ready)


## Said by the run's scene (game/sync/) once it is built, on every machine.
##
## Two machines load the game at their own speed, and a message sent to a node
## that is not there yet is lost - with an error on the far end for it. So the
## host does not speak to a guest's game until that guest has said this, and
## the saying goes through HERE because this node is the one thing both ends
## are certain to have whatever scene either is on.
func arrived() -> void:
	if state == State.IN_RUN and not is_host():
		_arrived_at_host.rpc_id(1)


## The host only: the guests whose game is up, in the party's order.
func arrived_peers() -> Array[int]:
	var out: Array[int] = []
	for id in _order:
		if _arrived.has(id):
			out.append(id)
	return out


@rpc("any_peer", "call_remote", "reliable")
func _arrived_at_host() -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if _rows.has(id) and not _arrived.has(id):
		_arrived[id] = true
		peer_arrived.emit(id)


# --- the roster over the wire -----------------------------------------------------


## A guest's first word once connected: which game it speaks and who it is.
@rpc("any_peer", "call_remote", "reliable")
func _hello(their_wire: int, player_name: String, character: String, route: String) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if their_wire != WIRE:
		_refuse(id, "version")
		return
	if state == State.IN_RUN:
		_refuse(id, "started")
		return
	var row: Dictionary = _rows.get(id, {"peer": id, "ping": -1})
	if not _order.has(id):
		_order.append(id)
	row["name"] = _clean_name(player_name)
	row["character"] = character
	# The host's own link knows the route; a local guest says LAN.
	if not row.has("route") or row["route"] == "...":
		row["route"] = route
	_rows[id] = row
	roster_changed.emit()
	_broadcast()


@rpc("authority", "call_remote", "reliable")
func _roster(rows: Array) -> void:
	var was_in := _rows.has(my_id())
	_rows.clear()
	_order.clear()
	for row: Dictionary in rows:
		_rows[int(row["peer"])] = row
		_order.append(int(row["peer"]))
	if not was_in and _rows.has(my_id()) and state == State.OPENING:
		state = State.LOBBY
		joined.emit()
	roster_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _refused(reason: String) -> void:
	# Deferred, like every reset that starts inside the MultiplayerAPI's own
	# poll: the peer is not swapped out from under the packet being read.
	_fail.call_deferred(reason)


@rpc("authority", "call_local", "reliable")
func _begin_run(rows: Array) -> void:
	state = State.IN_RUN
	run_started.emit(rows)


func _broadcast() -> void:
	if is_host() and not multiplayer.get_peers().is_empty():
		_roster.rpc(roster())


func _refuse(id: int, reason: String) -> void:
	_refused.rpc_id(id, reason)
	get_tree().create_timer(REFUSE_GRACE).timeout.connect(func() -> void:
		if _mp != null and multiplayer.get_peers().has(id):
			_mp.disconnect_peer(id))


# --- the MultiplayerAPI's side --------------------------------------------------


## A peer the transport has connected. Nothing happens until it says hello -
## the roster is who is in the PARTY, not who is on the line.
func _on_peer_connected(_id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	if is_host():
		_drop(id)


func _on_connected_to_server() -> void:
	var route := "LAN"
	if not _local:
		var link: RtcLink = _links.get(1)
		route = link.route if link != null else ""
	_hello.rpc_id(1, wire, _me["name"], _me["character"], route)


func _on_connection_failed() -> void:
	if state == State.OPENING:
		_fail.call_deferred("unreachable")


func _on_server_disconnected() -> void:
	if state != State.OFFLINE:
		_end.call_deferred("host_left")


# --- signaling ------------------------------------------------------------------


func _open_signaling() -> void:
	_signal = SignalClient.new()
	_signal.message.connect(_on_signal)
	_signal.closed.connect(_on_signal_closed)
	var err := _signal.open(signaling_url())
	if err != OK:
		_fail("no_server")


func _on_signal(msg: Dictionary) -> void:
	match String(msg.get("op", "")):
		"hosted":
			_code = String(msg["code"])
			_ice = msg.get("ice", {})
			var rtc := WebRTCMultiplayerPeer.new()
			rtc.create_server()
			_set_peer(rtc)
			_open_lobby("HOST")
			hosted.emit(_code)
		"joined":
			_code = String(msg["code"])
			_ice = msg.get("ice", {})
			var rtc := WebRTCMultiplayerPeer.new()
			rtc.create_client(int(msg["id"]))
			_set_peer(rtc)
			_add_link(1, true)
		"peer":
			# Somebody is on their way in: a row now, so the lobby can say so,
			# filled in when their hello arrives.
			var id := int(msg["id"])
			_rows[id] = {"peer": id, "name": _clean_name(String(msg.get("name", ""))),
				"character": "", "route": "...", "ping": -1}
			_order.append(id)
			_add_link(id, false)
			roster_changed.emit()
		"gone":
			_drop(int(msg["id"]))
		"signal":
			var link: RtcLink = _links.get(int(msg.get("from", 0)))
			if link != null:
				link.receive(msg.get("data", {}))
		"closed":
			if state != State.OFFLINE:
				_end("host_left")
		"error":
			# Before we are in a party a refusal is the end of trying; after, it
			# is a message we sent that the service did not like, and nothing
			# the party needs to hear about.
			if state == State.OPENING:
				_fail(String(msg.get("reason", "refused")))


func _on_signal_closed(_close_code: int, _reason: String) -> void:
	# Only fatal before the party is made: once connected, game traffic never
	# touches the signaling service, and a host whose socket drops simply
	# takes nobody new.
	if state == State.OPENING:
		_fail("no_server")


func _add_link(peer_id: int, offerer: bool) -> void:
	var link := RtcLink.new(_mp as WebRTCMultiplayerPeer, peer_id, _ice, offerer,
		offerer and _force_relay)
	_links[peer_id] = link
	link.outgoing.connect(func(data: Dictionary) -> void:
		if _signal != null:
			_signal.send({"op": "signal", "to": peer_id, "data": data}))
	link.connected.connect(_on_linked.bind(peer_id))
	link.failed.connect(_on_link_failed.bind(peer_id))
	link.start()


func _on_linked(route: String, peer_id: int) -> void:
	if is_host() and _rows.has(peer_id):
		_rows[peer_id]["route"] = route
		roster_changed.emit()
		_broadcast()


func _on_link_failed(_reason: String, peer_id: int) -> void:
	if is_host():
		_drop(peer_id)
	elif state == State.OPENING:
		_fail("no_route")


# --- plumbing ---------------------------------------------------------------------


func _begin(player_name: String, character: String) -> bool:
	if state != State.OFFLINE:
		push_warning("Net: already in a party - leave() first")
		return false
	_me = {"name": _clean_name(player_name), "character": character}
	state = State.OPENING
	return true


func _set_peer(peer: MultiplayerPeer) -> void:
	_mp = peer
	multiplayer.multiplayer_peer = peer


func _open_lobby(route: String) -> void:
	_rows[1] = {"peer": 1, "name": _me["name"], "character": _me["character"],
		"route": route, "ping": 0}
	_order = [1]
	state = State.LOBBY
	roster_changed.emit()


func _drop(id: int) -> void:
	var link: RtcLink = _links.get(id)
	if link != null:
		link.close()
	_links.erase(id)
	_ping.call("forget", id)
	_order.erase(id)
	_arrived.erase(id)
	if _rows.erase(id):
		roster_changed.emit()
		_broadcast()
		peer_left.emit(id)


## Hosting or joining did not happen.
func _fail(reason: String) -> void:
	_reset()
	failed.emit(reason)


## The party ended under this machine.
func _end(reason: String) -> void:
	_reset()
	ended.emit(reason)


## Back to offline, whatever state this was in. Says nothing: the caller knows
## why, and emits whatever the reason was.
func _reset() -> void:
	for link: RtcLink in _links.values():
		link.close()
	_links.clear()
	if _signal != null:
		_signal.close()
		_signal = null
	if _mp != null:
		_mp.close()
		_mp = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_rows.clear()
	_order.clear()
	_arrived.clear()
	_code = ""
	_ice = {}
	_force_relay = false
	_local = false
	_clock = 0.0
	state = State.OFFLINE
	roster_changed.emit()


## The signaling service's rule, applied on the wire's other road too: a local
## guest never passed through it.
static func _clean_name(value: String) -> String:
	var clean := ""
	for ch in value:
		if ch.unicode_at(0) >= 32:
			clean += ch
	clean = clean.strip_edges().left(24)
	return clean if clean != "" else "Player"
