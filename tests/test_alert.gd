extends "res://tests/helpers.gd"
## The room's one push: the moment the player is more than three tiles from
## where they came in, every enemy standing in the room is told the player is
## there, once - and then the ordinary leash takes it from there.
##
## Its own suite because every check is about a body that CANNOT see the
## player, which is the opposite of what test_combat.gd stages. Built in the
## empty lobby for test_steering.gd's reason: anything standing in it was put
## there by this file.
##
## The doorway is the only safe ground. Standing just inside it wakes nobody;
## walking on towards the far door - the old safe lane - is walking into the
## room, and wakes it. Everything after that is what must NOT change: an alerted
## body still gives up on the same patience and walks back to the same post,
## and a second trip out in the same visit is nothing.
##
## And the one thing that changes for good: a reinforcement walking in after the
## alert is told on arrival, and having no post it keeps coming past the
## patience a placed body would have gone home on.

const GUARD := "res://game/enemies/regular/regular.tscn"
const LOBBY := "res://game/levels/lobby/lobby.tscn"

## West of the lane, in the open row between the lobby's two west columns, and
## far enough from the player that sight (80) never reaches them in this file.
const POST := Vector2(40, 160)
## The lobby's `start` marker is (272, 240), where the south door puts you.
## Two tiles up from it: still in the doorway.
const NEAR_DOOR := Vector2(272, 208)
## On the walk to the north door, seven and a half tiles from where you came in.
const TOWARD_EXIT := Vector2(272, 120)
const OFF_LANE := Vector2(510, 160)
const OFF_AGAIN := Vector2(510, 140)

var _t0 := 0
var _guard: CharacterBody2D = null
var _arrival: CharacterBody2D = null
var _farthest := 0.0
var _woke_again := false


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
	if _guard != null and is_instance_valid(_guard):
		_farthest = maxf(_farthest, POST.distance_to(_guard.global_position))
	match at:
		2:
			_guard = _spawn(POST)
			_check("door: you arrive where the start marker is (%s)"
				% _player().global_position,
				_player().global_position == _level().call("spawn_position", &"start"))
			_player().global_position = NEAR_DOOR
		62:
			var radius: float = current_scene.get_script() \
				.get_script_constant_map()["ALERT_RADIUS"]
			_check("door: standing in the doorway wakes nobody (%.0f px in, %.0f allowed)"
				% [NEAR_DOOR.distance_to(_level().call("spawn_position", &"start")), radius],
				not _guard.hunting and not bool(current_scene.get("_room_alerted")))
			_check("door: and the guard has not moved (%.1f px)"
				% POST.distance_to(_guard.global_position),
				POST.distance_to(_guard.global_position) < 1.0)
			_player().global_position = TOWARD_EXIT
		65:
			var gap := _guard.global_position.distance_to(TOWARD_EXIT)
			_check("alert: walking on towards the far door puts the room on to you",
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
			_player().global_position = NEAR_DOOR
		525:
			_player().global_position = OFF_AGAIN
		526, 527, 528, 529, 530, 560, 600:
			_woke_again = _woke_again or _guard.hunting
			if at == 600:
				_check("once: going out into the room again in the same visit is nothing",
					not _woke_again)
				current_scene.call("_enter_level", LOBBY, &"start")
		602:
			_check("visit: a new arrival starts with its push unspent",
				not bool(current_scene.get("_room_alerted")))
			_guard = _spawn(POST)
		605:
			_player().global_position = OFF_LANE
		608:
			_check("visit: and spends it on its own", _guard.hunting)
			# Out of the way, so the only body left is the one walking in next.
			_guard.queue_free()
		610:
			_arrival = _arrive(POST)
		612:
			_check("arrival: a body walking in after the alert is told on its way in",
				_arrival.hunting)
			_check("arrival: without being able to see you (%.0f px, sight %.0f)"
				% [_arrival.global_position.distance_to(OFF_LANE), _arrival.sight_radius],
				_arrival.global_position.distance_to(OFF_LANE) > _arrival.sight_radius)
		# 2.5 s of patience from frame 610 ran out around 760; well past it.
		840:
			var walked := _arrival.global_position.x - POST.x
			var patience_walk: float = _arrival.speed * _arrival.patience_seconds
			_check("arrival: having no post, it does not give up on the patience",
				_arrival.hunting)
			_check("arrival: and is still coming (%.0f px east, patience alone walks %.0f)"
				% [walked, patience_walk], walked > patience_walk)
			_finish()


func _spawn(at: Vector2) -> CharacterBody2D:
	var enemy := (load(GUARD) as PackedScene).instantiate() as CharacterBody2D
	_level().add_child(enemy)
	enemy.global_position = at
	return enemy


## A reinforcement, the way game/levels/reinforcements.gd's _spawn makes one:
## into Props, placed one line after add_child, and given no post.
func _arrive(at: Vector2) -> CharacterBody2D:
	var enemy := (load(GUARD) as PackedScene).instantiate() as CharacterBody2D
	_level().get_node("Props").add_child(enemy)
	enemy.global_position = at
	enemy.call("unleash")
	return enemy
