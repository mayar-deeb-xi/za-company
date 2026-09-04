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
@onready var _camera: Camera2D = $Camera2D
@onready var _fade: ColorRect = $Transition/Fade

var _level: LevelType
var _travelling := false
## World-space extent of the level on screen now; drives the camera.
var _bounds := Rect2()


func _ready() -> void:
	_enter_level(START_LEVEL, &"start")


func _process(_delta: float) -> void:
	_camera.global_position = _camera_target()


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

	# Frame the new level before the first frame of it is drawn, then drop the
	# smoothing history - otherwise the camera glides across from wherever the
	# level we just left had put it.
	_bounds = _level.bounds()
	_camera.global_position = _camera_target()
	_camera.reset_smoothing()


## Where the camera wants to be, decided per axis:
##
## - the level is wider/taller than the screen -> follow the player, stopping at
##   the walls so the void outside the map never comes into view
## - the level already fits -> sit on its centre and show the whole room
##
## Deliberately not Camera2D's own limits: those cannot express the second case.
## Asked to keep a 544 px room inside a 640 px view they contradict themselves,
## and the camera ends up jammed against one edge.
func _camera_target() -> Vector2:
	var view := get_viewport_rect().size / _camera.zoom
	var half := view * 0.5
	var centre := _bounds.get_center()
	var target := _player.global_position
	if view.x >= _bounds.size.x:
		target.x = centre.x
	else:
		target.x = clampf(target.x, _bounds.position.x + half.x, _bounds.end.x - half.x)
	if view.y >= _bounds.size.y:
		target.y = centre.y
	else:
		target.y = clampf(target.y, _bounds.position.y + half.y, _bounds.end.y - half.y)
	return target
