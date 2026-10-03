extends Control
## The lobby's JOIN A GAME (lobby.gd): the list of games and nothing else, as
## the Open Games preview drew it. Every game on this build's wire is in it -
## open, private, full and playing, each row saying which (game_row.gd) - and
## one line under it says what Enter will do with the picked game, or why it
## can't. A private game opens a box for its code (code_box.gd).
##
## The list is Net's (`browse()`, net/room_list.gd), asked for again every few
## seconds while this screen is up, and each answer replaces the last WHOLE. So
## the rows are kept by game id rather than rebuilt: the picked game stays
## picked as the list moves under it, and only a game that is gone loses the
## focus - to whatever now sits where it was.

signal join_requested(room_id: String, code: String)
signal back_requested

const GameRow := preload("res://ui/lobby/game_row.gd")
const CodeBox := preload("res://ui/lobby/code_box.gd")

## The order the list is read in: what can be joined, what wants a code, what
## can only be looked at. Inside each, nearest time zone first.
const ORDER := ["open", "private", "full", "playing"]
const VISIBLE_ROWS := 7
const ROW_STEP := 31
## How long a refusal stays on the line before it gives way to the picked row.
const SAY_SECONDS := 4.0
const ACCENT := Color("6eb39d")
const MID := Color("e8b84a")
const TEXT := Color("fff8e1")
const DIM := Color("987a68")

@onready var _scroll: ScrollContainer = %ListScroll
@onready var _rows: VBoxContainer = %ListRows
@onready var _headers: Control = %ListHeaders
@onready var _empty_title: Label = %EmptyTitle
@onready var _empty_note: Label = %EmptyNote
@onready var _empty_again: Label = %EmptyAgain
@onready var _more: Control = %More
@onready var _more_label: Label = %MoreLabel
@onready var _line: Label = %ListLine
@onready var _back: Button = %JoinBack
@onready var _hint: Label = %JoinHint

var _box: CodeBox
## The private game the box is asking a code for.
var _box_room := {}
## game id -> its row.
var _by_id := {}
## Whether the last answer had any games, so the first games to arrive can
## take the focus BACK only held for want of anything else.
var _had_rows := false
var _answered := false
var _reachable := true
var _busy := false
var _said := 0.0
var _zone := 0


func _ready() -> void:
	_zone = Net.zone_minutes()
	_box = CodeBox.new()
	_box.name = "CodeBox"
	_box.visible = false
	_box.submitted.connect(_on_code)
	add_child(_box)
	_back.pressed.connect(back_requested.emit)
	_back.focus_entered.connect(_show_line)
	_scroll.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: _show_more())
	_more.draw.connect(_draw_arrow)
	# Methods, so the connections go when this screen is freed: Net outlives it.
	Net.rooms_listed.connect(_on_listed)
	Net.rooms_unreachable.connect(_on_unreachable)


## The lobby has just put this screen up.
func shown() -> void:
	_busy = false
	_said = 0.0
	_box.close()
	_show_state()
	_focus_first()


func _process(delta: float) -> void:
	if _said > 0.0:
		_said = maxf(_said - delta, 0.0)
		if _said == 0.0:
			_show_line()


## Escape is taken here before anything else sees it while the code box is up:
## its field is a LineEdit, which keeps the key for itself.
func _input(event: InputEvent) -> void:
	if visible and _box.visible and event.is_action_pressed("ui_cancel"):
		_cancel()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_cancel()


func _cancel() -> void:
	get_viewport().set_input_as_handled()
	UiSound.back()
	if _busy:
		Net.leave()
		_busy = false
		_box.set_busy(false)
		_box.say(CodeBox.ASK, DIM)
		_show_line()
	elif _box.visible:
		_box.close()
		_focus_first()
	else:
		back_requested.emit()


## Joining by an address's `#join=CODE` rather than from the list.
func joining(code: String) -> void:
	_busy = true
	_say("JOINING %s..." % code, ACCENT, 0.0)


## The join did not happen: said on the code box when it was the code, on the
## line under the list otherwise.
func refused(reason: String, message: String) -> void:
	_busy = false
	if _box.visible and reason == "wrong_code":
		_box.set_busy(false)
		_box.say(message, MID)
		return
	_box.close()
	_say(message, MID, SAY_SECONDS)
	_focus_first()


## Read by tests: the rows in the order they are shown.
func rows() -> Array:
	return _rows.get_children()


func code_box() -> Control:
	return _box


# --- the list -----------------------------------------------------------------------


func _on_listed(rooms: Array) -> void:
	_answered = true
	_reachable = true
	_apply(rooms)


func _on_unreachable() -> void:
	_answered = true
	_reachable = false
	_apply([])


func _apply(rooms: Array) -> void:
	var sorted := rooms.filter(func(r) -> bool: return r is Dictionary and r.has("id"))
	sorted.sort_custom(_before)
	var focused := _focused_row()
	var focused_id := String(focused.room.get("id", "")) if focused != null else ""
	var at := focused.get_index() if focused != null else -1
	var back_held_it := _back.has_focus()
	var seen := {}
	for i in sorted.size():
		var room: Dictionary = sorted[i]
		var id := String(room["id"])
		seen[id] = true
		var row: GameRow = _by_id.get(id)
		if row == null:
			row = GameRow.new()
			row.name = "Game_" + id
			row.pressed.connect(_on_row_pressed.bind(row))
			row.focus_entered.connect(_show_line)
			_rows.add_child(row)
			_by_id[id] = row
		row.show_room(room, _zone)
		_rows.move_child(row, i)
	for id in _by_id.keys():
		if not seen.has(id):
			var gone: GameRow = _by_id[id]
			_by_id.erase(id)
			_rows.remove_child(gone)
			gone.queue_free()
	_show_state()
	if focused_id != "" and not seen.has(focused_id):
		# The picked game went: whatever sits where it was.
		_focus_at(at)
	elif _focus_is_lost():
		_focus_first()
	elif back_held_it and not _had_rows and _rows.get_child_count() > 0:
		# BACK held the focus only because there was nothing else to hold it.
		_focus_first()
	_had_rows = _rows.get_child_count() > 0
	_show_line()


func _before(a: Dictionary, b: Dictionary) -> bool:
	var ra := ORDER.find(String(a.get("status", "")))
	var rb := ORDER.find(String(b.get("status", "")))
	if ra != rb:
		return ra < rb
	return absi(int(a.get("zone", 0)) - _zone) < absi(int(b.get("zone", 0)) - _zone)


func _on_row_pressed(row: GameRow) -> void:
	if _busy:
		return
	if row.joinable():
		_busy = true
		_say("JOINING %s GAME..." % CodeBox.possessive(String(row.room.get("host", ""))), ACCENT, 0.0)
		join_requested.emit(String(row.room["id"]), "")
	elif row.status() == "private":
		_box_room = row.room
		_box.open(row.room)


## The box holds the focus while it is up, so the game it was opened for is
## remembered rather than read off the list.
func _on_code(code: String) -> void:
	_busy = true
	_box.set_busy(true)
	join_requested.emit(String(_box_room.get("id", "")), code)


# --- what is on screen -----------------------------------------------------------


## Rows, or why there are none.
func _show_state() -> void:
	var has_rows := _rows.get_child_count() > 0
	_headers.visible = has_rows
	_scroll.visible = has_rows
	for label in [_empty_title, _empty_note, _empty_again]:
		label.visible = not has_rows
	if not _answered:
		_empty("LOOKING FOR GAMES...", TEXT, "", "")
	elif not _reachable:
		_empty("CAN'T REACH THE SERVER", MID, "CHECK YOUR CONNECTION - TRYING AGAIN", "")
	else:
		_empty("NO GAMES RIGHT NOW", TEXT, "HOST ONE FROM THE MAIN MENU", "LOOKING AGAIN EVERY FEW SECONDS")
	_hint.text = "ENTER JOIN    ARROWS CHOOSE    ESC BACK" if has_rows else "ESC BACK"
	_show_more()


func _empty(title: String, colour: Color, note: String, again: String) -> void:
	_empty_title.text = title
	_empty_title.add_theme_color_override(&"font_color", colour)
	_empty_note.text = note
	_empty_again.text = again


## How many games are below the bottom of the list, if any.
func _show_more() -> void:
	var first := int(_scroll.scroll_vertical / float(ROW_STEP))
	var below := _rows.get_child_count() - first - VISIBLE_ROWS
	_more.visible = _scroll.visible and below > 0
	_more_label.text = "%d MORE" % below


func _draw_arrow() -> void:
	for i in 4:
		_more.draw_rect(Rect2(i, 3 + i, 9 - 2 * i, 1), DIM)


## The line under the list: a refusal while it lasts, then what Enter will do
## with the picked game.
func _show_line() -> void:
	if _said > 0.0 or _busy:
		return
	var row := _focused_row()
	if row == null:
		_set_line("", DIM)
		return
	var who := CodeBox.possessive(String(row.room.get("host", "")))
	match row.status():
		"open":
			var free := int(row.room.get("max", 0)) - int(row.room.get("players", 0))
			_set_line("%s GAME HAS %d FREE %s - ENTER TO JOIN"
				% [who, free, "SEAT" if free == 1 else "SEATS"], ACCENT)
		"private":
			_set_line("%s GAME IS PRIVATE - ENTER, THEN TYPE THE CODE THEY GAVE YOU" % who, MID)
		"full":
			_set_line("%s GAME IS FULL - IT OPENS AGAIN IF A SEAT FREES UP" % who, DIM)
		_:
			_set_line("%s RUN HAS STARTED - NOBODY CAN JOIN A RUN ONCE IT BEGINS" % who, DIM)


func _say(message: String, colour: Color, seconds: float) -> void:
	_said = seconds
	_set_line(message, colour)


func _set_line(text: String, colour: Color) -> void:
	_line.text = text
	_line.add_theme_color_override(&"font_color", colour)


# --- focus -----------------------------------------------------------------------


func _focused_row() -> GameRow:
	var focus := get_viewport().gui_get_focus_owner()
	return focus as GameRow if focus is GameRow and focus.get_parent() == _rows else null


func _focus_is_lost() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	return focus == null or not is_ancestor_of(focus)


## The first game when there is one - the reason to be on this screen - and
## BACK when there is none.
func _focus_first() -> void:
	if _box.visible:
		return
	if _rows.get_child_count() > 0:
		(_rows.get_child(0) as Control).grab_focus()
	else:
		_back.grab_focus()


func _focus_at(index: int) -> void:
	var count := _rows.get_child_count()
	if count == 0:
		_back.grab_focus()
	else:
		(_rows.get_child(clampi(index, 0, count - 1)) as Control).grab_focus()
