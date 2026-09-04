extends "res://tests/helpers.gd"
## Combat test: the guard's telegraphed strike and the interrupt rules, the
## combo kill, the wraith's drain, the warden's wind-up and slow, and the heavy
## attack. Boots straight through the menu into the lobby, which is floor 1 and
## deliberately empty, and places each enemy under test by hand - so exactly one
## fight happens at a time by construction rather than by keeping the room's own
## enemies out of each other's sight radius. They are the real scenes either way.

var _enemy: Node2D
var _wraith: Node2D
var _warden: Node2D


func _tick(frame: int) -> void:
	match frame:
		2:
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		17:
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
		32:
			_check("enemies: the lobby starts empty, so every fight is placed (%d)"
				% get_nodes_in_group("enemies").size(),
				get_nodes_in_group("enemies").is_empty())
			var guard_scene := load("res://game/enemies/regular/regular.tscn") as PackedScene
			_enemy = guard_scene.instantiate() as Node2D
			_level().get_node("Props").add_child(_enemy)
			_check("enemies: a guard starts at full health (%s)"
				% _enemy.get("health"), _enemy.get("health") == 24)
			# Park mid-room, clear of props, and bring the guard inside its own
			# sight. The player has not moved this run, so they still face down -
			# the guard approaches straight into the swing.
			_player().global_position = Vector2(272, 140)
			_enemy.global_position = Vector2(272, 190)
		58:
			_check("enemies: the guard chases the player (%.0f px away)"
				% _enemy.global_position.distance_to(_player().global_position),
				_enemy.global_position.distance_to(_player().global_position) < 45.0)
		84:
			# It arrived around frame 71 and is mid-telegraph. THIS is the rule
			# that changed: being touched by an enemy is no longer being hurt by
			# one, so a wind-up in progress has cost nothing yet.
			_check("enemies: arriving costs nothing - the blow is the strike (%s)"
				% _player().get("health"), _player().get("health") == 100)
			_check("enemies: the guard is winding up, rooted (phase %s)"
				% _enemy.get("phase"), _enemy.get("phase") == 1)
			var guard_gap: float = _enemy.global_position.distance_to(
				_player().global_position)
			_check("enemies: the guard stops short instead of grinding in (%.1f px)"
				% guard_gap, guard_gap > 10.0 and guard_gap < 15.0)
		114:
			# The wind-up finished around 98 and only THEN did it cost anything.
			_check("enemies: a completed wind-up lands the blow (%s)"
				% _player().get("health"), _player().get("health") == 90)
			# Out of its own sight, so it finishes its cycle and settles back to
			# CHASE - which gives the interrupt test below a known starting point.
			_enemy.global_position = Vector2(100, 40)
		178:
			_check("enemies: away from the player it returns to chasing (phase %s)"
				% _enemy.get("phase"), _enemy.get("phase") == 0)
			# Right on top of the player: contact next frame, wind-up from ~179.
			_enemy.global_position = Vector2(272, 152)
			_health_mark = _player().get("health")
		182:
			_key(KEY_SPACE, true)
		184:
			_key(KEY_SPACE, false)
		189:
			# Hit three frames into a 27-frame wind-up, far inside commit_fraction
			# and with no cooldown running, so the swing is cancelled outright.
			_check("interrupt: an early hit staggers the guard (phase %s, health %s)"
				% [_enemy.get("phase"), _enemy.get("health")],
				_enemy.get("phase") == 3 and _enemy.get("health") == 19)
		209:
			# The blow it had been winding up would have landed around 206.
			_check("interrupt: the cancelled blow never lands (%s, was %d)"
				% [_player().get("health"), _health_mark],
				_player().get("health") == _health_mark)
			# Second hit, inside the 1.2s cooldown that started at 182. It is
			# early in the restarted wind-up, so ONLY the cooldown can stop this
			# from being a second free interrupt - which is the whole anti-mash
			# rule in one press.
			_key(KEY_SPACE, true)
		211:
			_key(KEY_SPACE, false)
		216:
			_check("interrupt: a second hit inside the cooldown does NOT stagger (phase %s)"
				% _enemy.get("phase"), _enemy.get("phase") == 1)
		239:
			_check("interrupt: so that blow lands, and mashing cannot lock it out (%s)"
				% _player().get("health"), _player().get("health") == _health_mark - 10)
			# 14 health left: kill it the way a player would, on the combo. It
			# dies around 276; the mash stops well before the kill check so the
			# last buffered attack has finished by then. An enemy placed while a
			# swing is still live would be inside the hitbox and eat it, which is
			# correct of the game and ruinous for a test that then measures how
			# much one deliberate hit costs.
			_mash_until = 279
		309:
			_check("attack: the guard dies to a chained combo (%d left)"
				% get_nodes_in_group("enemies").size(),
				not is_instance_valid(_enemy)
					and get_nodes_in_group("enemies").is_empty())
			# Back to a known spot before the next fight. The thrust lunges the
			# player forward, so a combo leaves them a good few pixels down-range
			# of where they started - which quietly moves every geometry the rest
			# of this run sets up.
			_player().global_position = Vector2(272, 140)
			# The wraith, placed by hand rather than walked to in hellfire: the
			# drain is a rate, and a rate needs contact to start on a frame the
			# test knows. It is the real scene either way.
			var wraith_scene := load("res://game/enemies/wraith/wraith.tscn") as PackedScene
			_wraith = wraith_scene.instantiate()
			_level().get_node("Props").add_child(_wraith)
			_wraith.global_position = Vector2(272, 152)
			# Pinned to a known rate AFTER _ready has applied the difficulty
			# scale: the shipped default is 3/s and mode-dependent, and this
			# section proves the metering, not the tuning.
			_wraith.set("drain_per_second", 1.0)
			_health_mark = _player().get("health")
		451:
			# 142 frames of contact at one point per second. Exactly two, and
			# nothing like the 10 a guard's strike would have cost in that time -
			# which is the check that it really has no attack to telegraph.
			_check("wraith: drains one point per second of proximity (%d -> %s)"
				% [_health_mark, _player().get("health")],
				_health_mark - int(_player().get("health")) == 2)
			# Held at stop_distance, not grinding into the player's collision and
			# not stalled out of its own aura either - and never attacking.
			var gap: float = _wraith.global_position.distance_to(_player().global_position)
			_check("wraith: holds station close by instead of pushing in (%.1f px, '%s')"
				% [gap, _wraith.get_node("AnimatedSprite2D").animation],
				gap > 10.0 and gap < 14.0
					and not String(_wraith.get_node("AnimatedSprite2D").animation)
						.begins_with("attack"))
			# The point of drain() existing. Land a normal hit to open a grace
			# window, then stay well inside it: a drain routed through
			# take_damage() would be swallowed whole and the loss would be the
			# 5 of the hit alone. The rate is turned up so the tick lands inside
			# the window rather than straddling it.
			_wraith.set("drain_per_second", 4.0)
			_health_mark = _player().get("health")
			_player().call("take_damage", 5)
		481:
			# 30 frames later - still inside the grace window.
			_check("wraith: the drain lands during the grace window a hit opens (lost %d)"
				% (_health_mark - int(_player().get("health"))),
				_health_mark - int(_player().get("health")) >= 6)
			_key(KEY_SPACE, true)
		483:
			_key(KEY_SPACE, false)
		511:
			_check("wraith: takes ATTACK_POWER like anything else (health %s)"
				% (str(_wraith.get("health")) if is_instance_valid(_wraith) else "<freed>"),
				is_instance_valid(_wraith) and _wraith.get("health") == 12)
			# Squishier than a guard on purpose: nothing about it can be
			# interrupted, so bursting it down is the answer that replaces the
			# stagger every other enemy offers.
			_mash_until = 543
		579:
			_check("wraith: dies in three hits, the softest of the three (%d left)"
				% get_nodes_in_group("enemies").size(),
				not is_instance_valid(_wraith)
					and get_nodes_in_group("enemies").is_empty())
			# Pinned again after the combo's lunges, so "80 px off" is true.
			_player().global_position = Vector2(272, 140)
			# The warden, 80 px off: far enough that it has to walk in, close
			# enough that it arrives inside a second.
			var warden_scene := load("res://game/enemies/warden/warden.tscn") as PackedScene
			_warden = warden_scene.instantiate()
			_level().get_node("Props").add_child(_warden)
			_warden.global_position = Vector2(272, 220)
			_health_mark = _player().get("health")
		655:
			# It reached its own rim around frame 611 and planted there. The
			# other two stop at 12 px; this one has to stay out at ~53, or its
			# area means nothing and it dies for free.
			var reach: float = _warden.global_position.distance_to(_player().global_position)
			_check("warden: plants at the rim of its area, not in your face (%.1f px)"
				% reach, reach > 46.0 and reach < 58.0)
			_check("warden: costs no health at all (%s)" % _player().get("health"),
				_player().get("health") == _health_mark)
			_check("warden: two seconds not yet up, so nothing has landed (x%.2f)"
				% _player().get("slow_factor"),
				_player().get("slow_factor") == 1.0)
			# Step out of the area with the wind-up part-way through. It had
			# been charging since ~611 and would fire around 733.
			_player().global_position = Vector2(100, 140)
		665:
			_player().global_position = Vector2(272, 140)
		735:
			# The moment the interrupted wind-up would have fired.
			_check("warden: leaving the area resets the wind-up, it does not pause (x%.2f)"
				% _player().get("slow_factor"),
				_player().get("slow_factor") == 1.0)
		805:
			# Restarted on re-entry at 665, so it lands around 787.
			_check("warden: the full two seconds lands a half-speed slow (x%.2f, %.1fs)"
				% [_player().get("slow_factor"), _player().get("slow_seconds")],
				_player().get("slow_factor") == 0.5
					and _player().get("slow_seconds") > 3.0)
			_mark = _player().global_position
			_key(KEY_D, true)
		835:
			# The number moving is not the point - the character has to actually
			# walk slower. Half a second of held input, which is ~40 px at the
			# player's 90 and ~21 at half that.
			_key(KEY_D, false)
			var moved: float = _player().global_position.distance_to(_mark)
			_check("warden: the slow is real movement, not just a readout (%.1f px)"
				% moved, moved > 14.0 and moved < 30.0)
			# Out of the way, so it cannot re-slow the player mid-expiry.
			_warden.queue_free()
		1035:
			_check("warden: the slow expires on its own after four seconds (x%.2f)"
				% _player().get("slow_factor"),
				_player().get("slow_factor") == 1.0
					and _player().get("slow_seconds") == 0.0)
			_mark = _player().global_position
			_key(KEY_D, true)
		1065:
			_key(KEY_D, false)
			var freed: float = _player().global_position.distance_to(_mark)
			_check("warden: full speed is back once it expires (%.1f px)"
				% freed, freed > 33.0)
			# Heavy attack: hold to charge, release to unleash on everything
			# around. The guard is placed BEHIND the swing (the player still
			# faces right from the walk, the guard comes from the left), so the
			# press's opening swing misses and the heavy's cost is measured
			# clean. It walks in and parks at 12 px - inside the spin circle.
			_player().global_position = Vector2(272, 140)
			var guard_scene := load("res://game/enemies/regular/regular.tscn") as PackedScene
			_enemy = guard_scene.instantiate()
			_level().get_node("Props").add_child(_enemy)
			_enemy.global_position = Vector2(250, 140)
			_key(KEY_SPACE, true)
		1134:
			# The press's swing is long over and the button is still down: the
			# player is in the charge stance, rooted.
			_check("heavy: holding past the swing enters the charge (got %s)"
				% _sprite().animation,
				String(_sprite().animation).begins_with("charge"))
			_check("heavy: the swing missed the guard behind the blade (%s)"
				% str(_enemy.get("health")), _enemy.get("health") == 24)
			# A warden joins the blast zone, placed late enough that its own
			# 2s wind-up is nowhere near the 75% commit point when the heavy
			# lands - so the hit staggers it and no slow muddies the checks. It
			# is the ledger's witness: at 36 health it SURVIVES the heavy, so a
			# wildfire double-hit would show up where a dead guard hides it.
			var ws := load("res://game/enemies/warden/warden.tscn") as PackedScene
			_warden = ws.instantiate()
			_level().get_node("Props").add_child(_warden)
			_warden.global_position = Vector2(272, 158)
		1154:
			# ~70 frames of charge - past CHARGE_SECONDS. Release unleashes.
			_key(KEY_SPACE, false)
		1179:
			_check("heavy: the spin erupts into the wildfire (got %s)"
				% _sprite().animation,
				String(_sprite().animation).begins_with("wildfire"))
			# HEAVY_POWER is exactly a guard's health, and that equality IS the
			# design: an AoE that does not kill the basic enemy thins no crowd.
			_check("heavy: one-shots a guard (%s)"
				% ("<freed>" if not is_instance_valid(_enemy)
					else str(_enemy.get("health"))),
				not is_instance_valid(_enemy))
		1219:
			_check("heavy: costs HEAVY_POWER once across spin and fire (%s of 36)"
				% (str(_warden.get("health")) if is_instance_valid(_warden) else "<freed>"),
				is_instance_valid(_warden) and _warden.get("health") == 12)
			if is_instance_valid(_warden):
				_warden.queue_free()
			# Last: a warden's charge is interruptible too, now that it runs the
			# base's cycle rather than a clock of its own. Clear the guard out
			# first so nothing else is landing hits.
			if is_instance_valid(_enemy):
				_enemy.queue_free()
			_player().global_position = Vector2(272, 140)
			# A tap of D fixes the facing, so the swing below reaches a warden
			# placed to the right rather than wherever the heavy left them aimed.
			_key(KEY_D, true)
		1224:
			_key(KEY_D, false)
			_player().global_position = Vector2(272, 140)
			var w2 := load("res://game/enemies/warden/warden.tscn") as PackedScene
			_warden = w2.instantiate()
			_level().get_node("Props").add_child(_warden)
			# Close enough to hit, which is the point: unlike walking out, this
			# counter costs you standing inside the thing about to slow you.
			_warden.global_position = Vector2(286, 140)
			_health_mark = _warden.get("health")
		1230:
			_key(KEY_SPACE, true)
		1232:
			_key(KEY_SPACE, false)
		1239:
			# A few frames into a 120-frame charge, far inside commit_fraction.
			_check("warden: an early hit staggers the charge too (phase %s, %s of %d)"
				% [_warden.get("phase"), _warden.get("health"), _health_mark],
				_warden.get("phase") == 3
					and int(_warden.get("health")) < _health_mark)
		1354:
			# Uninterrupted it would have landed around 1346; staggered, it is
			# still winding the restarted charge.
			_check("warden: so the slow it was building never lands (x%.2f)"
				% _player().get("slow_factor"),
				_player().get("slow_factor") == 1.0)
			_finish()
