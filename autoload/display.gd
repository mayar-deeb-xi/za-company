extends Node
## Owns the game window: fullscreen or windowed, and the windowed size.
##
## Autoloaded so the fullscreen hotkey works in every scene, menu included, and
## so the player's saved choice is applied before the first frame is drawn.
## Every change goes through here rather than through DisplayServer directly, so
## there is one place that both moves the window and remembers the move.

const SECTION := &"display"

## Window sizes are offered as WHOLE multiples of the base viewport only.
##
## This is a pixel-art game with a fixed 640x360 internal resolution, so the
## window size does not change what is rendered - only how big each game pixel
## is drawn. At a fractional scale (1600x900 is 2.5x) some pixels land on three
## screen pixels and their neighbours on two, and the whole image crawls as the
## camera moves. Whole multiples keep every pixel the same size.
const SCALES := [2, 3, 4, 5, 6]
## Matches the window override in project.godot.
const DEFAULT_SCALE := 3

## Camera zoom, which is the setting that actually changes how much of a level
## is on screen - window size only makes the same picture bigger.
##
## At 1 the 640x360 view holds a whole 544x304 room and the camera sits still;
## anything above that scrolls. 4 shows about ten tiles across, which is as close
## as a top-down game can get before the player stops seeing what is walking at
## them.
##
## 1.25 and 1.5 are the deliberate exception to the whole-numbers rule that
## governs SCALES. A fractional zoom means a source pixel covers 1.25 screen
## pixels, so neighbouring pixels are drawn at different sizes - the cost of
## having any step at all between "the whole room" and "half of it", since 2 is
## the next whole number and it is a big jump. Both are quarters, so a 16 px tile
## still lands on a whole 20 or 24 px, which keeps the tile grid itself even.
const ZOOMS := [1.0, 1.25, 1.5, 2.0, 3.0, 4.0]
const DEFAULT_ZOOM := 1.0

const FULLSCREEN_MODES := [
	DisplayServer.WINDOW_MODE_FULLSCREEN,
	DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
]

signal changed


func _ready() -> void:
	# Stay responsive while the tree is paused, so F11 works from the pause menu.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Nothing saved means the player has never expressed a preference, so leave
	# the window exactly as the project launched it. Writing a default here
	# would record a choice they never made - and would let any headless run
	# quietly reset how the game opens.
	if Settings.has(SECTION, &"fullscreen"):
		_apply_fullscreen(Settings.get_value(SECTION, &"fullscreen", false))


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		get_viewport().set_input_as_handled()
		set_fullscreen(not is_fullscreen())


func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() in FULLSCREEN_MODES


## The internal render size. Fixed: the window scales it, never replaces it.
func base_size() -> Vector2i:
	return Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width", 640),
		ProjectSettings.get_setting("display/window/size/viewport_height", 360))


## How big the window is in windowed mode - deliberately NOT called a
## resolution. The game always renders at base_size(); this only decides how
## many screen pixels one game pixel becomes. Remembered even while fullscreen,
## so switching back restores the window the player had.
func window_size() -> Vector2i:
	return Settings.get_value(SECTION, &"window_size", base_size() * DEFAULT_SCALE)


func set_fullscreen(on: bool) -> void:
	Settings.set_value(SECTION, &"fullscreen", on)
	_apply_fullscreen(on)
	changed.emit()


## Borderless fullscreen rather than exclusive - it alt-tabs cleanly.
func _apply_fullscreen(on: bool) -> void:
	if on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		_resize(window_size())


func set_window_size(size: Vector2i) -> void:
	Settings.set_value(SECTION, &"window_size", size)
	if not is_fullscreen():
		_resize(size)
	changed.emit()


## How much of the world is on screen. Stored here beside the window settings
## because it is the same question from the player's side - "how big is the
## game?" - but applied by game.gd, which is what owns a camera.
## Cast rather than trusted: a settings.cfg written before the fractional steps
## existed holds a plain int here.
func zoom() -> float:
	return float(Settings.get_value(SECTION, &"zoom", DEFAULT_ZOOM))


func set_zoom(level: float) -> void:
	Settings.set_value(SECTION, &"zoom", level)
	changed.emit()


## Whole-multiple window sizes that fit on this monitor. Where the screen size
## is unknown - a headless run reports zero - every scale is offered.
func available_window_sizes() -> Array[Vector2i]:
	var base := base_size()
	var screen := DisplayServer.screen_get_size()
	var fits: Array[Vector2i] = []
	for scale: int in SCALES:
		var size := base * scale
		if screen.x <= 0 or (size.x <= screen.x and size.y <= screen.y):
			fits.append(size)
	# Never hand back an empty list: too big is better than no choice at all.
	if fits.is_empty():
		fits.append(base * SCALES[0])
	return fits


func _resize(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	# Re-centre: a window grown past the screen edge can otherwise end up with
	# its title bar out of reach.
	var screen := DisplayServer.screen_get_size()
	if screen.x > 0:
		DisplayServer.window_set_position(
			DisplayServer.screen_get_position() + (screen - size) / 2)
