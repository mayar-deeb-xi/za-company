extends Control
## Pick who to play. Sits between the main menu's Play button and the game:
## one focusable portrait per roster character, left/right to browse, Enter or
## a click to choose. The choice is saved through Settings so the next visit
## starts on the same character, then the game scene loads.

const GAME_SCENE := "res://game/game.tscn"
const MENU_SCENE := "res://ui/main_menu/main_menu.tscn"

## Preloaded by path rather than via `class_name`, like the rest of the project.
const Roster := preload("res://game/player/characters/roster.gd")

## 32px frames drawn at a whole multiple, matching the game's pixel scale rules.
const PORTRAIT_PX := 64
const WALK_FPS := 8.0

@onready var _row: HBoxContainer = %Roster
@onready var _back_button: Button = %BackButton

## Button -> {"icon": TextureRect, "frames": SpriteFrames}
var _portraits := {}
var _focused: Button = null
var _walk_frame := 0


func _ready() -> void:
	_back_button.pressed.connect(_go_back)

	var saved: String = Settings.get_value(&"player", &"character", Roster.DEFAULT_ID)
	var first: Button = null
	var focus_target: Button = null
	for entry in Roster.CHARACTERS:
		var button := _make_portrait(entry)
		_row.add_child(button)
		if first == null:
			first = button
		if entry["id"] == saved:
			focus_target = button
	(focus_target if focus_target != null else first).grab_focus()

	# The focused portrait walks in place; everyone else stands still.
	var timer := Timer.new()
	timer.wait_time = 1.0 / WALK_FPS
	timer.autostart = true
	timer.timeout.connect(_animate_focused)
	add_child(timer)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_go_back()


func _go_back() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


func _make_portrait(entry: Dictionary) -> Button:
	var frames := load(entry["frames"]) as SpriteFrames

	var button := Button.new()
	button.name = entry["id"]
	button.custom_minimum_size = Vector2(72, 100)

	# The button is the one control here; its children must not eat the mouse.
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(PORTRAIT_PX, PORTRAIT_PX)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = frames.get_frame_texture("idle_down", 0)
	box.add_child(icon)

	var label := Label.new()
	label.text = String(entry["name"]).to_upper()
	label.theme_type_variation = &"Footer"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)

	button.add_child(box)
	button.pressed.connect(_choose.bind(entry["id"]))
	button.focus_entered.connect(_on_portrait_focused.bind(button))

	_portraits[button] = {"icon": icon, "frames": frames}
	return button


func _choose(id: String) -> void:
	Settings.set_value(&"player", &"character", id)
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_portrait_focused(button: Button) -> void:
	if _focused != null and _portraits.has(_focused):
		var prev: Dictionary = _portraits[_focused]
		prev["icon"].texture = prev["frames"].get_frame_texture("idle_down", 0)
	_focused = button
	_walk_frame = 0


func _animate_focused() -> void:
	if _focused == null or not _portraits.has(_focused):
		return
	var portrait: Dictionary = _portraits[_focused]
	_walk_frame = (_walk_frame + 1) % portrait["frames"].get_frame_count("walk_down")
	portrait["icon"].texture = portrait["frames"].get_frame_texture("walk_down", _walk_frame)
