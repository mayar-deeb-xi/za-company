extends Control
## The box a PRIVATE game opens over the list (join_view.gd): the host's name,
## a field for the six-letter code they gave you, and JOIN. A private game is in
## the list for everybody to see and only its code gets in, so this is the
## whole of what "private" asks of a joiner.
##
## It checks only the code's SHAPE; whether it is this game's is the signaling
## service's to say (`wrong_code`), and the join screen hands that answer back
## here with `say()`, so the box stays open to try again.

signal submitted(code: String)

const CODE_LENGTH := 6
const BOX := Rect2(160, 112, 320, 136)
const MID := Color("e8b84a")
const TEXT := Color("fff8e1")
const DIM := Color("987a68")
const ACCENT := Color("6eb39d")
const BG := Color("1b1119")
const SHADE := Color(0.055, 0.031, 0.051, 0.78)
const ASK := "TYPE THE CODE THEY GAVE YOU"

var _title: Label
var _note: Label
var _field: LineEdit
var _join: Button


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = SHADE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var panel := Panel.new()
	panel.position = BOX.position
	panel.size = BOX.size
	var frame := StyleBoxFlat.new()
	frame.bg_color = BG
	frame.border_color = MID
	frame.set_border_width_all(2)
	panel.add_theme_stylebox_override(&"panel", frame)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_title = _line(14, false)
	_title.name = "Title"
	_title.add_theme_color_override(&"font_color", TEXT)
	_note = _line(36, true)
	_note.name = "Note"
	_field = LineEdit.new()
	_field.name = "Code"
	_field.position = BOX.position + Vector2(24, 58)
	_field.size = Vector2(176, 30)
	_field.max_length = CODE_LENGTH
	_field.placeholder_text = "CODE"
	_field.text_changed.connect(_on_typed)
	_field.text_submitted.connect(func(_text: String) -> void: _submit())
	add_child(_field)
	_join = Button.new()
	_join.name = "Join"
	_join.text = "JOIN"
	_join.position = BOX.position + Vector2(208, 58)
	_join.size = Vector2(88, 30)
	_join.add_theme_font_size_override(&"font_size", 16)
	_join.pressed.connect(_submit)
	add_child(_join)
	var hint := _line(106, true)
	hint.text = "ENTER JOIN    ESC CANCEL"


## Over the list, for this game; the field focused and empty.
func open(room: Dictionary) -> void:
	_title.text = "%s GAME IS PRIVATE" % possessive(String(room.get("host", "")))
	_field.text = ""
	set_busy(false)
	say(ASK, DIM)
	visible = true
	_field.grab_focus()


func close() -> void:
	visible = false


## The line under the title: what to do, or why that did not work.
func say(message: String, colour: Color) -> void:
	_note.text = message
	_note.add_theme_color_override(&"font_color", colour)


## While the join is on its way: nothing to press twice.
func set_busy(busy: bool) -> void:
	_field.editable = not busy
	_join.disabled = busy
	if busy:
		say("JOINING...", ACCENT)


## "REEM'S", and "ANAS'" for a name that already ends in S.
static func possessive(name: String) -> String:
	var upper := name.to_upper()
	return upper + ("'" if upper.ends_with("S") else "'S")


func _submit() -> void:
	if _join.disabled:
		return
	var code := _field.text.strip_edges().to_upper()
	if code.length() != CODE_LENGTH:
		say("TYPE THE %d-LETTER CODE" % CODE_LENGTH, MID)
		_field.grab_focus()
		return
	submitted.emit(code)


## A code is six letters and digits, shown as typed in capitals.
func _on_typed(text: String) -> void:
	var upper := text.to_upper()
	if upper != text:
		var caret := _field.caret_column
		_field.text = upper
		_field.caret_column = caret


func _line(y: float, small: bool) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"Footer" if small else &""
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(BOX.position.x, BOX.position.y + y)
	label.size = Vector2(BOX.size.x, 18 if not small else 14)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
