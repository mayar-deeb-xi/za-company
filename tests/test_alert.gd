extends "res://tests/helpers.gd"
## The room's one push: the moment the player steps off the walk lane, every
## enemy standing in the room is told the player is there, once - and then the
## ordinary leash takes it from there.
##
## Its own suite because every check is about a body that CANNOT see the
## player, which is the opposite of what test_combat.gd stages. Built in the
## empty lobby for test_steering.gd's reason: anything standing in it was put
## there by this file.
##
## What is checked is mostly what must NOT change: walking the lane wakes
## nobody, an alerted body still gives up on the same patience and walks back
## to the same post, and a second step off the lane in the same visit is
## nothing. Plus the one sweep that keeps it honest across the chain - no
## floor's spawn marker may sit off its own lane, or arriving would fire it.

const GUARD := "res://game/enemies/regular/regular.tscn"
const LOBBY := "res://game/levels/lobby/lobby.tscn"

## West of the lane, in the open row between the lobby's two west columns, and
## far enough from the player that sight (80) never reaches them in this file.
const POST := Vector2(40, 160)
const ON_LANE := Vector2(272, 160)
const OFF_LANE := Vector2(510, 160)
const OFF_AGAIN := Vector2(510, 140)

var _t0 := 0
var _guard: CharacterBody2D = null
var _farthest := 0.0
var _woke_again := false


func _tick(frame: int) -> void:
	if _t0 == 0:
		if frame == 1:
			_spawns()
		elif frame == 2:
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		elif frame == 17:
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
		elif frame > 20 and _level() != null:
			_t0 = frame
		return
	_lobby(frame - _t0)


## Every floor's arrival points, read off disk, against that floor's own walk.
func _spawns() -> void:
	var limit: float = (load("res://game/game.gd") as GDScript) \
		.get_script_constant_map()["LANE_ALERT_CLEARANCE"]
	var off: Array[String] = []
	for name: String in ["lobby", "content_studio", "call_center",
			"ahmed_office", "the_hub", "marble_hall", "innovation_lab",
			"conflict_resolution", "asset_recovery", "hellfire",
			"executive_floor", "khaled_office"]:
		var room := (load("res://game/levels/%s/%s.tscn" % [name, name])
			as PackedScene).instantiate()
		var spawns := room.get_node("Spawns") as Node2D
		for marker in spawns.get_children():
			var at: Vector2 = (spawns.transform * (marker as Node2D).transform).origin
			if float(room.call("lane_clearance", at)) > limit:
				off.append("%s/%s" % [name, marker.name])
		room.free()
	_check("chain: every spawn stands on its own lane, so arriving alerts nobody (%s)"
		% ("all of them" if off.is_empty() else ", ".join(off)), off.is_empty())


func _lobby(at: int) -> void:
	if _guard != null and is_instance_valid(_guard):
		_farthest = maxf(_farthest, POST.distance_to(_guard.global_position))
	match at:
		2:
			_guard = _spawn(POST)
			_player().global_position = ON_LANE
		62:
			_check("lane: a player walking the lane wakes nobody",
				not _guard.hunting)
			_check("lane: and the guard has not moved (%.1f px)"
				% POST.distance_to(_guard.global_position),
				POST.distance_to(_guard.global_position) < 1.0)
			_player().global_position = OFF_LANE
		65:
			var gap := _guard.global_position.distance_to(OFF_LANE)
			_check("alert: stepping off the lane puts the room on to you",
				_guard.hunting)
			_check("alert: without the guard being able to see you (%.0f px, sight %.0f)"
				% [gap, _guard.sight_radius], gap > _guard.sight_radius)
		95:
			_check("alert: and it comes your way (%.0f px east of its post)"
				% (_guard.global_position.x - POST.x),
				_guard.global_position.x - POST.x > 20.0)
		# 2.5 s of patience from frame 63, with slack.
		240:
			_check("leash: it still gives up on the ordinary patience",
				not _guard.hunting)
			_check("leash: having followed no further than its leash (%.0f of %.0f px)"
				% [_farthest, _guard.sight_radius * _guard.leash_factor],
				_farthest <= _guard.sight_radius * _guard.leash_factor + 1.0)
		520:
			_check("leash: and walks back onto its post (%.1f px off)"
				% POST.distance_to(_guard.global_position),
				POST.distance_to(_guard.global_position) <= 3.0)
			_player().global_position = ON_LANE
		525:
			_player().global_position = OFF_AGAIN
		526, 527, 528, 529, 530, 560, 600:
			_woke_again = _woke_again or _guard.hunting
			if at == 600:
				_check("once: stepping off the lane again in the same visit is nothing",
					not _woke_again)
				current_scene.call("_enter_level", LOBBY, &"start")
		602:
			_check("visit: a new arrival starts with its push unspent",
				not bool(current_scene.get("_lane_alerted")))
			_guard = _spawn(POST)
			_player().global_position = ON_LANE
		605:
			_player().global_position = OFF_LANE
		608:
			_check("visit: and spends it on its own", _guard.hunting)
		610:
			_finish()


func _spawn(at: Vector2) -> CharacterBody2D:
	var enemy := (load(GUARD) as PackedScene).instantiate() as CharacterBody2D
	_level().add_child(enemy)
	enemy.global_position = at
	return enemy
