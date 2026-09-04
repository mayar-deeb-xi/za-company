extends SceneTree
## One-shot project configuration. Re-runnable; safe to run again after edits.

func _key(physical_keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = physical_keycode
	return ev


func _action(events: Array) -> Dictionary:
	return {"deadzone": 0.2, "events": events}


func _initialize() -> void:
	# Pixel art must not be filtered, or every sprite goes blurry when scaled.
	ProjectSettings.set_setting("rendering/textures/canvas_textures/default_texture_filter", 0)

	# Pixel-art snapping stops sprites shimmering when the smoothed camera lands
	# on a fractional position.
	ProjectSettings.set_setting("rendering/2d/snap/snap_2d_transforms_to_pixel", true)

	ProjectSettings.set_setting("display/window/size/viewport_width", 640)
	ProjectSettings.set_setting("display/window/size/viewport_height", 360)
	# Launch fullscreen - this is how a player sees the game. F11 drops back to a
	# window for debugging (autoload/display.gd).
	ProjectSettings.set_setting("display/window/size/mode", 3)

	# The windowed fallback is an exact 3x of the 640x360 base, so pixels stay even.
	ProjectSettings.set_setting("display/window/size/window_width_override", 1920)
	ProjectSettings.set_setting("display/window/size/window_height_override", 1080)

	# Physical keycodes so WASD stays positional on non-QWERTY layouts.
	ProjectSettings.set_setting("input/move_up", _action([_key(KEY_W), _key(KEY_UP)]))
	ProjectSettings.set_setting("input/move_down", _action([_key(KEY_S), _key(KEY_DOWN)]))
	ProjectSettings.set_setting("input/move_left", _action([_key(KEY_A), _key(KEY_LEFT)]))
	ProjectSettings.set_setting("input/move_right", _action([_key(KEY_D), _key(KEY_RIGHT)]))
	ProjectSettings.set_setting("input/attack", _action([_key(KEY_SPACE), _key(KEY_J)]))
	ProjectSettings.set_setting("input/toggle_fullscreen", _action([_key(KEY_F11)]))

	# Order matters: autoloads are readied in the order they appear here, and
	# display.gd reads its saved values from Settings during _ready. Clearing
	# Display first re-appends it, which is what puts Settings ahead of it on a
	# project that already had Display registered.
	ProjectSettings.clear("autoload/Display")
	ProjectSettings.set_setting("autoload/Settings", "*res://autoload/settings.gd")
	ProjectSettings.set_setting("autoload/Display", "*res://autoload/display.gd")

	var err := ProjectSettings.save()
	print("ProjectSettings.save() -> ", error_string(err))
	quit(0 if err == OK else 1)
