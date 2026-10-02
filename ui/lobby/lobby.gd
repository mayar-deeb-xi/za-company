extends Control
## Online play's front door (DESIGN.md's Multiplayer, M2) - option A of the
## lobby preview, FOUR SEATS. Two views on one screen:
##
## - **Before a room**: your name, HOST A ROOM, or a code and JOIN.
## - **The room**: its code and join link, then one seat per `MAX_PARTY` - the
##   character select's own cards, your seat walking - and START for the host.
##
## It is a VIEW of the `Net` autoload and a set of buttons that call it, and it
## holds no party state of its own: whatever Net says, it shows. That is also
## what lets a suite host through `Net.host_local()` and find the room already
## up when this screen opens.
##
## START is Net's `run_started`, heard on every machine: the rows become
## game.gd's `next_party` - this machine's member on the keyboard, everybody
## else on hands that are still until M3 puts their bodies in step - and the
## game loads.
##
## On the web the ADDRESS is the way in from a phone: `#join=CODE` (and
## `&relay` to force the relay, for testing) joins that room on arrival, as
## Guest unless a name was saved, once per page load.

const MENU_SCENE := "res://ui/main_menu/main_menu.tscn"
const GAME_SCENE := "res://game/game.tscn"
const GameType := preload("res://game/game.gd")
const Seat := preload("res://ui/lobby/seat.gd")
const Heads := preload("res://game/heads.gd")
const Roster := preload("res://game/player/characters/roster.gd")
const VirtualInput := preload("res://game/player/virtual_input.gd")

## Where the name lives: Settings' `online` section, not the settings panel,
## which has no room for a fourth row (DESIGN.md's Multiplayer).
const SETTINGS := &"online"
const CODE_LENGTH := 6
const COPIED_SECONDS := 1.5
const ACCENT := Color("6eb39d")
const WARN := Color("e8b84a")
const DIM := Color("987a68")

## What a refusal says to a player, by Net's reason code.
const REASONS := {
	"no_server": "CAN'T REACH THE SERVER - CHECK YOUR CONNECTION",
	"no_such_room": "NO ROOM WITH THAT CODE",
	"room_full": "THAT ROOM IS FULL",
	"started": "THAT RUN HAS ALREADY STARTED",
	"version": "THAT GAME IS ON ANOTHER VERSION",
	"unreachable": "COULD NOT CONNECT",
	"no_route": "COULD NOT CONNECT, EVEN THROUGH THE RELAY",
	"host_left": "THE HOST LEFT",
	"server_full": "THE SERVER IS FULL - TRY AGAIN SOON",
}

## The join link is used once per page load, so leaving a room it opened and
## coming back to the lobby does not join it all over again.
static var _link_spent := false

@onready var _entry: Control = %Entry
@onready var _room: Control = %Room
@onready var _name_edit: LineEdit = %NameEdit
@onready var _host_button: Button = %HostButton
@onready var _code_edit: LineEdit = %CodeEdit
@onready var _join_button: Button = %JoinButton
@onready var _back_button: Button = %BackButton
@onready var _status: Label = %Status
@onready var _entry_hint: Label = %EntryHint
@onready var _room_title: Label = %RoomTitle
@onready var _link: Label = %Link
@onready var _seats: HBoxContainer = %Seats
@onready var _relay_line: Label = %RelayLine
@onready var _wait_line: Label = %WaitLine
@onready var _start_button: Button = %StartButton
@onready var _leave_button: Button = %LeaveButton
@onready var _room_hint: Label = %RoomHint

var _busy := false
var _copied := 0.0


func _ready() -> void:
	Music.play(Music.MENU)
	for i in Heads.MAX_PARTY:
		var seat := Seat.new()
		seat.name = "Seat%d" % (i + 1)
		_seats.add_child(seat)
	_host_button.pressed.connect(_on_host)
	_join_button.pressed.connect(_on_join)
	_back_button.pressed.connect(_on_back)
	_start_button.pressed.connect(_on_start)
	_leave_button.pressed.connect(_on_leave)
	_code_edit.text_changed.connect(_on_code_typed)
	_code_edit.text_submitted.connect(func(_text: String) -> void: _on_join())
	_name_edit.text_submitted.connect(func(_text: String) -> void: _host_button.grab_focus())
	# Methods rather than lambdas: a connection to a method is dropped when this
	# screen is freed, and Net outlives every screen.
	Net.hosted.connect(_on_hosted)
	Net.joined.connect(_show_room)
	Net.roster_changed.connect(_on_roster_changed)
	Net.failed.connect(_on_failed)
	Net.ended.connect(_on_failed)
	Net.run_started.connect(_on_run_started)

	var link := {} if _link_spent else _link_args()
	_name_edit.text = String(Settings.get_value(SETTINGS, &"name",
		"GUEST" if link.has("join") else "PLAYER"))
	if Net.state == Net.State.LOBBY:
		_show_room()
	elif link.has("join"):
		_link_spent = true
		_show_entry("")
		_code_edit.text = String(link["join"])
		_join(bool(link.get("relay", false)))
	else:
		_show_entry("")


func _process(delta: float) -> void:
	if _copied > 0.0:
		_copied = maxf(_copied - delta, 0.0)
		if _copied == 0.0:
			_refresh_room()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		UiSound.back()
		if _room.visible:
			_on_leave()
		else:
			_on_back()
	elif _room.visible and event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).physical_keycode == KEY_C:
		get_viewport().set_input_as_handled()
		_copy_link()


# --- before a room --------------------------------------------------------------


func _on_host() -> void:
	if _busy:
		return
	_remember_name()
	_set_busy("OPENING A ROOM...")
	Net.host(_name_edit.text, _character())


func _on_join() -> void:
	_join(false)


func _join(force_relay: bool) -> void:
	if _busy:
		return
	var code := _code_edit.text.strip_edges().to_upper()
	if code.length() != CODE_LENGTH:
		_say("TYPE THE %d-LETTER ROOM CODE" % CODE_LENGTH, WARN)
		_code_edit.grab_focus()
		return
	_remember_name()
	_set_busy("JOINING %s..." % code)
	Net.join(code, _name_edit.text, _character(), force_relay)


## BACK out of the lobby, or - while a room is being opened or joined - out of
## trying, back to the choice.
func _on_back() -> void:
	if _busy:
		Net.leave()
		_show_entry("")
		return
	get_tree().change_scene_to_file(MENU_SCENE)


## A code is six letters and digits, shown as typed in capitals.
func _on_code_typed(text: String) -> void:
	var upper := text.to_upper()
	if upper != text:
		var caret := _code_edit.caret_column
		_code_edit.text = upper
		_code_edit.caret_column = caret


func _on_failed(reason: String) -> void:
	_show_entry(String(REASONS.get(reason, "THE SERVER SAID NO (%s)" % reason)))


func _show_entry(message: String) -> void:
	_busy = false
	_entry.visible = true
	_room.visible = false
	_name_edit.editable = true
	_code_edit.editable = true
	_host_button.disabled = false
	_join_button.disabled = false
	_back_button.text = "BACK"
	_entry_hint.text = "ENTER CHOOSE    ESC BACK"
	_say(message, WARN)
	_host_button.grab_focus()


func _set_busy(message: String) -> void:
	_busy = true
	_name_edit.editable = false
	_code_edit.editable = false
	_host_button.disabled = true
	_join_button.disabled = true
	_back_button.text = "CANCEL"
	_entry_hint.text = "ESC CANCEL"
	_say(message, ACCENT)
	_back_button.grab_focus()


func _say(message: String, colour: Color) -> void:
	_status.text = message
	_status.add_theme_color_override(&"font_color", colour)


# --- the room -----------------------------------------------------------------------


func _on_hosted(_code: String) -> void:
	_show_room()


func _show_room() -> void:
	_busy = false
	_entry.visible = false
	_room.visible = true
	_refresh_room()
	(_start_button if Net.is_host() else _leave_button).grab_focus()


func _on_roster_changed() -> void:
	if _room.visible and Net.state != Net.State.OFFLINE:
		_refresh_room()


## Everything in the room view is drawn from Net, every time.
func _refresh_room() -> void:
	var rows := Net.roster()
	var me := Net.my_id()
	var host := Net.is_host()
	var code := Net.code()
	_room_title.text = "ROOM %s" % code if code != "" else "LOCAL GAME"
	var link := Net.join_link().trim_prefix("https://").trim_prefix("http://")
	if _copied > 0.0:
		_link.text = "JOIN LINK COPIED"
		_link.add_theme_color_override(&"font_color", ACCENT)
	else:
		_link.text = "JOIN LINK  %s   C COPY" % link if link != "" else ""
		_link.add_theme_color_override(&"font_color", DIM)
	for i in _seats.get_child_count():
		var seat := _seats.get_child(i)
		if i < rows.size():
			seat.call("show_row", rows[i], int(rows[i]["peer"]) == me)
		else:
			seat.call("show_open")

	var relayed: Array = rows.filter(func(row: Dictionary) -> bool: return row.get("route") == "RELAY")
	var mine: Array = rows.filter(func(row: Dictionary) -> bool: return int(row["peer"]) == me)
	if host and relayed.size() == 1:
		_relay_line.text = "! %s IS ON THE RELAY - EXPECT A HIGHER PING" % String(relayed[0]["name"]).to_upper()
	elif host and relayed.size() > 1:
		_relay_line.text = "! %d PLAYERS ARE ON THE RELAY - EXPECT HIGHER PINGS" % relayed.size()
	elif not host and not mine.is_empty() and mine[0].get("route") == "RELAY":
		_relay_line.text = "! CONNECTED THROUGH RELAY - EXPECT HIGHER PING"
	else:
		_relay_line.text = ""

	if not host:
		var host_name := String(rows[0]["name"]).to_upper() if not rows.is_empty() else "THE HOST"
		_wait_line.text = "WAITING FOR %s TO START" % host_name
	elif rows.size() == 1:
		_wait_line.text = "SEND THE CODE OR THE LINK - START WHEN EVERYONE IS IN"
	else:
		_wait_line.text = ""
	_start_button.visible = host
	var keys: Array[String] = []
	if host:
		keys.append("ENTER START")
	if link != "":
		keys.append("C COPY LINK")
	keys.append("ESC LEAVE")
	_room_hint.text = "    ".join(keys)


func _on_start() -> void:
	Net.start_run()


func _on_leave() -> void:
	Net.leave()
	_show_entry("")


func _copy_link() -> void:
	var link := Net.join_link()
	if link == "":
		return
	DisplayServer.clipboard_set(link)
	_copied = COPIED_SECONDS
	_refresh_room()


## Everybody into the run, in the roster's order, which is the same order on
## every machine. This machine's member is marked `local` and drives its body
## from the keyboard; everybody else's body has hands nothing moves yet.
func _on_run_started(rows: Array) -> void:
	var me := Net.my_id()
	var party := []
	for row: Dictionary in rows:
		var member := {"character": String(row.get("character", "")),
			"name": String(row.get("name", "")), "peer": int(row["peer"]),
			"local": int(row["peer"]) == me}
		if not member["local"]:
			member["input"] = VirtualInput.new()
		party.append(member)
	GameType.next_party = party
	get_tree().change_scene_to_file(GAME_SCENE)


# --- plumbing ---------------------------------------------------------------------


func _remember_name() -> void:
	var clean := _name_edit.text.strip_edges()
	if clean == "":
		clean = "PLAYER"
		_name_edit.text = clean
	Settings.set_value(SETTINGS, &"name", clean)


func _character() -> String:
	return String(Settings.get_value(&"player", &"character", Roster.DEFAULT_ID))


## A page has no command line, so on the web the address is one:
## `#join=K7Q2PX` joins that room, and `&relay` after it forces the relay.
static func _link_args() -> Dictionary:
	var out := {}
	if not OS.has_feature("web"):
		return out
	var hash := String(JavaScriptBridge.eval("window.location.hash", true))
	for part in hash.trim_prefix("#").split("&", false):
		if part.begins_with("join="):
			out["join"] = part.substr(5).strip_edges().to_upper()
		elif part == "relay":
			out["relay"] = true
	return out
