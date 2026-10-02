extends "res://tests/helpers.gd"
## The way into online play (DESIGN.md's Multiplayer, M2), through the real
## screens: the main menu's ONLINE, the character select it reuses, and the
## lobby - option A, four seats - up to START putting the party into the game.
##
## The lobby is a view of the `Net` autoload, so the suite hosts the way the
## lobby's HOST would but on ENet (`Net.host_local()`), and a guest joins from
## a Net of its own in a SubViewport - tests/test_net.gd's arrangement. What is
## checked is what the SCREEN does with what Net says: the seats, the lines
## under them, the keys, and the party game.gd is handed.
##
## Driven by waits with deadlines, like test_net.gd, because a connection takes
## as long as it takes.

const PORT := 47921
const DEADLINE := 300
const NET := "res://autoload/net.gd"
const LOBBY := "res://ui/lobby/lobby.tscn"
const SELECT := "res://ui/character_select/character_select.tscn"
const MENU := "res://ui/main_menu/main_menu.tscn"
const GAME := "res://game/game.tscn"

var _guest: Node
var _guest_heard := {}
var _steps: Array[Callable] = []
var _at := 0
var _waiting := Callable()
var _label := ""
var _since := 0


func _tick(frame: int) -> void:
	if frame == 2:
		_steps = [_menu, _select, _entry, _escape, _again, _select, _host, _hosted,
			_join, _seated, _relay_and_link, _start, _in_game, _host_gone]
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


func _wait(label: String, cond: Callable) -> void:
	_label = label
	_waiting = cond


func _on(path: String) -> Callable:
	return func() -> bool: return current_scene != null and current_scene.scene_file_path == path


func _net() -> Node:
	return _autoload("Net")


func _node(unique: String) -> Node:
	return current_scene.get_node("%" + unique)


# --- the steps --------------------------------------------------------------------


func _menu() -> void:
	var play := current_scene.get_node("%PlayButton") as Button
	var online := current_scene.get_node("%OnlineButton") as Button
	var mode := current_scene.get_node("%ModeButton") as Button
	_check("menu: ONLINE sits between PLAY and MODE",
		online.global_position.y > play.global_position.y
			and online.global_position.y < mode.global_position.y)
	# Measured as test_menu.gd measures the select, by the column's own size -
	# a headless window is not 640x360, so positions would not say. The fifth
	# button is paid for in gaps and not in height: the column is no taller
	# than the four-button one it replaced (339), whose bottom the footer's
	# corner labels already sat beside.
	var need := (current_scene.get_node("CenterContainer/Menu") as Control).get_combined_minimum_size()
	_check("menu: five buttons in no more height than four took (%s)" % need,
		need.y <= 339.0)
	online.pressed.emit()
	_wait("menu: ONLINE opens the character select", _on(SELECT))


func _select() -> void:
	(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
	_wait("select: picking somebody on the way online opens the lobby", _on(LOBBY))


func _entry() -> void:
	_check("entry: the choice is up, the room is not",
		(_node("Entry") as Control).visible and not (_node("Room") as Control).visible)
	_check("entry: a clean install's name (%s)" % (_node("NameEdit") as LineEdit).text,
		(_node("NameEdit") as LineEdit).text == "PLAYER")
	_check("entry: HOST A ROOM has the focus", (_node("HostButton") as Button).has_focus())
	(_node("JoinButton") as Button).pressed.emit()
	_check("entry: JOIN with no code asks for one (%s)" % (_node("Status") as Label).text,
		(_node("Status") as Label).text == "TYPE THE 6-LETTER ROOM CODE")
	var code := _node("CodeEdit") as LineEdit
	code.text = "k7q2px"
	code.text_changed.emit("k7q2px")
	_check("entry: a code is shown in capitals (%s)" % code.text, code.text == "K7Q2PX")
	_net().emit_signal("failed", "no_such_room")
	_check("entry: a refusal is said in words (%s)" % (_node("Status") as Label).text,
		(_node("Status") as Label).text == "NO ROOM WITH THAT CODE")


func _escape() -> void:
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	_wait("entry: Escape backs out to the main menu", _on(MENU))


func _again() -> void:
	(current_scene.get_node("%OnlineButton") as Button).pressed.emit()
	_wait("again: ONLINE once more", _on(SELECT))


func _host() -> void:
	var err: int = _net().call("host_local", PORT, "Mayar", "reem")
	_check("host: the suite hosts on ENet the way HOST would online (%s)" % error_string(err),
		err == OK)
	_wait("host: the lobby shows the room Net opened",
		func() -> bool: return (_node("Room") as Control).visible)


func _hosted() -> void:
	_check("room: a local game has no code to show (%s)" % (_node("RoomTitle") as Label).text,
		(_node("RoomTitle") as Label).text == "LOCAL GAME" and (_node("Link") as Label).text == "")
	var seats := _seats()
	_check("room: one seat per MAX_PARTY (%d)" % seats.size(), seats.size() == 4)
	_check("room: the host's own seat, theirs and marked HOST",
		seats[0].get("kind") == "player" and _seat_text(seats[0], "Name") == "MAYAR"
			and _seat_text(seats[0], "Line1") == "HOST")
	_check("room: the rest are open",
		seats.slice(1).all(func(s) -> bool: return s.get("kind") == "open"))
	_check("room: alone, it says what to do (%s)" % (_node("WaitLine") as Label).text,
		(_node("WaitLine") as Label).text.begins_with("SEND THE CODE"))
	_check("room: START is the host's, and focused",
		(_node("StartButton") as Button).visible and (_node("StartButton") as Button).has_focus())
	_check("room: the keys a local host has (%s)" % (_node("RoomHint") as Label).text,
		(_node("RoomHint") as Label).text == "ENTER START    ESC LEAVE")


func _join() -> void:
	var view := SubViewport.new()
	view.name = "GuestView"
	root.add_child(view)
	set_multiplayer(SceneMultiplayer.new(), view.get_path())
	_guest = (load(NET) as GDScript).new()
	_guest.name = "Net"
	view.add_child(_guest)
	_guest.connect("run_started", func(rows: Array) -> void: _guest_heard["run_started"] = rows)
	_guest.connect("ended", func(reason: String) -> void: _guest_heard["ended"] = reason)
	_guest.call("join_local", "127.0.0.1", PORT, "Ivo", "anas")
	_wait("join: the guest takes the second seat",
		func() -> bool: return _seats()[1].get("kind") == "player")


func _seated() -> void:
	var seat: Node = _seats()[1]
	_check("seat: their name and their route (%s, %s)" % [_seat_text(seat, "Name"), _seat_text(seat, "Line2")],
		_seat_text(seat, "Name") == "IVO" and _seat_text(seat, "Line2") == "LAN")
	_check("seat: not this machine's, so it does not walk", seat.get("_mine") == false)
	_check("room: with company the waiting line goes", (_node("WaitLine") as Label).text == "")
	_wait("seat: the host's measured ping lands on the card",
		func() -> bool: return _seat_text(_seats()[1], "Line1").ends_with(" MS"))


func _relay_and_link() -> void:
	# Neither a relay nor a code exists on ENet, so both are told to the host's
	# Net directly: what is under test is what the screen does with them.
	var rows: Dictionary = _net().get("_rows")
	var guest_id: int = _guest.call("my_id")
	rows[guest_id]["route"] = "RELAY"
	_net().set("_code", "K7Q2PX")
	_net().emit_signal("roster_changed")
	_check("relay: the host is told who is on it (%s)" % (_node("RelayLine") as Label).text,
		(_node("RelayLine") as Label).text == "! IVO IS ON THE RELAY - EXPECT A HIGHER PING")
	_check("link: a room with a code shows it (%s)" % (_node("RoomTitle") as Label).text,
		(_node("RoomTitle") as Label).text == "ROOM K7Q2PX")
	_check("link: and its join link, with the key to copy it (%s)" % (_node("Link") as Label).text,
		(_node("Link") as Label).text == "JOIN LINK  dev.za-company.mayar-deeb.dev/#join=K7Q2PX   C COPY")
	_key(KEY_C, true)
	_key(KEY_C, false)
	_wait("link: C copies it, and says so",
		func() -> bool: return (_node("Link") as Label).text == "JOIN LINK COPIED")


func _start() -> void:
	var rows: Dictionary = _net().get("_rows")
	rows[int(_guest.call("my_id"))]["route"] = "LAN"
	_net().set("_code", "")
	(_node("StartButton") as Button).pressed.emit()
	_wait("start: START puts this machine into the game", _on(GAME))


func _in_game() -> void:
	var party: Array = current_scene.call("party")
	_check("game: one body per member of the roster (%d)" % party.size(), party.size() == 2)
	_check("game: this machine's is the host, as the character it picked",
		_player().get("character") == "reem")
	var other := current_scene.get_node_or_null("Player2")
	_check("game: the guest's body, as their character, on hands nothing moves yet",
		other != null and other.get("character") == "anas"
			and other.get("input_source").get_script() == load("res://game/player/virtual_input.gd"))
	var rows: Array = current_scene.get_node("HUD/Hud").call("party_rows")
	_check("game: the guest's HUD row carries the name they typed",
		rows.size() == 1 and (rows[0].get_node("Name") as Label).text == "Ivo")
	_check("game: the guest heard START too, with the same party",
		_guest_heard.get("run_started") is Array and (_guest_heard["run_started"] as Array).size() == 2)
	_check("game: the host's Net is in the run", _net().get("state") == 3)
	# The run ending under this machine - as it does for a guest whose host
	# goes - is a way back to the menu.
	_net().emit_signal("ended", "host_left")
	_wait("ended: the party ending ends the run, on the main menu", _on(MENU))


func _host_gone() -> void:
	_check("menu: arriving home left the party", _net().get("state") == 0)
	_wait("menu: and the guest was told the host left",
		func() -> bool: return _guest_heard.get("ended") == "host_left")


func _seats() -> Array:
	return (_node("Seats") as Node).get_children()


func _seat_text(seat: Node, child: String) -> String:
	return (seat.get_node(child) as Label).text
