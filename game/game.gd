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

const START_LEVEL := "res://game/levels/lobby/lobby.tscn"
const FADE_SECONDS := 0.28

## Typed by preloaded script rather than by the `class_name` those scripts also
## declare: global class names come from a cache the editor writes, which a
## fresh checkout running headless does not have yet.
const LevelType := preload("res://game/levels/level.gd")
const DoorType := preload("res://game/levels/door_base.gd")
const PlayerType := preload("res://game/player/player.gd")
const HudType := preload("res://ui/hud/hud.gd")
const PauseMenuType := preload("res://ui/pause_menu/pause_menu.gd")
const LevelTitleType := preload("res://ui/level_title/level_title.gd")

@onready var _player: PlayerType = $Player
@onready var _camera: Camera2D = $Camera2D
@onready var _fade: ColorRect = $Transition/Fade
@onready var _hud: HudType = $HUD/Hud
@onready var _title: LevelTitleType = $Title/LevelTitle
@onready var _pause_menu: PauseMenuType = $PauseMenu

var _level: LevelType
var _travelling := false
## World-space extent of the level on screen now; drives the camera.
var _bounds := Rect2()


func _ready() -> void:
	# Re-applied live: zoom is reachable from the pause menu, with the game
	# sitting right behind the panel.
	Display.changed.connect(_apply_zoom)
	# The player owns its health and lives; game.gd only wires them to the HUD
	# and decides what a death means. Pushed once here so the HUD never starts
	# blank.
	_player.health_changed.connect(_hud.set_health)
	_player.lives_changed.connect(_hud.set_lives)
	_player.died.connect(_on_player_died)
	_hud.set_health(_player.health, PlayerType.MAX_HEALTH)
	_hud.set_lives(_player.lives, PlayerType.MAX_LIVES)
	_enter_level(START_LEVEL, &"start")


func _process(_delta: float) -> void:
	_camera.global_position = _camera_target()


## Zoom decides how much world fits on screen, which in turn decides whether
## _camera_target() frames the room whole or follows the player around it.
func _apply_zoom() -> void:
	_camera.zoom = Vector2.ONE * Display.zoom()
	# Reposition here rather than waiting for _process: the tree is paused while
	# the settings panel is open, so nothing else would run until it closes.
	_camera.global_position = _camera_target()
	_camera.reset_smoothing()


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


## Each death spends one of the player's lives. While any remain, dying costs
## the ground covered in this room; the last one ends the run.
func _on_player_died() -> void:
	if _player.lose_life() > 0:
		_respawn()
	else:
		_game_over()


## The run is over: the pause overlay comes up as a death screen (YOU DIED,
## CONTINUE disabled) with the room still visible behind it, frozen by the
## tree pause. Leaving through MAIN MENU builds a fresh player next run, so
## health and lives reset by construction.
func _game_over() -> void:
	_player.velocity = Vector2.ZERO
	_pause_menu.show_game_over()


## Death with lives to spare is a fade back to this room's start marker with
## full health. Reuses the travel fade so dying and arriving read as the same
## kind of cut.
func _respawn() -> void:
	# A death can land mid-transition (a hazard right beside a door); let the
	# travel finish rather than fight it for the fade.
	while _travelling:
		await get_tree().process_frame
	_travelling = true
	_player.set_physics_process(false)
	_player.velocity = Vector2.ZERO

	var out := create_tween()
	out.tween_property(_fade, "color:a", 1.0, FADE_SECONDS)
	await out.finished

	_player.global_position = _level.spawn_position(&"start")
	_player.revive()

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
	_apply_zoom()

	# Announce the room. Called here rather than after the fade finishes, so the
	# name is already up on the black and the room appears behind it; and here
	# rather than from the door, so arriving at the start of a run names the
	# lobby too. A respawn deliberately does not come through here - dying and
	# getting up in the same room is not arriving somewhere.
	_title.show_title(_level.title())


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
