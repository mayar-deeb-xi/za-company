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
const DialogueType := preload("res://game/dialogue/dialogue_director.gd")
const SubtitleType := preload("res://ui/subtitle/subtitle.gd")

@onready var _player: PlayerType = $Player
@onready var _camera: Camera2D = $Camera2D
@onready var _fade: ColorRect = $Transition/Fade
@onready var _hud: HudType = $HUD/Hud
@onready var _title: LevelTitleType = $Title/LevelTitle
@onready var _pause_menu: PauseMenuType = $PauseMenu
@onready var _dialogue: DialogueType = $Dialogue
@onready var _subtitle: SubtitleType = $Subtitle/BossSubtitle

var _level: LevelType
var _travelling := false
## World-space extent of the level on screen now; drives the camera.
var _bounds := Rect2()
## Camera shake: world pixels of throw, and how much of it is left to spend.
var _shake_throw := 0.0
var _shake_left := 0.0
var _shake_span := 0.12


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
	# Every friendly face in the game, wired once here rather than per room -
	# see _on_node_added. Connected BEFORE the first level is built, because
	# building one is what adds the first of them.
	get_tree().node_added.connect(_on_node_added)
	# The front end's track ends here rather than at the character select, so
	# it carries over the load and goes out under the first room's fade-in.
	Music.fade_out()
	_enter_level(START_LEVEL, &"start")


func _process(delta: float) -> void:
	_camera.global_position = _camera_target()
	_apply_shake(delta)


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
	# A door reached mid-conversation ends it: the NPC saying the line is about
	# to be freed with the room, and the player must not arrive next door still
	# under someone else's control.
	_dialogue.stop()
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
	# Dying hands the body back before anything else does anything with it -
	# a respawn moves the player, and a conversation still holding the wheel
	# would keep walking them back towards whoever was talking.
	_dialogue.stop()
	# And whatever the boss was shouting goes with it: the player is about to
	# be somewhere the line was not said.
	_subtitle.clear()
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

	_watch_boss()

	# Nothing carries over from the room just left, the camera least of all: a
	# shake still decaying would offset the first frame of the new one, and a
	# line still up would be shouted by a boss who is now a floor away.
	_shake_left = 0.0
	_camera.offset = Vector2.ZERO
	_subtitle.clear()

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


## The friendly faces, and the one thing in this scene that is wired as people
## ARRIVE rather than as a room is built. An NPC raises its hand; the director
## in this scene does the talking, and nothing in game.gd knows what any of them
## says.
##
## The doors above can be found by group the moment the level goes in, because
## a room has all the doors it will ever have. People it does not: a floor that
## has been cleared walks Ivan in through one of those doors minutes later
## (game/levels/relief.gd), and an NPC who arrives after the sweep would never
## be connected to anything - his prompt would come up and the key would do
## nothing. Listening to the tree instead catches both, since instancing a level
## adds every node in it one at a time too.
func _on_node_added(node: Node) -> void:
	if not node.is_in_group("npcs") or not node.has_signal(&"talk_requested"):
		return
	if not node.is_connected(&"talk_requested", _on_talk_requested):
		node.connect(&"talk_requested", _on_talk_requested)


func _on_talk_requested(npc: Node2D) -> void:
	# Declined while the room is changing under everyone's feet: the fade is
	# already running and the NPC is about to be freed with the level.
	if _travelling:
		return
	_dialogue.talk(npc, _player)


## A boss floor puts a second bar on screen. Found by GROUP at the moment the
## room is built, exactly like the doors above and for the same reason:
## nothing in game.gd names a boss, and a floor without one simply clears the
## bar. A floor whose boss has already conceded - the player walking back down
## through a fight they have won - clears it too.
##
## Wired by signal rather than asked every frame, which is the HUD's shape:
## the player's own health arrives the same way. He is never freed, so the bar
## comes down on `conceded` rather than on him disappearing.
##
## His MUSIC is the third thing hung here, for the same reason as the other
## two: a boss floor is the only floor with a track, and the moments it starts
## and stops are exactly the moments the bar goes up and comes down. Which is
## also what makes the silence right - a floor with no live boss fades out
## whatever was playing, so walking back down through a fight already won is
## as quiet as the fight is over, and no room has to say so.
func _watch_boss() -> void:
	_hud.clear_boss()
	var theme := ""
	for node in get_tree().get_nodes_in_group("bosses"):
		if not node.has_method("title") or node.get("has_conceded"):
			continue
		_hud.set_boss(node.call("title"), node.get("health"), node.get("max_health"))
		node.connect(&"health_changed", Callable(_hud, "set_boss_health"))
		node.connect(&"conceded", Callable(_hud, "clear_boss"))
		# A boss may also shake the room. Checked for rather than assumed, so a
		# boss who never throws the camera about needs no shake code of his own
		# - the same deal the bar gets one line above.
		if node.has_signal(&"shook"):
			node.connect(&"shook", Callable(self, "_shake"))
		# And a mouth, on the same terms again. A boss who says nothing emits
		# nothing, so no floor and nothing here has to know which of them talk.
		if node.has_signal(&"said"):
			node.connect(&"said", Callable(self, "_on_boss_said"))
		# And a theme, on the same terms. `get` rather than a typed read so a
		# boss predating the export is a boss with no track, not a crash.
		var declared: Variant = node.get("music")
		theme = declared if declared is String else ""
		if theme != "":
			# And back to the bed when he gives in. Not silence: the floor is an
			# ordinary floor the moment he concedes - Ivan walks in on half of
			# them - and the theme leaving is the fight ending, not the music
			# ending.
			node.connect(&"conceded", Callable(Music, "fade_to").bind(Music.DEFAULT))
		break

	# After the loop, not inside it: a floor with no boss AND a boss floor whose
	# boss has already conceded both land here, and both want the bed rather
	# than a theme of anyone's.
	#
	# `fade_to` and not `play`, because the menu track is still going as the
	# first room is built (_ready has just asked it to leave) and a straight
	# `play` would cut it dead - this queues the bed behind the fade it is
	# already taking. It is idempotent on the track for the other nine floors,
	# so a door between two ordinary rooms does not restart the bed underneath
	# it: the music crosses the building with the player, and only a boss
	# interrupts it.
	if theme == "":
		Music.fade_to(Music.DEFAULT)
	else:
		Music.play(theme)


## A boss shouting. Dropped rather than queued while an NPC is talking: the
## dialogue box is at the bottom of the screen too, and it holds the player's
## hands as well as their eyes - a line shouted over it would be the one thing
## on screen they could not answer. Nothing is lost by dropping it, because a
## bark is only ever about the moment it was said in.
func _on_boss_said(speaker: String, text: String, seconds: float) -> void:
	if _dialogue.talking():
		return
	_subtitle.show_line(speaker, text, seconds)


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


## A blow landed hard enough to move the room. Reached by signal from whoever
## threw it; applied here because this is what owns a camera.
func _shake(strength: float, seconds: float) -> void:
	_shake_throw = strength
	_shake_span = maxf(seconds, 0.001)
	_shake_left = _shake_span


## The shake as an OFFSET, so _camera_target() above stays the only thing that
## decides where the camera is pointed. Framing a room and being shoved about
## are separate questions, and adding them together would fight the clamping
## that keeps the void outside the map off screen.
##
## Quantized to whole world pixels, because a camera parked on a fraction of
## one is exactly what makes a pixel-art room crawl - the same reason the
## window size setting only offers whole multiples of the base viewport.
func _apply_shake(delta: float) -> void:
	if _shake_left <= 0.0:
		if _camera.offset != Vector2.ZERO:
			_camera.offset = Vector2.ZERO
		return
	_shake_left = maxf(_shake_left - delta, 0.0)
	var mag := _shake_throw * (_shake_left / _shake_span)
	var tick := Time.get_ticks_msec()
	_camera.offset = Vector2(
		roundf(_jitter(tick, 1) * 2.0 * mag),
		roundf(_jitter(tick, 2) * mag))


## -0.5..0.5, steady within a frame and different the next.
static func _jitter(a: int, b: int) -> float:
	return float(absi((a * 73856093) ^ (b * 19349663)) % 1000) / 1000.0 - 0.5
