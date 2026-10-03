extends "res://tests/helpers.gd"
## The `Net` autoload (DESIGN.md's Multiplayer, M2): a host and its guests in
## ONE process, each Net in a SubViewport of its own with a MultiplayerAPI of
## its own, talking over ENet on localhost - the same API online play uses,
## with none of the internet in it.
##
## - The lobby: hosting opens a party of one, a guest's hello puts them in it,
##   and both ends hold the same roster in the same order - names, characters,
##   the guest's route - and the host measures a ping that reaches the guest.
## - The refusals: a build speaking another WIRE is turned away with `version`
##   and the party is untouched; once the run has started a late arrival is
##   turned away with `started`.
## - START: everybody hears `run_started` with the same rows.
## - Leaving: a guest leaving is a row gone at the host; the host leaving is
##   `host_left` at the guest.
## - The host's say over the room: the public switch, and KICK - their seat
##   empty at once, and `kicked` at their end.
## - Which signaling service a build talks to, and the join link it hands out.
##
## Driven by WAITS rather than frame numbers: a connection takes as long as it
## takes, so every step acts once and then gives its predicate a deadline. One
## step at a time; a check fails at its deadline rather than hanging the run.

const NET := "res://autoload/net.gd"
## Out of the way of anything a developer runs. A second one for the second
## party, because a closed ENet port is not always free again at once.
const PORT := 47911
const PORT_2 := 47912
const DEADLINE := 300

var _net_script: GDScript
var _host: Node
var _guest: Node
var _late: Node
var _heard := {}
var _steps: Array[Callable] = []
var _at := 0
var _waiting := Callable()
var _label := ""
var _since := 0


func _tick(frame: int) -> void:
	if frame == 2:
		_net_script = load(NET)
		_steps = [_host_one, _join_one, _ping_one, _wrong_wire, _start, _late_comer,
			_host_leaves, _host_two, _public_switch, _kick, _kicked_out, _come_back,
			_guest_leaves, _addresses]
	if frame < 3:
		return
	if _waiting.is_valid():
		if _waiting.call():
			_check(_label, true)
			_waiting = Callable()
		elif frame - _since > DEADLINE:
			_check(_label + " (timed out)", false)
			_waiting = Callable()
		return
	if _at >= _steps.size():
		_finish()
		return
	_since = frame
	_steps[_at].call()
	_at += 1


## After the action, wait for `cond` - the check passes when it holds, and
## fails at the deadline.
func _wait(label: String, cond: Callable) -> void:
	_label = label
	_waiting = cond


## A Net of its own, in a SubViewport of its own, with a MultiplayerAPI of its
## own - and named Net there, so its RPC paths match the other end's.
func _spawn_net(view_name: String) -> Node:
	var view := SubViewport.new()
	view.name = view_name
	root.add_child(view)
	set_multiplayer(SceneMultiplayer.new(), view.get_path())
	var net: Node = _net_script.new()
	net.name = "Net"
	view.add_child(net)
	for event in ["hosted", "joined", "failed", "ended", "run_started", "peer_left"]:
		net.connect(event, _hear.bind(view_name, event))
	return net


## Gone, with the MultiplayerAPI its view was given taken back first - a
## SceneMultiplayer left registered against a freed path polls nothing forever.
func _drop_view(net: Node) -> void:
	var view := net.get_parent()
	set_multiplayer(null, view.get_path())
	view.queue_free()


## Every signal a Net emits, latched by who and what, with its first argument.
func _hear(a = null, b = null, c = null) -> void:
	# Signals carry 0 or 1 arguments, then the two bound ones.
	var args := [a, b, c].filter(func(v) -> bool: return v != null)
	var event: String = args[args.size() - 1]
	var who: String = args[args.size() - 2]
	_heard["%s:%s" % [who, event]] = args[0] if args.size() == 3 else true


func _heard_of(who: String, event: String) -> Variant:
	return _heard.get("%s:%s" % [who, event])


# --- the steps --------------------------------------------------------------------


func _host_one() -> void:
	_host = _spawn_net("HostView")
	var err: int = _host.call("host_local", PORT, "Mayar", "reem")
	_check("host: ENet opens on localhost (%s)" % error_string(err), err == OK)
	var rows: Array = _host.call("roster")
	_check("host: a party of one, the host, HOST (%s)" % [rows],
		rows.size() == 1 and rows[0]["name"] == "Mayar" and rows[0]["route"] == "HOST"
			and rows[0]["character"] == "reem")
	_check("host: in the lobby, and said so",
		_host.get("state") == 2 and _heard_of("HostView", "hosted") != null)


func _join_one() -> void:
	_guest = _spawn_net("GuestView")
	_guest.call("join_local", "127.0.0.1", PORT, "Ivo\u0007", "anas")
	_wait("join: the guest is in the party once the host has its hello",
		func() -> bool: return _heard_of("GuestView", "joined") != null)


func _ping_one() -> void:
	var host_rows: Array = _host.call("roster")
	var guest_rows: Array = _guest.call("roster")
	_check("roster: both ends hold the same party in the same order",
		host_rows.size() == 2 and _ids(host_rows) == _ids(guest_rows)
			and int(host_rows[0]["peer"]) == 1)
	var row: Dictionary = host_rows[1] if host_rows.size() > 1 else {}
	_check("roster: the guest's name (cleaned), character and route (%s)" % [row],
		row.get("name") == "Ivo" and row.get("character") == "anas" and row.get("route") == "LAN")
	_check("roster: the guest is not the host",
		_guest.call("is_host") == false and _host.call("is_host") == true)
	_wait("ping: the host measures one, and the guest is sent it",
		func() -> bool:
			var mine: Array = _guest.call("roster")
			return mine.size() == 2 and int(mine[1]["ping"]) >= 0)


func _wrong_wire() -> void:
	_late = _spawn_net("WrongView")
	_late.set("wire", 99)
	_late.call("join_local", "127.0.0.1", PORT, "Old", "mayar")
	_wait("wire: a build on another wire is refused with `version`",
		func() -> bool: return (_heard_of("WrongView", "failed") == "version"
			and _late.get("state") == 0))


func _start() -> void:
	_check("wire: and the party never had them (%d)" % (_host.call("roster") as Array).size(),
		(_host.call("roster") as Array).size() == 2)
	_drop_view(_late)
	_host.call("start_run")
	_wait("start: everybody hears it, with the same rows",
		func() -> bool:
			var a = _heard_of("HostView", "run_started")
			var b = _heard_of("GuestView", "run_started")
			return a is Array and b is Array and _ids(a) == _ids(b) and (a as Array).size() == 2)


func _late_comer() -> void:
	_check("start: both are in the run",
		_host.get("state") == 3 and _guest.get("state") == 3)
	_late = _spawn_net("LateView")
	_late.call("join_local", "127.0.0.1", PORT, "Late", "omar")
	_wait("start: a party is joined in the lobby - a late arrival is refused with `started`",
		func() -> bool: return _heard_of("LateView", "failed") == "started")


func _host_leaves() -> void:
	_drop_view(_late)
	_host.call("leave")
	_wait("leave: the host going is `host_left` at the guest",
		func() -> bool: return (_heard_of("GuestView", "ended") == "host_left"
			and _guest.get("state") == 0))


func _host_two() -> void:
	_check("leave: the host is offline again", _host.get("state") == 0)
	_heard.clear()
	_host.call("host_local", PORT_2, "Mayar", "reem")
	_guest.call("join_local", "127.0.0.1", PORT_2, "Ivo", "anas")
	_wait("again: a second party on the same two Nets",
		func() -> bool: return _heard_of("GuestView", "joined") != null)


func _public_switch() -> void:
	_check("public: a room is private unless the host opens it",
		_host.call("is_public") == false and _guest.call("is_public") == false)
	_host.call("set_public", true)
	_check("public: the host opens it", _host.call("is_public") == true)
	_guest.call("set_public", true)
	_check("public: a guest cannot", _guest.call("is_public") == false)
	_host.call("set_public", false)
	_check("public: and the host makes it private again", _host.call("is_public") == false)


func _kick() -> void:
	_guest.call("kick", 1)
	_check("kick: a guest kicks nobody", (_host.call("roster") as Array).size() == 2)
	_host.call("kick", 1)
	_check("kick: the host cannot kick itself", (_host.call("roster") as Array).size() == 2)
	var guest_id: int = _guest.call("my_id")
	_host.call("kick", guest_id)
	_check("kick: their seat is empty at once (%d)" % (_host.call("roster") as Array).size(),
		(_host.call("roster") as Array).size() == 1 and _heard_of("HostView", "peer_left") == guest_id)
	_wait("kick: and they are told why",
		func() -> bool: return (_heard_of("GuestView", "failed") == "kicked"
			and _guest.get("state") == 0))


func _kicked_out() -> void:
	_wait("kick: the line to them goes too",
		func() -> bool: return (_host.get("multiplayer") as MultiplayerAPI).get_peers().is_empty())


## There is no signaling service on ENet to remember them by, so on a LAN they
## may come back; online the service refuses their address (its own suite).
func _come_back() -> void:
	_heard.erase("GuestView:joined")
	_guest.call("join_local", "127.0.0.1", PORT_2, "Ivo", "anas")
	_wait("kick: on a LAN they may come back",
		func() -> bool: return _heard_of("GuestView", "joined") != null)


func _guest_leaves() -> void:
	_guest.call("leave")
	_wait("leave: a guest going is a row gone at the host",
		func() -> bool: return (_host.call("roster") as Array).size() == 1)


func _addresses() -> void:
	_check("leave: and the guest is offline", _guest.get("state") == 0)
	_host.call("leave")
	# Not packaged, not web, no --signal: the editor's answer, which is dev's.
	_check("signaling: an unpackaged build talks to dev's service (%s)"
		% _host.call("signaling_url"),
		_host.call("signaling_url") == _net_script.get_script_constant_map()["DEV_SIGNALING"])
	_check("link: no room, no link", _host.call("join_link") == "")
	_host.set("_code", "K7Q2PX")
	_check("link: a code is a page on the same domain (%s)" % _host.call("join_link"),
		_host.call("join_link") == "https://dev.za-company.mayar-deeb.dev/#join=K7Q2PX")
	_host.set("_code", "")
	# Godot's bias is minutes EAST of UTC, which is the sign the list prints.
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	_check("zone: a room says its clock's minutes from UTC (%d)" % _host.call("zone_minutes"),
		_host.call("zone_minutes") == bias)


static func _ids(rows: Array) -> Array:
	return rows.map(func(row) -> int: return int(row["peer"]))
