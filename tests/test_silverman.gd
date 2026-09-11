extends "res://tests/helpers.gd"
## SILVERMAN's fight: the glare both ways, the crossing that passes through
## you, the split, the cold room, and the ladder all three hang off.
##
## His own suite rather than a fourth section of test_bosses.gd, for the reason
## the ladder exists: every check after the first depends on how much health he
## has left, and a file that walks a boss down through three phases cannot also
## hand the room to a next section unchanged. test_bosses.gd keeps his ART
## invariants - one picture per crossing, the ghost row, 1x, the concede -
## which are true of him at any health.
##
## Boots into the empty lobby and places him by hand, like test_combat.gd and
## test_bosses.gd, so his is the only thing in the room.
##
## Three habits worth keeping if you extend this:
##
## - **Geometry does the isolating, not frame numbers.** His band is a 20 px
##   lane and his crossing only travels along x, so a player parked 30 px off
##   his line is untouchable by both while the copy - which homes in two
##   dimensions - still reaches them. That is what lets the split's 12 be
##   asserted as a number rather than as "something happened".
## - **He always closes to `stop_distance`.** Left alone in CHASE he glides to
##   20 px and is then touching, so a check that needs him at range has to
##   fire before he arrives - which is why the ranged glare below is set up
##   73 frames before its cooldown expires and not the frame of it.
## - **His cooldowns are long on purpose** (glare 3.2 s, split 5 s), so the
##   sections are laid out around them. A phase change clears both, which is
##   the other way to get an attack when you want one.
## - **Never set a position while he is crossing.** The dash drives him along a
##   curve off `_dash_from`, so moving him mid-flight fights it and lands him
##   somewhere neither of you chose - which is exactly how the split section
##   first failed: a stray crossing left him 31 px out, inside
##   `split_min_distance`, and he glared instead. Every setup frame below sits
##   in a gap between crossings, and the gaps are what the odd frame numbers
##   are about.

var _sv: Node2D
var _conceded := false
var _shakes := 0

# The crossing.
var _was_dashing := false
var _dash_started := -1
var _dash_ended := -1
var _dash_from := Vector2.ZERO
var _dash_travel := 0.0
var _moving_frames := 0
var _dash_anims := {}

# The ladder: every attack he opens, and the phase he was in when he did.
var _opened: Array[String] = []
var _prev_attack := ""
var _tiers_seen := {}

# The hug: how far off his line the player was standing when the glare landed
# on them anyway.
var _hug_offset := 0.0

# The interrupt attempt in his third phase.
var _tried_interrupt := -1
var _phase_after_interrupt := -1
var _commit_at_interrupt := -1.0

# The copy's blow, measured as a DELTA rather than against an absolute. He
# crosses the room on his own schedule between the setup frames, and a
# pass-through is 18 - so an absolute health here is really an assertion about
# every blow that came before it, which is how this check first failed.
var _before_copy := -1

# The cold room: a drain is a RATE, so what is counted is the number of
# separate frames health went down on. One blow cannot make five of those.
var _watch_drops := false
var _last_health := 0
var _drops := 0
var _health_at_edge := -1


func _tick(frame: int) -> void:
	if _sv != null and is_instance_valid(_sv):
		var now: String = _sv.get("attack")
		if now != "" and _prev_attack == "":
			_opened.append(now)
			_tiers_seen[now] = int(_sv.call("tier"))
		_prev_attack = now

		var crossing: bool = _sv.get("dashing")
		if crossing and not _was_dashing:
			_dash_from = _sv.global_position
			_dash_started = frame
		elif _was_dashing and not crossing:
			_dash_travel = _dash_from.distance_to(_sv.global_position)
			_dash_ended = frame
		if crossing:
			_dash_anims[_sprite_of(_sv).animation] = true
		if _sv.get("dash_moving"):
			_moving_frames += 1
		_was_dashing = crossing

		# Third phase: hit him at the very start of a wind-up, where phase one
		# would have staggered him. Once, and the next frame's phase is the
		# answer.
		if frame > 601 and frame < 690 and _tried_interrupt < 0 \
				and now != "" and _sv.get("phase") == 1:
			_commit_at_interrupt = _sv.get("commit_fraction")
			_sv.call("take_damage", 1)
			_tried_interrupt = frame
		elif _tried_interrupt > 0 and frame == _tried_interrupt + 1:
			_phase_after_interrupt = _sv.get("phase")

	if _watch_drops:
		var health: int = _player().get("health")
		if health < _last_health:
			_drops += 1
		_last_health = health

	match frame:
		2:
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		17:
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
		32:
			_check("silverman: the lobby starts empty, so the fight is placed (%d)"
				% get_nodes_in_group("enemies").size(),
				get_nodes_in_group("enemies").is_empty())
			_sv = (load("res://game/bosses/silverman/silverman.tscn") as PackedScene).instantiate() as Node2D
			_level().get_node("Props").add_child(_sv)
			_sv.connect("conceded", func() -> void: _conceded = true)
			_sv.connect("shook", func(_s: float, _t: float) -> void: _shakes += 1)
			_check("silverman: he opens at 192 - eight heavies (%s)" % _sv.get("health"),
				_sv.get("health") == 192)
			_check("silverman: and opens in his first phase (%s)" % _sv.call("tier"),
				int(_sv.call("tier")) == 1)
			# His screen layer must sit UNDER the HUD: a room going white that
			# takes his own health bar with it hides the one number the player
			# is reading while it lands.
			_check("silverman: the glare draws below the HUD (%d < %d)"
				% [_glare_layer(), _hud_layer()], _glare_layer() < _hud_layer())
			_check("silverman: the band draws in the room and the wash on the frame (%s)"
				% str(_glare_parts()), _glare_parts() == ["band", "screen"])
			# ---- THE HUG. Standing on him, due south, which is the one place
			# every reach he owns used to miss: the band is a 20 px lane through
			# his chest (so it misses on BOTH axes from here), the crossing only
			# travels along x, and the split will not fire closer than 34. He
			# has to have an answer or the last fight in the game is free.
			_sv.global_position = Vector2(382, 140)
			_player().global_position = Vector2(382, 160)
		48:
			_check("silverman: hugged, he winds up on contact (phase %s, '%s')"
				% [_sv.get("phase"), _sv.get("attack")],
				_sv.get("phase") == 1 and _sv.get("attack") == "glare")
			# The telegraph is the DULL steps on the sheet, not a tint. The base
			# fades a winding enemy towards amber, which on a body of six exact
			# greyscale values is a multiply landing between two rungs.
			_check("silverman: he is never tinted while he loads (%s)"
				% _sprite_of(_sv).modulate, _sprite_of(_sv).modulate == Color.WHITE)
			_check("silverman: nothing has landed yet (%s)" % _player().get("health"),
				_player().get("health") == 100)
			_hug_offset = absf(_player().global_position.y - _sv.global_position.y)
		95:
			# The band cannot have done this: at 20 px due south the player is
			# outside its lane in y AND beside it in x. The glare bursting off
			# HIM is what lands, which is the whole point of the fix.
			_check("silverman: hugging him is off the band's line (%.0f px of 20)"
				% _hug_offset, _hug_offset >= 20.0)
			_check("silverman: and the glare still bursts off him for 16 (%s)"
				% _player().get("health"), _player().get("health") == 84)
		130:
			# ---- THE CROSSING. 60 px is inside its own 72, which is the whole
			# of the pass-through: he goes THROUGH rather than stopping short.
			_player().global_position = Vector2(322, 140)
		175:
			_check("silverman: out of reach, he crosses (started %d)"
				% _dash_started, _dash_started > 0)
			_check("silverman: the crossing covers its 72 px (%.1f)" % _dash_travel,
				absf(_dash_travel - 72.0) < 8.0)
			_check("silverman: and takes its half second (%d frames)"
				% (_dash_ended - _dash_started),
				_dash_ended - _dash_started >= 26 and _dash_ended - _dash_started <= 36)
			_check("silverman: one picture for the whole crossing (%s)"
				% str(_dash_anims.keys()), _dash_anims.keys() == [&"dash_side"])
			_check("silverman: the smear draws on the travel beats only (%d frames)"
				% _moving_frames, _moving_frames >= 7 and _moving_frames <= 15)
			# ONE blow, not three: all three travel beats can hit and a flag
			# keeps the crossing to a single pass-through.
			_check("silverman: he passes THROUGH you for 18, once (%s)"
				% _player().get("health"), _player().get("health") == 66)
			_check("silverman: and comes out the other side of you (%.0f)"
				% _sv.global_position.x, _sv.global_position.x < 322.0)
		200:
			# ---- THE BAND. Set up well before the glare's 3.2 s is up, because
			# he closes to stop_distance while he waits: 110 px now is ~64 px by
			# the time it fires, which is still outside the burst's own reach so
			# what lands here can only be the sweep.
			_sv.global_position = Vector2(382, 140)
			_player().global_position = Vector2(272, 140)
		350:
			_check("silverman: at range he glares with no contact needed (%s)"
				% str(_opened), _opened.size() >= 2 and _opened[1] == "glare")
			_check("silverman: the band crosses the room and lands its 16 (%s)"
				% _player().get("health"), _player().get("health") == 50)
			_check("silverman: from outside the burst, so that was the sweep (%.0f px)"
				% _sv.global_position.distance_to(_player().global_position),
				_sv.global_position.distance_to(_player().global_position) > 27.0)
			_check("silverman: a blow that big shakes the room (%d)" % _shakes,
				_shakes >= 1)
		400:
			# ---- THE MEETING. 128, and the split arrives -------------------
			_sv.call("take_damage", 72)
			_check("silverman: at two thirds he is in his second phase (%s at %s HP)"
				% [_sv.call("tier"), _sv.get("health")],
				int(_sv.call("tier")) == 2 and _sv.get("health") == 120)
			_check("silverman: a phase announces itself (%.1f s)" % _sv.get("herald"),
				float(_sv.get("herald")) > 0.0)
			# 30 px off his line: the band is a 20 px lane and the crossing only
			# moves along x, so neither reaches here - but the copy homes in two
			# dimensions and will.
			_sv.global_position = Vector2(332, 140)
			_player().global_position = Vector2(272, 110)
		460:
			_check("silverman: in his second phase he divides (%s)" % str(_opened),
				_opened.has("split"))
			_check("silverman: and the split is a second-phase thing only (%s)"
				% str(_tiers_seen), _tiers_seen.get("split", 0) >= 2)
			_check("silverman: the copy is in the room (%d)" % _copies().size(),
				_copies().size() == 1)
			var copies := _copies()
			_check("silverman: it is not a body - no groups, nothing to fight (%s)"
				% (str(copies[0].get_groups()) if not copies.is_empty() else "no copy"),
				not copies.is_empty() and copies[0].get_groups().is_empty())
			_check("silverman: and he stands still while it goes (%s)"
				% _sv.global_position,
				_sv.global_position.distance_to(Vector2(332, 140)) < 6.0)
			# Before it arrives: the copy emerges for 0.30 s and then walks, so
			# it is still on its way over here.
			_before_copy = _player().get("health")
		520:
			_check("silverman: the copy walks you down for 12 (%s -> %s)"
				% [_before_copy, _player().get("health")],
				_before_copy - int(_player().get("health")) == 12)
		560:
			_check("silverman: the copy is gone a second and a half later (%d)"
				% _copies().size(), _copies().is_empty())
		600:
			# ---- THE PERFORMANCE REVIEW. 64, and the room goes cold --------
			_sv.call("take_damage", 60)
			_check("silverman: at a third he is in his last phase (%s at %s HP)"
				% [_sv.call("tier"), _sv.get("health")],
				int(_sv.call("tier")) == 3 and _sv.get("health") == 60)
		700:
			_check("silverman: his last phase is uninterruptible (commit %.2f)"
				% _commit_at_interrupt, is_equal_approx(_commit_at_interrupt, 0.0))
			_check("silverman: so a hit at the start of a wind-up does not stagger him (phase %s)"
				% _phase_after_interrupt, _phase_after_interrupt == 1)
		760:
			# THE COLD ROOM, isolated the honest way: his sight goes to zero, so
			# he cannot glare, cannot cross and cannot even turn - and the aura
			# bites anyway, which is the design. It is not on the cycle.
			_sv.set("sight_radius", 0.0)
			_sv.global_position = Vector2(332, 140)
			# 30 px: outside Touch (22 + the player's 5), inside the aura (34).
			_player().global_position = Vector2(362, 140)
			_player().call("heal", 100)
			_last_health = _player().get("health")
			_watch_drops = true
		880:
			_check("silverman: standing near him costs health with no telegraph (%s)"
				% _player().get("health"), _player().get("health") < 100)
			# A rate, not a blow. Three points a second cannot arrive on one frame.
			_check("silverman: and it is a DRAIN - it ticks (%d separate frames)"
				% _drops, _drops >= 5)
			_check("silverman: he never wound up for any of it (phase %s, '%s')"
				% [_sv.get("phase"), _sv.get("attack")],
				_sv.get("phase") == 0 and _sv.get("attack") == "")
		890:
			# Out of the aura, still well inside where it was biting.
			_player().global_position = Vector2(382, 140)
			_health_at_edge = _player().get("health")
		960:
			_check("silverman: step out of the radius and it stops (%s -> %s)"
				% [_health_at_edge, _player().get("health")],
				_player().get("health") == _health_at_edge)
		970:
			_sv.call("take_damage", 500)
			_check("silverman: at zero he concedes (%s)" % _sv.get("has_conceded"),
				_sv.get("has_conceded") == true)
			_check("silverman: conceding is a signal the door can hear", _conceded)
			_check("silverman: out of the fight, still in the room",
				not _sv.is_in_group("enemies") and _sv.is_inside_tree()
				and _sv.is_in_group("bosses"))
			_check("silverman: losing flight is the defeat (%s)"
				% _sprite_of(_sv).animation, _sprite_of(_sv).animation == &"concede_side")
		990:
			_check("silverman: a conceded boss draws no aura", _drawn_nothing())
			_check("silverman: and casts no more copies (%d)" % _copies().size(),
				_copies().is_empty())
		1060:
			_check("silverman: he settles, then keeps cooling (%s)"
				% _sprite_of(_sv).animation, _sprite_of(_sv).animation == &"beaten_side")
			_check("silverman: and stops crossing the room",
				_sv.get("dashing") == false and _sv.get("dash_moving") == false)
			_check("silverman: the ladder was climbed in order (%s)" % str(_opened),
				_opened[0] == "glare" and _opened.has("split"))
			_finish()


func _sprite_of(enemy: Node2D) -> AnimatedSprite2D:
	return enemy.get_node("AnimatedSprite2D") as AnimatedSprite2D


## Everything in the room wearing copy.gd. Found by script rather than by group
## precisely because a copy is in no group - see copy.gd's header.
func _copies() -> Array[Node]:
	var found: Array[Node] = []
	var script := load("res://game/bosses/silverman/copy.gd")
	for child in _level().get_node("Props").get_children():
		if child.get_script() == script:
			found.append(child)
	return found


## The glare's two parts, in the order they draw: under the body, then the
## frame itself.
func _glare_parts() -> Array:
	var parts := []
	for path in ["GlareBand", "Glare/GlareScreen"]:
		var node := _sv.get_node_or_null(path)
		if node != null:
			parts.append(str(node.get("part")))
	return parts


func _glare_layer() -> int:
	var layer := _sv.get_node_or_null("Glare") as CanvasLayer
	return layer.layer if layer != null else -999


func _hud_layer() -> int:
	return (current_scene.get_node("HUD") as CanvasLayer).layer


## A conceded boss is harmless, and the aura is the one thing on him that does
## not run off the attack cycle - so it is the one that has to be checked.
func _drawn_nothing() -> bool:
	return _player().get("health") == _health_at_edge
