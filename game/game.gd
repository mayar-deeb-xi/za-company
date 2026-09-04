extends Node2D
## Gameplay host. Owns the player, the camera, the HUD and the pause menu, and
## swaps one Level child in and out beneath them.
##
## The player node is never re-instantiated, so anything it accumulates - facing,
## and later health or inventory - survives a door transition for free, and the
## pause menu is not duplicated per map.
##
## Escape is handled by the PauseMenu child, which pauses the tree instead of
## leaving the scene. Leaving for the main menu is one of its options.

const START_LEVEL := "res://game/levels/marble_hall/marble_hall.tscn"
const FADE_SECONDS := 0.28

## Typed by preloaded script rather than by the `class_name` those scripts also
## declare: global class names come from a cache the editor writes, which a
## fresh checkout running headless does not have yet.
const LevelType := preload("res://game/levels/level.gd")
const DoorType := preload("res://game/levels/door_base.gd")

@onready var _player: CharacterBody2D = $Player
@onready var _camera: Camera2D = $Player/Camera2D
@onready var _fade: ColorRect = $Transition/Fade

var _level: LevelType
var _travelling := false


func _ready() -> void:
	_enter_level(START_LEVEL, &"start")


## Fade out, swap, fade back in. Input is suspended for the whole trip so a key
## held through the transition cannot walk the player straight back into the
## door they just arrived beside.
func _travel(level_path: String, spawn: StringName) -> void:
	if _travelling:
		return
	_travelling = true
	_player.set_physics_process(false)
	_player.velocity = Vector2.ZERO

	var out := create_tween()
	out.tween_property(_fade, "color:a", 1.0, FADE_SECONDS)
	await out.finished

	_enter_level(level_path, spawn)

	var back := create_tween()
	back.tween_property(_fade, "color:a", 0.0, FADE_SECONDS)
	await back.finished

	_player.set_physics_process(true)
	_travelling = false


func _enter_level(level_path: String, spawn: StringName) -> void:
	if _level != null:
		# Detach before freeing: the replacement is added in the same frame and
		# would otherwise collide with the outgoing level's node name.
		remove_child(_level)
		_level.queue_free()

	_level = (load(level_path) as PackedScene).instantiate()
	add_child(_level)
	move_child(_level, 0)

	# Group rather than a type search, for the same reason as the preloads above.
	# The outgoing level has already left the tree, so this only sees new doors.
	for node in get_tree().get_nodes_in_group("door"):
		var door := node as DoorType
		if door != null:
			door.travelled.connect(_travel)

	_player.global_position = _level.spawn_position(spawn)
	_apply_camera_limits(_level.bounds())


## Camera limits come from the level rather than the scene file, so each map can
## be its own size without game.tscn knowing anything about it.
func _apply_camera_limits(rect: Rect2) -> void:
	_camera.limit_left = int(rect.position.x)
	_camera.limit_top = int(rect.position.y)
	_camera.limit_right = int(rect.end.x)
	_camera.limit_bottom = int(rect.end.y)
	# Otherwise the camera glides across from wherever the last level left it.
	_camera.reset_smoothing()
