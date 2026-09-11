extends "res://tests/helpers.gd"
## Getting round the furniture: whether an enemy with something solid between
## it and the player ever arrives.
##
## Its own suite because it needs a room arranged WRONG. Every floor in the
## game is dressed so the fight works - the door lane is clear, the enemies are
## placed off it, the furniture is where a room's furniture goes - and none of
## them is a fair test of what happens when a body and its target end up on
## opposite sides of a desk. So this one builds the bad case by hand in the
## empty lobby, which is what test_reinforcements.gd and test_ivan.gd already
## do with their beats and for the same reason.
##
## ## What was wrong
##
## Steering is `walk at the player`, and `move_and_slide` handles a glancing
## approach by sliding. The case it cannot handle is the one it CREATES: as a
## blocked body slides it comes to face the player ever more directly, the
## sideways part of the walk decays to nothing, and it parks square against the
## obstacle with the player a few tiles beyond. Hunting, awake, and unable to
## reach anybody ever again - and because the attack cycle is gated on
## `touching_player`, that reads in the game as an enemy that does not attack.
##
## Two desks and a guard reproduced it in about two seconds. The fix is
## `_steer` in game/enemies/enemy_base.gd: commit to one side and hold it until
## a ray says the way is open, rather than re-aiming every frame.
##
## ## What is checked, and why the last one is the important one
##
## The first three are the bug: it arrives, it swings, and it got there by
## going round the desk rather than by some accident of the geometry. The
## fourth is the part a fix like this usually gets wrong - a heuristic that
## cannot lose will grind forever in the one arrangement it cannot solve, so a
## body walled in has to give up and go home rather than wear a groove in the
## wall it is standing against. And the fifth
## is the promise the other four are worthless without: a body with nothing in
## its way must be unchanged, or every number in game/enemies/CLAUDE.md has
## quietly moved. The sixth and last is B's half of the same day's work: the
## small furniture is on its own collision layer, so a chair is something an
## enemy walks THROUGH rather than something it has to be clever about.
##
## ## Why it is built in the lobby
##
## Floor 1 is the one room with no enemies in it at all, so anything standing
## in it was put there by this file. Nothing else is moving, nothing else is
## draining, and a health check has exactly one cause.

const DESK := "res://game/levels/lobby/props/furniture/desk.tscn"
const CHAIR := "res://game/levels/lobby/props/furniture/chair.tscn"
const GUARD := "res://game/enemies/regular/regular.tscn"

## The wall of desks, and the guard behind it. 38 px each, butted end to end,
## so the pocket runs x 181 to 257 - 29 px to clear it going west and 52 going
## east, and the body has no way of knowing which it picked.
const DESK_A := Vector2(200, 226)
const DESK_B := Vector2(238, 226)
## Square on, which is the shape that used to be fatal: straight at the player
## from here runs into the middle of a desk with no lean either way.
const BEHIND := Vector2(210, 260)
const INFRONT := Vector2(210, 190)

## The walled-in case for the give-up: three desks stacked into a wall with the
## guard pinned between them and the room's own west wall, and the player above
## it. There is no step that opens the way, which is the whole point - the
## check is that it stops trying, not that it fails to escape.
const PEN := [Vector2(100, 120), Vector2(100, 158), Vector2(100, 196)]
const PENNED := Vector2(84, 158)
const ABOVE_PEN := Vector2(84, 60)

## Nothing in the way at all, well inside the guard's 80 px sight.
const OPEN_FROM := Vector2(400, 120)
const OPEN_TO := Vector2(400, 170)

## The clutter case: a chair between the two, which the enemy should not so
## much as notice. Layer 2, and an enemy masks only the world - tools/props.gd
## has the why.
const CHAIR_AT := Vector2(470, 262)
const CHAIR_BEHIND := Vector2(470, 290)
const CHAIR_INFRONT := Vector2(470, 236)

var _guard: CharacterBody2D = null
var _t0 := 0
var _closest := 999.0
## How far off its own line the guard ever got, which is what going AROUND
## something means - the end position cannot say, because by then it has come
## back to the player.
var _widest := 0.0


func _tick(frame: int) -> void:
	if _t0 == 0:
		if frame == 2:
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		elif frame == 17:
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
		elif frame > 20 and _level() != null:
			_t0 = frame
		return
	_lobby(frame - _t0)


func _lobby(at: int) -> void:
	match at:
		2:
			_desk(DESK_A)
			_desk(DESK_B)
			_guard = _spawn(BEHIND)
			_player().global_position = INFRONT
			_check("setup: the guard can see the player through the desk (%.0f px)"
				% _guard.global_position.distance_to(INFRONT),
				_guard.global_position.distance_to(INFRONT)
					<= _guard.sight_radius)
			_check("setup: and is not already touching them",
				not _guard.touching_player)
		3, 4, 5:
			# Held still. The player standing still is the hard version: a
			# moving target keeps the walk off the perpendicular by itself,
			# which is exactly the accident that hid this for twelve floors.
			_player().global_position = INFRONT
		_:
			_walled(at)
			_open(at)
			_clutter(at)
			# `at` reaches 1 before the room has been arranged at 2, which is
			# the only frame in this suite with no guard standing in it.
			if at > 2 and at < 200 and _guard != null:
				_player().global_position = INFRONT
				_closest = minf(_closest,
					_guard.global_position.distance_to(INFRONT))
				_widest = maxf(_widest,
					absf(_guard.global_position.x - BEHIND.x))


func _walled(at: int) -> void:
	match at:
		200:
			_check("desk: it got round the furniture and reached the player (%.0f px)"
				% _closest, _closest <= _guard.stop_distance + 2.0)
			_check("desk: and swung once it was there",
				_guard.phase != _guard.Phase.CHASE or _guard.touching_player)
			# AROUND it, not through it. Which side is deliberately not
			# checked: with nothing leaning it either way the body knows the
			# desk is in the way and nothing at all about its shape, so it
			# picks a side and finds out - see enemy_base._around().
			_check("desk: by going round the end rather than through it (%.0f px off its line)"
				% _widest, _widest > 20.0)
			_guard.queue_free()
			for desk in [DESK_A, DESK_B]:
				_prop_at(desk).queue_free()
			for at_pen in PEN:
				_desk(at_pen)
			_guard = _spawn(PENNED)
		203, 204, 205:
			_player().global_position = ABOVE_PEN
		206:
			_health_mark = _guard.max_health
			_mark = _guard.global_position
		# Three steps that run the whole 1.5s cap, plus the 0.12s it takes to
		# notice each one, is a little under 5s. Checked at 7s, by which point
		# it has to have stopped hunting and be on its way back.
		626:
			_check("penned: a body that cannot get round it stops trying",
				not _guard.hunting)
			_check("penned: and heads back to its post rather than grinding (%.0f px moved)"
				% _mark.distance_to(_guard.global_position),
				_mark.distance_to(_guard.global_position) > 4.0)
			_guard.queue_free()
			for at_pen in PEN:
				_prop_at(at_pen).queue_free()


func _open(at: int) -> void:
	match at:
		628:
			_guard = _spawn(OPEN_FROM)
			_player().global_position = OPEN_TO
		630, 631, 632:
			_player().global_position = OPEN_TO
		# 50 px at 55 px/s is a little under a second. Checked at 1.5s: a
		# straight walk has to be a straight walk, and a body that now
		# side-steps its way across an empty room has broken every distance
		# in the tuning.
		716:
			_player().global_position = OPEN_TO
			_check("open: nothing in the way is still a straight walk (%.0f px)"
				% _guard.global_position.distance_to(OPEN_TO),
				_guard.global_position.distance_to(OPEN_TO)
					<= _guard.stop_distance + 2.0)
			_check("open: dead on the line it started on (x %.0f, expected 400)"
				% _guard.global_position.x,
				absf(_guard.global_position.x - OPEN_FROM.x) < 3.0)
			_guard.queue_free()


func _clutter(at: int) -> void:
	match at:
		718:
			var chair := (load(CHAIR) as PackedScene).instantiate() as StaticBody2D
			chair.position = CHAIR_AT
			_level().get_node("Props").add_child(chair)
			_check("clutter: a chair is on the clutter layer, not the world's (%d)"
				% chair.collision_layer, chair.collision_layer == 2)
			_guard = _spawn(CHAIR_BEHIND)
			_player().global_position = CHAIR_INFRONT
		720, 721, 722:
			_player().global_position = CHAIR_INFRONT
		# Straight through it, so the same second a clear walk takes.
		806:
			_player().global_position = CHAIR_INFRONT
			_check("clutter: an enemy walks through a chair rather than round it (%.0f px)"
				% _guard.global_position.distance_to(CHAIR_INFRONT),
				_guard.global_position.distance_to(CHAIR_INFRONT)
					<= _guard.stop_distance + 2.0)
			_check("clutter: without ever leaving its line (x %.0f, expected 470)"
				% _guard.global_position.x,
				absf(_guard.global_position.x - CHAIR_AT.x) < 3.0)
			# The other half of the promise, and the half that makes it a
			# choice rather than a deletion: the room is still solid for the
			# person who can see it. test_move() asks the physics server what
			# a step would do without taking it, so this needs no input and no
			# frames - and it is asked of the PLAYER's own body, mask and all.
			_check("clutter: and the player still walks into it",
				_player().test_move(Transform2D(0.0, CHAIR_INFRONT),
					Vector2(0.0, 24.0)))
		811:
			_finish()


## One desk, standing where it is told. The lobby's own, because a level owns
## everything in it and this suite is standing in the lobby.
func _desk(at: Vector2) -> void:
	var desk := (load(DESK) as PackedScene).instantiate() as Node2D
	desk.position = at
	_level().get_node("Props").add_child(desk)


func _prop_at(at: Vector2) -> Node:
	for child in _level().get_node("Props").get_children():
		if (child as Node2D).position.is_equal_approx(at):
			return child
	return null


## A guard, posted where it is dropped. Added to the level rather than to Props
## so it is in the room on the same terms every other enemy is.
func _spawn(at: Vector2) -> CharacterBody2D:
	var enemy := (load(GUARD) as PackedScene).instantiate() as CharacterBody2D
	_level().add_child(enemy)
	enemy.global_position = at
	return enemy
