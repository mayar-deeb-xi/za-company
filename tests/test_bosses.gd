extends "res://tests/helpers.gd"
## Boss test: Ahmed's four attacks, the order he picks them in, the slam
## landing on his own adds, the wave at range, the interrupt, and the concede.
## Boots into the empty lobby like test_combat.gd and places him by hand, so
## his is the only fight in the room and the frame numbers below hold.
##
## Sequence rather than stopwatch: `_tick` samples his `attack` every frame and
## records each new one, so the checks read the order he fought in rather than
## betting on the exact frame a swing began.

const _MPoses := preload("res://game/bosses/mostafa/poses.gd")

var _boss: Node2D
var _boy: Node2D
var _seq: Array[String] = []
var _conceded_heard := false
var _interrupted_at := -1
var _phase_after_interrupt := -1
var _health_at_concede := -1

# Mostafa, fought second in the same cleared room.
var _m: Node2D
var _mseq: Array[String] = []
var _m_conceded := false
var _m_prev := ""
var _m_anim_mismatch := ""
var _m_gap_before := 0.0
var _m_health_at_concede := -1
var _m_shakes := 0
var _m_throw_max := 0.0

# Silverman, third. His FIGHT is tests/test_silverman.gd's: it walks him down
# a three-phase ladder, and a file that does that cannot also hand the room to
# a next section unchanged. What is under test HERE is the art that is true of
# him at any health - 1x, the feet on the origin, one picture per crossing, the
# dulled row the smear stamps, and the concede - so he is placed out of his own
# sight and never throws anything.
var _sv: Node2D
var _sv_conceded := false


func _tick(frame: int) -> void:
	if _m != null and is_instance_valid(_m):
		var mnow: String = _m.get("attack")
		# Record every attack that STARTS, not every change: his combination
		# throws two jabs in a row, and "different from the last one" would
		# collapse them into one. `attack` is "" between attacks, so a
		# transition out of "" is one swing.
		if mnow != "" and _m_prev == "":
			_mseq.append(mnow)
		# The animation IS the telegraph - hold that every frame he is swinging
		# rather than betting on catching one attack at one frame number.
		if mnow != "" and _sprite_of(_m).animation != StringName(mnow + "_side"):
			_m_anim_mismatch = "%s playing %s" % [mnow, _sprite_of(_m).animation]
		_m_prev = mnow
	if _boss != null and is_instance_valid(_boss):
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
			# His two sounds, mid-fight. The axe burns for as long as he holds
			# it, so its loop is running from his first frame; the breath he
			# is left with has not been asked for. Checked the other way round
			# at 568, which is the pair that makes either one mean anything.
			var snd: Node = _boss.get_node_or_null("Audio")
			_check("bosses: the axe is alight from his first frame (%s)"
				% _loop_mode_of(snd, "axe"),
				_loop_mode_of(snd, "axe") == AudioStreamWAV.LOOP_FORWARD)
			_check("bosses: the breath he ends on has not started (%s)"
				% _loop_mode_of(snd, "breath"),
				_loop_mode_of(snd, "breath") == AudioStreamWAV.LOOP_DISABLED)
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
			# The concede runs 1.07 s and he is freed at 570, so it is wound on
			# rather than waited out - what is under test is the hand-off, not
			# how long the kneel takes.
			_sprite_of(_boss).speed_scale = 100.0
		568:
			_check("bosses: the concede hands off to the breath (%s)"
				% _sprite_of(_boss).animation, _sprite_of(_boss).animation == &"beaten_side")
			_check("bosses: and the breath loops, so he never freezes",
				_sprite_of(_boss).sprite_frames.get_animation_loop(&"beaten_side")
				and _sprite_of(_boss).is_playing())
			# The noise. Ahmed is the boss who has sounds, so his are what
			# hold the contract in boss_audio.gd: the base's three ids plus
			# the two that are his. A boss without an Audio child is legal
			# and silent, which is why this asks HIM and not the base.
			var audio: Node = _boss.get_node_or_null("Audio")
			_check("bosses: he carries his own sounds (%s)" % audio, audio != null)
			var sounds: Dictionary = audio.get("sounds") if audio != null else {}
			_check("bosses: the base's three ids and his own two (%s)"
				% str(sounds.keys()),
				sounds.has("hurt") and sounds.has("stagger")
				and sounds.has("concede") and sounds.has("axe")
				and sounds.has("breath"))
			# Null here is the un-imported checkout the header warns about -
			# the fight above all passed either way, which is the point, but
			# a developer who HAS imported should be told if one went missing.
			var missing: Array = []
			for id in sounds:
				if sounds[id] == null:
					missing.append(id)
			_check("bosses: every declared sound resolves (missing %s)" % str(missing),
				missing.is_empty())
			_check("bosses: one player built per sound (%d of %d)"
				% [audio.get_child_count(), sounds.size()],
				audio.get_child_count() == sounds.size())
			# The functional half, and it cannot be `playing`: headless runs
			# the Dummy audio driver, under which even a plain
			# AudioStreamPlayer with a good stream reports playing == false
			# forever. What IS observable is the loop flag, and it happens to
			# be the better check anyway - the importer writes
			# `edit/loop_mode=0` on every WAV it has not been told otherwise
			# about, so a loop only ever loops because `boss_audio.loop()`
			# set the flag, and seeing it set is seeing that call happen.
			# Paired with the frame-110 check above: the axe burns from his
			# first frame, the breath waits for his last.
			_check("bosses: the concede hands the breath its loop (%s)"
				% _loop_mode_of(audio, "breath"),
				_loop_mode_of(audio, "breath") == AudioStreamWAV.LOOP_FORWARD)

		# ---- Mostafa. Same room, cleared: his fight is a RHYTHM, so what is
		# checked here is the ORDER he throws in, not the frame each punch
		# lands on. The player is healed first because Ahmed left them at 38
		# and a hook is 18 - a death mid-suite would respawn them elsewhere.
		570:
			# Guarded: the office boy has usually been killed by Ahmed's second
			# slam by now and freed itself, and an unguarded queue_free on it
			# throws - which would abort this whole arm and leave Mostafa
			# uncreated.
			if is_instance_valid(_boss):
				_boss.queue_free()
			if is_instance_valid(_boy):
				_boy.queue_free()
			_boss = null
			_boy = null
			_player().call("heal", 100)
			_m = (load("res://game/bosses/mostafa/mostafa.tscn") as PackedScene).instantiate() as Node2D
			_level().get_node("Props").add_child(_m)
			_m.connect("conceded", func() -> void: _m_conceded = true)
			_check("bosses: Mostafa opens at 144 - six heavies (%s)" % _m.get("health"),
				_m.get("health") == 144)
			_check("bosses: he is a boss and an enemy",
				_m.is_in_group("bosses") and _m.is_in_group("enemies"))
			_check("bosses: he squares up front on, on the side-only rig (%s)"
				% _sprite_of(_m).animation, _sprite_of(_m).animation == &"idle_side")
			# Drawn at 2x density, so his sheet is halved back in the scene -
			# this is what keeps him the same height in the room as Ahmed.
			_check("bosses: 2x density is halved in the scene (scale %s)"
				% _sprite_of(_m).scale, is_equal_approx(_sprite_of(_m).scale.x, 0.5))
			# THE BELL - his punches announced at the scale of the room. Three
			# parts because they draw in three different spaces; see bell.gd.
			_m.connect("shook", _on_shook)
			_check("bosses: the Bell is on him in all three spaces (%s)"
				% str(_bell_parts(_m)),
				_bell_parts(_m) == ["ground", "burst", "screen"])
			# A flash that washed out his own health bar would hide the one
			# number the player is watching while it lands.
			_check("bosses: his screen layer sits under the HUD (%d < %d)"
				% [_bell_layer(_m), _hud_layer()], _bell_layer(_m) < _hud_layer())
			_player().global_position = Vector2(272, 140)
			_m.global_position = Vector2(272, 196)
		700:
			_check("bosses: Mostafa opens the combination with a jab (%s)" % str(_mseq),
				not _mseq.is_empty() and _mseq[0] == "jab")
			_check("bosses: every swing plays its own animation (%s)"
				% ("all matched" if _m_anim_mismatch == "" else _m_anim_mismatch),
				_m_anim_mismatch == "")
		980:
			_check("bosses: he throws jab, jab, hook in that order (%s)" % str(_mseq),
				_mseq.size() >= 3 and _mseq.slice(0, 3) == ["jab", "jab", "hook"])
			_check("bosses: the combination has hurt the player (%s)"
				% _player().get("health"), _player().get("health") < 100)
			_check("bosses: every blow he finishes shakes the room (%d, %d thrown)"
				% [_m_shakes, _mseq.size()], _m_shakes >= 3)
			_check("bosses: and the hook throws the camera hardest (%.2f px)"
				% _m_throw_max, is_equal_approx(_m_throw_max, 4.65))
			_check("bosses: the hook is the long telegraph, the jab the short one "
				+ "(%.2fs vs %.2fs)" % [_MPoses.windup_of("hook"), _MPoses.windup_of("jab")],
				is_equal_approx(_MPoses.windup_of("jab"), 0.25)
				and is_equal_approx(_MPoses.windup_of("hook"), 0.70))
			# Out of reach, straight ahead: the corner rush is for exactly this.
			_m_gap_before = 999.0
			_player().global_position = _m.global_position + Vector2(76, 0)
		1120:
			_check("bosses: kited out of reach, he rushes the gap (%s)" % str(_mseq),
				_mseq.has("rush"))
			_check("bosses: the rush closed the ground (%.0f px)"
				% _m.global_position.distance_to(_player().global_position),
				_m.global_position.distance_to(_player().global_position) < 76.0)
			_m_health_at_concede = _player().get("health")
			_m.call("take_damage", 500)
			_check("bosses: at zero he concedes (%s)" % _m.get("has_conceded"),
				_m.get("has_conceded") == true)
			_check("bosses: conceding is a signal the door can hear", _m_conceded)
			_check("bosses: a conceded boss is out of the fight but still in the room",
				not _m.is_in_group("enemies") and _m.is_inside_tree()
				and _m.is_in_group("bosses"))
		1125:
			_check("bosses: Mostafa has a concede row to hold on (%s)"
				% _sprite_of(_m).animation, _sprite_of(_m).animation == &"concede_side")
			_check("bosses: nothing more lands after he concedes (%s -> %s)"
				% [_m_health_at_concede, _player().get("health")],
				_player().get("health") == _m_health_at_concede)
			# Hit-stop pauses his sprite for 0.08 s on the frame a blow lands.
			# It must always let go: the animation it would otherwise freeze
			# forever is the concede the locked door is waiting to see.
			_check("bosses: hit-stop always lets go of the sprite (speed %.1f)"
				% _sprite_of(_m).speed_scale,
				is_equal_approx(_sprite_of(_m).speed_scale, 1.0))
		1130:
			# ---- SILVERMAN, third, in the same cleared room ----------------
			if is_instance_valid(_m):
				_m.queue_free()
			_m = null
			_player().call("heal", 100)
			_sv = (load("res://game/bosses/silverman/silverman.tscn") as PackedScene).instantiate() as Node2D
			_level().get_node("Props").add_child(_sv)
			_sv.connect("conceded", func() -> void: _sv_conceded = true)
			_check("bosses: Silverman opens at 192 - eight heavies (%s)" % _sv.get("health"),
				_sv.get("health") == 192)
			_check("bosses: he is a boss and an enemy",
				_sv.is_in_group("bosses") and _sv.is_in_group("enemies"))
			# 1x density, unlike Mostafa: he was drawn, shown and picked at 35
			# rows, and the approved picture is the spec. A scale here that is
			# not 1 means someone redrew him at double density.
			_check("bosses: he ships at 1x, unscaled like Ahmed (scale %s)"
				% _sprite_of(_sv).scale, is_equal_approx(_sprite_of(_sv).scale.x, 1.0))
			_check("bosses: his feet sit on the origin (offset %s)"
				% _sprite_of(_sv).offset, _sprite_of(_sv).offset == Vector2(0, -24))
			# THE RULE HIS ART TURNS ON. He never deforms, so the crossing has
			# one picture in it - and the sheet carries a second, dulled copy
			# on a row he never plays, which is what smear.gd stamps.
			var sheet := _sprite_of(_sv).sprite_frames
			_check("bosses: the dash is ONE frame - the body never changes shape (%d)"
				% sheet.get_frame_count("dash_side"),
				sheet.get_frame_count("dash_side") == 1)
			_check("bosses: the sheet carries the dulled copy the smear stamps",
				sheet.has_animation("ghost_side") and sheet.get_frame_count("ghost_side") == 1)
			_check("bosses: the smear is on him, under the body (%s)"
				% str(_sv.get_children().map(func(n: Node) -> String: return n.name)),
				_sv.get_child(0).name == "Smear")
			# Both attack rows are on the sheet, and both are six frames of the
			# same body at a different height - two attacks for two rows of
			# nothing, which is what his one rule buys.
			for row in ["glare_side", "split_side"]:
				_check("bosses: %s is on the sheet, six frames of it (%d)"
					% [row, sheet.get_frame_count(row)],
					sheet.has_animation(row) and sheet.get_frame_count(row) == 6)
			# Out of his own sight (130), so the only thing this section moves
			# is his art. The fight is test_silverman.gd's.
			_player().global_position = Vector2(250, 140)
			_sv.global_position = Vector2(392, 140)
		1200:
			_check("bosses: left alone outside his sight he does nothing (phase %s, '%s')"
				% [_sv.get("phase"), _sv.get("attack")],
				_sv.get("phase") == 0 and _sv.get("attack") == "")
			_check("bosses: and nothing reaches the player (%s)"
				% _player().get("health"), _player().get("health") == 100)
			_sv.call("take_damage", 500)
			_check("bosses: at zero he concedes (%s)" % _sv.get("has_conceded"),
				_sv.get("has_conceded") == true)
			_check("bosses: conceding is a signal the door can hear", _sv_conceded)
			_check("bosses: a conceded boss is out of the fight but still in the room",
				not _sv.is_in_group("enemies") and _sv.is_inside_tree()
				and _sv.is_in_group("bosses"))
			_check("bosses: losing flight is the defeat (%s)" % _sprite_of(_sv).animation,
				_sprite_of(_sv).animation == &"concede_side")
		1300:
			# The concede runs 1.2 s and then hands off, or he is a statue: the
			# row that loops for the rest of the run is `beaten`.
			_check("bosses: he settles, then keeps cooling (%s)"
				% _sprite_of(_sv).animation, _sprite_of(_sv).animation == &"beaten_side")
			_check("bosses: a conceded boss stops crossing the room",
				_sv.get("dashing") == false and _sv.get("dash_moving") == false)
			_finish()


func _sprite_of(enemy: Node2D) -> AnimatedSprite2D:
	return enemy.get_node("AnimatedSprite2D") as AnimatedSprite2D


func _on_shook(strength: float, _seconds: float) -> void:
	_m_shakes += 1
	_m_throw_max = maxf(_m_throw_max, strength)


## The Bell's parts, in the order they draw: under the body, over it, then the
## screen itself.
func _bell_parts(boss: Node2D) -> Array:
	var parts := []
	for path in ["BellGround", "BellBurst", "Bell/BellScreen"]:
		var node := boss.get_node_or_null(path)
		if node != null:
			parts.append(str(node.get("part")))
	return parts


func _bell_layer(boss: Node2D) -> int:
	var layer := boss.get_node_or_null("Bell") as CanvasLayer
	return layer.layer if layer != null else -999


func _hud_layer() -> int:
	return (current_scene.get_node("HUD") as CanvasLayer).layer


## The loop flag on one of a boss's sounds, or -1 where he has no such player.
## It is the only part of playback that survives headless: the Dummy audio
## driver reports `playing` false forever, so a sound is shown to have STARTED
## by the flag `boss_audio.loop()` sets on its way to `play()`.
func _loop_mode_of(audio: Node, id: String) -> int:
	if audio == null:
		return -1
	var player := audio.get_node_or_null("Sfx_%s" % id) as AudioStreamPlayer2D
	if player == null:
		return -1
	var wav := player.stream as AudioStreamWAV
	return wav.loop_mode if wav != null else -1
