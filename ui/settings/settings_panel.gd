extends Control
## Settings overlay, shared by the main menu and the pause menu.
##
## An overlay rather than its own screen because the pause menu cannot leave the
## scene - the game is still sitting behind it, paused. One panel serves both,
## so the two can never drift apart.
##
## It only drives Display; the saving lives there, next to the applying, so a
## change made with F11 is remembered the same way as one made here.

signal closed

@onready var _mode: OptionButton = %ModeOption
@onready var _window_size: OptionButton = %WindowSizeOption
@onready var _back_button: Button = %BackButton

## Parallel to the window-size dropdown's items.
var _sizes: Array[Vector2i] = []
## Whatever had focus when the panel opened, so closing puts it back.
var _return_focus: Control = null


func _ready() -> void:
	# The pause menu is the whole reason: it runs with the tree paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_mode.item_selected.connect(_on_mode_selected)
	_window_size.item_selected.connect(_on_window_size_selected)
	_back_button.pressed.connect(close)


func _input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	# Swallow it, or the pause menu would treat the same press as unpause.
	get_viewport().set_input_as_handled()
	close()


func is_open() -> bool:
	return visible


func open(return_focus: Control = null) -> void:
	_return_focus = return_focus
	_refresh()
	visible = true
	_mode.grab_focus()


func close() -> void:
	visible = false
	if is_instance_valid(_return_focus):
		_return_focus.grab_focus()
	closed.emit()


## Reads the live window state every time rather than trusting a cached value:
## F11 can change it while the panel is closed.
func _refresh() -> void:
	_mode.clear()
	_mode.add_item("WINDOWED", 0)
	_mode.add_item("FULLSCREEN", 1)
	_mode.select(1 if Display.is_fullscreen() else 0)

	_sizes = Display.available_window_sizes()
	var current := Display.window_size()
	# A saved size the monitor can no longer show still belongs in the list, or
	# the dropdown would silently disagree with what is stored.
	if not _sizes.has(current):
		_sizes.append(current)
		_sizes.sort()
	_window_size.clear()
	for i in _sizes.size():
		_window_size.add_item(_size_label(_sizes[i]), i)
	_window_size.select(_sizes.find(current))

	_update_window_size_availability()


## Names the whole multiple alongside the pixels. The game renders at a fixed
## internal size, so the number the player is really choosing is how many screen
## pixels one game pixel becomes - saying "3x" makes that legible.
func _size_label(size: Vector2i) -> String:
	var base: Vector2i = Display.base_size()
	var scale := size.x / maxi(base.x, 1)
	if scale > 0 and size == base * scale:
		return "%d x %d   %dx" % [size.x, size.y, scale]
	return "%d x %d" % [size.x, size.y]


## Window size means nothing in fullscreen - it follows the monitor - so the
## dropdown greys out rather than lying about having an effect.
func _update_window_size_availability() -> void:
	_window_size.disabled = Display.is_fullscreen()


func _on_mode_selected(index: int) -> void:
	Display.set_fullscreen(index == 1)
	_update_window_size_availability()


func _on_window_size_selected(index: int) -> void:
	if index >= 0 and index < _sizes.size():
		Display.set_window_size(_sizes[index])
