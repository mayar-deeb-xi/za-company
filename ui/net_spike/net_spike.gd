extends Control
## M0's proving ground (DESIGN.md, Multiplayer): host or join by code through
## server/, connect direct-or-relay, and show each player's ping and route the
## way the real scoreboard will. A development screen and nothing else - no
## game, no lobby - deleted once M0 is signed off, when signal_client.gd,
## rtc_link.gd and ping.gd move into the `Net` autoload for M2.
##
## It lives in ui/ rather than tools/ because it SHIPS, in the web build only
## and only behind an address nobody is sent to: ui/web_entry/ opens it for
## https://DOMAIN/#nettest, and https://DOMAIN/#join=CODE opens it and joins
## that room - which is how a phone joins, since a phone cannot type into the
## web build. The host shows that link and copies it. A browser is the second
## machine without installing anything, and a phone on mobile data is the
## second network; hosting from the editor keeps the desktop plugin on the line.
##
## Run it in two copies of the game on two machines (F6 in the editor):
##   <godot> --path . res://ui/net_spike/net_spike.tscn
## or headless, which is how it is checked on one machine:
##   ... -- --signal=ws://127.0.0.1:8765 --host --quit-after=15
##   ... -- --signal=ws://127.0.0.1:8765 --join=CODE --quit-after=12
## Add --force-relay on the guest (or `&relay` after the code in the link) to
## skip the direct attempt, which is how the relay is proved on purpose rather
## than waited for.

const SignalClient := preload("res://autoload/net/signal_client.gd")
const RtcLink := preload("res://autoload/net/rtc_link.gd")

## The party size is the game's (game/heads.gd's MAX_PARTY, the ONE place it is
## written down), so the spike opens a room the size a real party is; the
## server only ever caps it.
const Heads := preload("res://game/heads.gd")
const PROTOCOL := 1
const SETTINGS := &"online"
## Ours (server/README.md). On the web the page's own host wins, so a build
## served from anywhere else talks to the signaling beside it.
const SERVER := "wss://za-company.mayar-deeb.dev"

@onready var _ping: Node = $Ping

var _signal: SignalClient
var _mp: WebRTCMultiplayerPeer
var _links := {}  # peer id -> RtcLink
var _roster := {}  # peer id -> {name, route, ms}; the host's is the truth
var _ice := {}  # {stun, turn} as the signaling service handed them out
## Off for a scripted run, so a test's localhost URL never becomes the
## developer's saved server.
var _remember := true
## Latched for the headless verdict: a guest that has since left still counts.
var _pinged := false
var _my_id := 0
var _quit_at := -1.0
var _shown_clock := 0.0

var _url: LineEdit
var _name: LineEdit
var _code: LineEdit
var _relay: CheckBox
var _status: Label
var _link: Label
var _copy: Button
var _join_link := ""
var _table: Label
var _log: Label
var _lines: PackedStringArray = []


func _ready() -> void:
	_build_ui()
	var args := _args()
	_remember = not args.has("signal")
	_url.text = args.get("signal", Settings.get_value(SETTINGS, &"signal_url", _default_server()))
	# Whoever arrives by a link cannot type a name on a phone.
	var nobody := "Guest" if args.has("join") else "Player"
	_name.text = args.get("name", Settings.get_value(SETTINGS, &"name", nobody))
	_relay.button_pressed = args.has("force-relay")
	if args.has("quit-after"):
		_quit_at = float(args["quit-after"])
	if args.has("host"):
		_host()
	elif args.has("join"):
		_code.text = args["join"]
		_join()


func _process(delta: float) -> void:
	if _signal != null:
		_signal.poll()
	for link: RtcLink in _links.values():
		link.poll()
	if multiplayer.multiplayer_peer is WebRTCMultiplayerPeer and multiplayer.is_server():
		_shown_clock += delta
		if _shown_clock >= 1.0:
			_shown_clock = 0.0
			for id: int in _roster:
				if id != 1:
					_roster[id]["ms"] = _ping.call("ms", id)
					_pinged = _pinged or int(_roster[id]["ms"]) >= 0
			_show_roster.rpc(_roster)
			_show_roster(_roster)
	if _quit_at >= 0.0:
		_quit_at -= delta
		if _quit_at < 0.0:
			_finish()


# --- hosting and joining -----------------------------------------------------

func _host() -> void:
	if not _connect_signal():
		return
	_signal.send({"op": "host", "v": PROTOCOL, "name": _name.text, "max": Heads.MAX_PARTY})
	_say("asking %s for a room" % _url.text)


func _join() -> void:
	if _code.text.strip_edges().is_empty():
		_say("type the host's code first")
		return
	if not _connect_signal():
		return
	_signal.send({"op": "join", "v": PROTOCOL, "name": _name.text, "code": _code.text})
	_say("joining %s" % _code.text.to_upper())


func _connect_signal() -> bool:
	if _signal != null:
		_say("already connected - restart the screen to try again")
		return false
	if _remember:
		Settings.set_value(SETTINGS, &"signal_url", _url.text)
		Settings.set_value(SETTINGS, &"name", _name.text)
	_signal = SignalClient.new()
	_signal.message.connect(_on_signal)
	_signal.closed.connect(func(code: int, reason: String):
		_say("signaling closed (%d %s)" % [code, reason]))
	var err := _signal.open(_url.text)
	if err != OK:
		_say("cannot open %s: %s" % [_url.text, error_string(err)])
		_signal = null
		return false
	return true


func _on_signal(msg: Dictionary) -> void:
	match String(msg.get("op", "")):
		"hosted":
			_my_id = 1
			_mp = WebRTCMultiplayerPeer.new()
			_mp.create_server()
			multiplayer.multiplayer_peer = _mp
			_roster[1] = {"name": _name.text, "route": "HOST", "ms": 0}
			_code.text = msg["code"]
			_status.text = "HOSTING - code %s" % msg["code"]
			_say("room %s open; give a friend the code" % msg["code"])
			_ice = msg["ice"]
			_show_link(String(msg["code"]))
		"joined":
			_my_id = int(msg["id"])
			_mp = WebRTCMultiplayerPeer.new()
			_mp.create_client(_my_id)
			multiplayer.multiplayer_peer = _mp
			_status.text = "CONNECTING to %s..." % msg["host"]
			_say("in room %s as peer %d" % [msg["code"], _my_id])
			_ice = msg["ice"]
			_add_link(1, true)
		"peer":
			var id := int(msg["id"])
			_roster[id] = {"name": String(msg["name"]), "route": "...", "ms": -1}
			_say("%s is connecting" % msg["name"])
			_add_link(id, false)
		"gone":
			_drop(int(msg["id"]))
		"signal":
			var link: RtcLink = _links.get(int(msg["from"]))
			if link != null:
				link.receive(msg["data"])
		"closed":
			_status.text = "THE HOST LEFT"
			_say("room closed: %s" % msg.get("reason", ""))
		"error":
			_say("refused: %s" % msg.get("reason", "?"))


func _add_link(peer_id: int, offerer: bool) -> void:
	var link := RtcLink.new(_mp, peer_id, _ice, offerer, offerer and _relay.button_pressed)
	_links[peer_id] = link
	link.outgoing.connect(func(data: Dictionary):
		_signal.send({"op": "signal", "to": peer_id, "data": data}))
	link.connected.connect(_on_linked.bind(peer_id))
	link.failed.connect(func(reason: String):
		_say("could not reach peer %d: %s" % [peer_id, reason]))
	link.start()
	if offerer and _relay.button_pressed:
		_say("forcing the relay (test)")


func _on_linked(route: String, peer_id: int) -> void:
	if _my_id == 1:
		_roster[peer_id]["route"] = route
		var who: String = _roster[peer_id]["name"]
		_say("%s connected %s" % [who, route])
		if route == "RELAY":
			_say("! %s is on the relay - expect a higher ping" % who)
	else:
		_status.text = "CONNECTED %s" % route
		_say("connected to the host %s" % route)
		if route == "RELAY":
			_say("! Connected through relay - expect higher ping")


func _drop(peer_id: int) -> void:
	var link: RtcLink = _links.get(peer_id)
	if link != null:
		link.close()
	_links.erase(peer_id)
	_ping.call("forget", peer_id)
	if _roster.has(peer_id):
		_say("%s left" % _roster[peer_id]["name"])
		_roster.erase(peer_id)


# --- the scoreboard ------------------------------------------------------------

@rpc("authority", "call_remote", "unreliable")
func _show_roster(rows: Dictionary) -> void:
	_roster = rows
	var text := "%-16s %7s  %s\n" % ["PLAYER", "PING", "ROUTE"]
	var ids := rows.keys()
	ids.sort()
	for id in ids:
		var row: Dictionary = rows[id]
		var ms := int(row.get("ms", -1))
		var shown := "HOST" if int(id) == 1 else ("..." if ms < 0 else "%d ms" % ms)
		var mark := " <" if int(id) == _my_id else ""
		text += "%-16s %7s  %s%s\n" % [String(row["name"]).left(16), shown, row["route"], mark]
	_table.text = text
	var mine: Dictionary = rows.get(_my_id, {})
	if _my_id > 1 and mine.has("ms") and int(mine["ms"]) >= 0:
		var ms := int(mine["ms"])
		_status.text = "CONNECTED %s - %d ms" % [mine.get("route", ""), ms]
		_status.add_theme_color_override(&"font_color", _ping_colour(ms))


static func _ping_colour(ms: int) -> Color:
	if ms < 60:
		return Color("6fdc6f")
	if ms < 120:
		return Color("e8b84a")
	return Color("e85a4a")


## The headless run's verdict, for the one-machine check: a host passes with a
## guest on the line and a ping measured, a guest passes connected.
func _finish() -> void:
	var ok := false
	if _my_id == 1:
		ok = _pinged
		print("SPIKE host roster=", _roster)
	else:
		var link: RtcLink = _links.get(1)
		ok = link != null and link.route != ""
		print("SPIKE guest route=", link.route if link else "none", " roster=", _roster)
	print("SPIKE ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


# --- plumbing ---------------------------------------------------------------------

func _say(line: String) -> void:
	print("[spike] ", line)
	_lines.append(line)
	if _lines.size() > 9:
		_lines = _lines.slice(_lines.size() - 9)
	_log.text = "\n".join(_lines)


static func _args() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		var bare := arg.trim_prefix("--")
		var cut := bare.find("=")
		if cut < 0:
			out[bare] = true
		else:
			out[bare.left(cut)] = bare.substr(cut + 1)
	out.merge(_link_args())
	return out


## A page has no command line, so on the web the address is one:
## `#join=K7Q2PX` joins that room and `&relay` after it forces the relay.
static func _link_args() -> Dictionary:
	var out := {}
	if not OS.has_feature("web"):
		return out
	var hash := String(JavaScriptBridge.eval("window.location.hash", true))
	for part in hash.trim_prefix("#").split("&", false):
		if part.begins_with("join="):
			out["join"] = part.substr(5).strip_edges().to_upper()
		elif part == "relay":
			out["force-relay"] = true
	return out


## Our server, except on a page served over https, where the signaling is the
## page's own host (the Caddyfile puts them on one domain). A page served from
## a plain-http test server talks to ours.
static func _default_server() -> String:
	if OS.has_feature("web"):
		var page := String(JavaScriptBridge.eval("window.location.protocol + '//' + window.location.host", true))
		if page.begins_with("https://"):
			return "wss://" + page.trim_prefix("https://")
	return SERVER


## What a second machine opens to join this room: the signaling's own domain
## with the code in the address (ui/web_entry/ reads it). A phone cannot type
## into the web build, so for a phone this link IS the way in.
func _show_link(code: String) -> void:
	var secure := _url.text.begins_with("wss://")
	var host := _url.text.trim_prefix("wss://").trim_prefix("ws://").trim_suffix("/")
	_join_link = "%s://%s/#join=%s" % ["https" if secure else "http", host, code]
	_link.text = "JOIN LINK  %s" % _join_link
	_copy.visible = true
	_say("join link: %s" % _join_link)


func _copy_link() -> void:
	DisplayServer.clipboard_set(_join_link)
	_say("join link copied")


func _build_ui() -> void:
	theme = load("res://ui/theme/menu_theme.tres")
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	box.add_theme_constant_override(&"separation", 4)
	add_child(box)

	var top := HBoxContainer.new()
	box.add_child(top)
	top.add_child(_small_label("SERVER"))
	_url = _field(top, 260)
	top.add_child(_small_label("NAME"))
	_name = _field(top, 110)

	var row := HBoxContainer.new()
	box.add_child(row)
	row.add_child(_button("HOST", _host))
	row.add_child(_small_label("CODE"))
	_code = _field(row, 90)
	row.add_child(_button("JOIN", _join))
	_relay = CheckBox.new()
	_relay.text = "FORCE RELAY"
	_relay.add_theme_font_size_override(&"font_size", 12)
	row.add_child(_relay)

	_status = _small_label("NOT CONNECTED")
	_status.add_theme_font_size_override(&"font_size", 16)
	box.add_child(_status)
	var share := HBoxContainer.new()
	box.add_child(share)
	_link = _small_label("")
	share.add_child(_link)
	_copy = _button("COPY LINK", _copy_link)
	_copy.visible = false
	share.add_child(_copy)
	_table = _small_label("")
	box.add_child(_table)
	_log = _small_label("")
	_log.modulate = Color(1, 1, 1, 0.7)
	box.add_child(_log)


func _small_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", 12)
	return label


func _field(parent: Control, width: float) -> LineEdit:
	var edit := LineEdit.new()
	edit.custom_minimum_size.x = width
	edit.add_theme_font_size_override(&"font_size", 12)
	parent.add_child(edit)
	return edit


func _button(text: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override(&"font_size", 12)
	button.pressed.connect(pressed)
	return button
