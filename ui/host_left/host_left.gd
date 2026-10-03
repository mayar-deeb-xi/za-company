extends CanvasLayer
## The host has left, and with them the run (DESIGN.md's *Rules that keep it
## honest*: the host leaving ends the session for everybody). Picked as option B
## ("Panel with a button") from the Ping On Screen preview and built exactly as
## previewed: a panel over the room saying what happened, waiting for MAIN
## MENU, so nobody is moved anywhere without seeing why.
##
## It wears the death screen's manners rather than its panel: Escape is
## swallowed - there is nothing to go back to - the room is frozen behind it,
## and the one way out is the button. game.gd builds it when Net says the party
## ended under this machine with `host_left`; Net has already gone back to
## offline by then, so the run really is over and pausing the tree stops
## nobody else's game.

const MAIN_MENU_SCENE := "res://ui/main_menu/main_menu.tscn"
const THEME := preload("res://ui/theme/menu_theme.tres")

## The menu theme's colours (tools/build_ui_theme.gd).
const BG := Color("1b1119")
const ACCENT := Color("6eb39d")
const DIM := Color("987a68")
## The design viewport the panel is centred in.
const VIEW := Vector2(640, 360)
## Above the HUD, the fade and the title; with the pause menu, which it stands
## in for.
const LAYER := 10

var _panel: PanelContainer
var _button: Button
var _line: Label


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS


## Up, over a frozen room, for the game `host` was hosting ("" when nobody
## knows their name).
func open(host: String) -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = THEME
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_panel = PanelContainer.new()
	root.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	_panel.add_child(box)
	var heading := Label.new()
	heading.theme_type_variation = &"Heading"
	heading.text = "THE HOST LEFT"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	_line = Label.new()
	_line.text = ("%s'S GAME HAS ENDED" % host.to_upper()) if host != "" else "THE GAME HAS ENDED"
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.add_theme_color_override(&"font_color", DIM)
	box.add_child(_line)
	_button = Button.new()
	_button.name = "MainMenuButton"
	_button.text = "MAIN MENU"
	_button.custom_minimum_size = Vector2(200, 34)
	_button.pressed.connect(_on_main_menu)
	box.add_child(_button)
	_panel.custom_minimum_size = Vector2(260, 0)
	_panel.add_theme_stylebox_override(&"panel", _panel_box())
	get_tree().paused = true
	# Centred once it has a size, which a container only has after a frame.
	await get_tree().process_frame
	_panel.position = ((VIEW - _panel.size) / 2).round()
	_button.grab_focus()


## What the panel says under its heading. For tests.
func line() -> String:
	return _line.text if _line != null else ""


func main_menu_button() -> Button:
	return _button


## Escape has nothing to go back to here, and must not reach the pause menu
## underneath: this layer is added after it, so it hears the key first.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()


func _on_main_menu() -> void:
	# Unpaused before leaving, or the menu scene loads frozen.
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _panel_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(BG, 0.96)
	box.border_color = ACCENT
	box.set_border_width_all(2)
	box.set_content_margin_all(16)
	return box
