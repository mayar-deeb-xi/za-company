extends "res://tests/helpers.gd"
## Boss test: Ahmed's four attacks, the order he picks them in, the slam
## landing on his own adds, the wave at range, the interrupt, and the concede.
## Boots into the empty lobby like test_combat.gd and places him by hand, so
## his is the only fight in the room and the frame numbers below hold.
##
## Sequence rather than stopwatch: `_tick` samples his `attack` every frame and
## records each new one, so the checks read the order he fought in rather than
## betting on the exact frame a swing began.

var _boss: Node2D
var _boy: Node2D
var _seq: Array[String] = []
var _conceded_heard := false
var _interrupted_at := -1
var _phase_after_interrupt := -1
var _health_at_concede := -1


func _tick(frame: int) -> void:
	if _boss != null:
		var now: String = _boss.get("attack")
		if now != "" and (_seq.is_empty() or _seq[-1] != now):
			_seq.append(now)
		# The first frame of the first chop after the wave: hit him at the very
		# start of the wind-up, where the interrupt rules say it must stagger him.
		if frame > 420 and _interrupted_at < 0 and now == "chop" and _boss.get("phase") == 1:
			_boss.call("take_damage", 1)
			_interrupted_at = frame
		elif _interrupted_at > 0 and frame == _interrupted_at + 1:
			_phase_after_interrupt = _boss.get("phase")

	match frame:
		2:
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		17:
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
		32:
			_check("bosses: the lobby starts empty, so the fight is placed (%d)"
				% get_nodes_in_group("enemies").size(),
				get_nodes_in_group("enemies").is_empty())
			_boss = (load("res://game/bosses/ahmed/ahmed.tscn") as PackedScene).instantiate() as Node2D
			_level().get_node("Props").add_child(_boss)
			_boss.connect("conceded", func() -> void: _conceded_heard = true)
			_check("bosses: Ahmed opens at 96 - four heavies (%s)" % _boss.get("health"),
				_boss.get("health") == 96)
			_check("bosses: he is a boss and an enemy",
				_boss.is_in_group("bosses") and _boss.is_in_group("enemies"))
			_check("bosses: he faces the fight sideways only (animation %s)"
				% _sprite_of(_boss).animation, _sprite_of(_boss).animation == &"idle_side")
			# Mid-room, clear of the furniture; he is inside his own sight and
			# 60 px off, which at speed 40 is a second's walk to stop distance.
			_player().global_position = Vector2(272, 140)
			_boss.global_position = Vector2(272, 200)
			# An add for the slam to catch. Sight zeroed so it stands where it is
			# put and never swings at the player - the only thing that can hurt it
			# in this room is Ahmed.
			_boy = (load("res://game/enemies/office_boy/office_boy.tscn") as PackedScene).instantiate() as Node2D
			_level().get_node("Props").add_child(_boy)
			_boy.set("sight_radius", 0.0)
			_boy.global_position = Vector2(300, 175)
		62:
			_check("bosses: he closes the ground (%.0f px away)"
				% _boss.global_position.distance_to(_player().global_position),
				_boss.global_position.distance_to(_player().global_position) < 50.0)
		110:
			_check("bosses: arrived, he winds up (phase %s, attack '%s')"
				% [_boss.get("phase"), _boss.get("attack")],
				_boss.get("phase") == 1 and _boss.get("attack") == "chop")
			_check("bosses: the attack's own animation is the telegraph (%s)"
				% _sprite_of(_boss).animation, _sprite_of(_boss).animation == &"chop_side")
			_check("bosses: nothing has landed yet (%s)" % _player().get("health"),
				_player().get("health") == 100)
			var gap: float = _boss.global_position.distance_to(_player().global_position)
			# Touch is r 24 and the player's body r 5, so contact - and the wind-up
			# that roots him - comes at ~29 px, before stop_distance ever would.
			_check("bosses: he stops at the axe's reach, not in your face (%.1f px)" % gap,
				gap > 24.0 and gap < 33.0)
		150:
			_check("bosses: the chop lands 16 (%s)" % _player().get("health"),
				_player().get("health") == 84)
		305:
			_check("bosses: chop, then sweep, then the slam (%s)" % str(_seq),
				_seq == ["chop", "sweep", "slam"])
			_check("bosses: sweep 12 and slam 20 have landed (%s)" % _player().get("health"),
				_player().get("health") == 52)
			_check("bosses: the slam hits everyone in the ring - the office boy too (%s)"
				% _boy.get("health"), _boy.get("health") == 4)
			# Out of reach, straight ahead: the wave is for exactly this.
			_player().global_position = _boss.global_position + Vector2(60, 0)
		410:
			_check("bosses: out of reach in the lane, he sends the wave (%s)" % str(_seq),
				_seq.size() == 4 and _seq[3] == "wave")
			_check("bosses: the wave lands 14 at 60 px (%s)" % _player().get("health"),
				_player().get("health") == 38)
		560:
			_check("bosses: an early hit on a wind-up staggers him (hit at %d, phase after %d)"
				% [_interrupted_at, _phase_after_interrupt],
				_interrupted_at > 0 and _phase_after_interrupt == 3)
			_check("bosses: he keeps fighting after the wave (%s)" % str(_seq),
				_seq.size() >= 5)
			_health_at_concede = _player().get("health")
			_boss.call("take_damage", 500)
			_check("bosses: at zero he concedes (%s)" % _boss.get("has_conceded"),
				_boss.get("has_conceded") == true)
			_check("bosses: conceding is a signal the door can hear", _conceded_heard)
			_check("bosses: a conceded boss is out of the fight but still in the room",
				not _boss.is_in_group("enemies") and _boss.is_inside_tree()
				and _boss.is_in_group("bosses"))
		565:
			_check("bosses: he kneels rather than vanishing (%s)"
				% _sprite_of(_boss).animation, _sprite_of(_boss).animation == &"concede_side")
			_check("bosses: nothing more lands on the player (%s -> %s)"
				% [_health_at_concede, _player().get("health")],
				_player().get("health") == _health_at_concede)
			_finish()


func _sprite_of(enemy: Node2D) -> AnimatedSprite2D:
	return enemy.get_node("AnimatedSprite2D") as AnimatedSprite2D
