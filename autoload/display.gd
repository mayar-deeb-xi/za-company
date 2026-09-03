extends Node
## Autoloaded so the fullscreen hotkey works in every scene, menu included.

const FULLSCREEN_MODES := [
	DisplayServer.WINDOW_MODE_FULLSCREEN,
	DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
]


func _ready() -> void:
	# Stay responsive while the tree is paused, so F11 works from the pause menu.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		get_viewport().set_input_as_handled()
		toggle_fullscreen()


func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() in FULLSCREEN_MODES


## Borderless fullscreen rather than exclusive - it alt-tabs cleanly.
func toggle_fullscreen() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_WINDOWED if is_fullscreen()
		else DisplayServer.WINDOW_MODE_FULLSCREEN)
