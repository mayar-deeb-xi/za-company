extends "res://tests/helpers.gd"
## Rage test: Mostafa going up at 72 HP, and staying up.
##
## Its own suite rather than another section of test_bosses.gd, for the reason
## the root CLAUDE.md gives: the rage needs a world where he is FIGHTING and
## then gets taken across half health on a frame of this test's choosing, and
## threading that through a file that already fights three bosses in sequence
## made one boss's timing decide another's. One suite, one clean world.
##
## What is under test is the FLIP, not the fire: that it happens at 72 and not
## before, that it happens once, that he is rooted and silent and cannot be
## staggered while it runs, and that it never comes back down. The picture is
## in the artifact; the pixels are not something a check can hold.

const Poses := preload("res://game/bosses/mostafa/poses.gd")

var _m: Node2D
var _seq: Array[String] = []
var _prev := ""
var _seq_at_rage := 0
var _throw_last := 0.0
var _conceded := false


func _tick(frame: int) -> void:
	if _m != null and is_instance_valid(_m):
		var now: String = _m.get("attack")
		if now != "" and _prev == "":
			_seq.append(now)
		_prev = now

	match frame:
		2:
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		17:
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
		32:
			_m = (load("res://game/bosses/mostafa/mostafa.tscn") as PackedScene)\
				.instantiate() as Node2D
			_level().get_node("Props").add_child(_m)
			_m.connect("shook", _on_shook)
			_m.connect("conceded", func() -> void: _conceded = true)
			# In reach, so the rage has a swing to interrupt when it comes.
			_player().global_position = Vector2(272, 140)
			_m.global_position = Vector2(272, 200)

			_check("rage: he opens at 144, so half of him is 72 (%s)" % _m.get("health"),
				_m.get("health") == 144)
			_check("rage: and opens it cold (%s)" % _m.get("is_raging"),
				_m.get("is_raging") == false)
			# The sheet grew a row for this. Six frames, played once.
			var sheet := _sprite_of(_m).sprite_frames
			_check("rage: the sheet carries the eruption (%d frames)"
				% sheet.get_frame_count("rage_side"),
				sheet.get_frame_count("rage_side")
					== (Poses.ANIMS["rage"] as Array).size())
			_check("rage: and it plays once, never loops",
				not sheet.get_animation_loop("rage_side"))
			_check("rage: it is drawn on all three surfaces (%s)" % str(_parts()),
				_parts() == ["ground", "burst", "screen"])
			# THE ONE THAT MATTERS TO THE ART. rage.gd fires its pulses and its
			# blast at fixed seconds; poses.gd decides when frames change. They
			# agree only because each beat is a frame boundary - retime a `dur`
			# and the fire comes off the picture with nothing to warn you.
			_check("rage: every beat of the fire lands on a frame boundary (%s)"
				% str(_boundaries()), _beats_on_frames())
		110:
			_check("rage: he is mid-combination before anything happens (%s)"
				% str(_seq), not _seq.is_empty())
			_m.call("take_damage", 60)
		116:
			_check("rage: at 84 he is still just a boxer (%s hp, raging %s)"
				% [_m.get("health"), _m.get("is_raging")],
				_m.get("health") == 84 and _m.get("is_raging") == false)
			_seq_at_rage = _seq.size()
			_m.call("take_damage", 20)
		119:
			_check("rage: crossing 72 sets him alight (%s hp, raging %s)"
				% [_m.get("health"), _m.get("is_raging")],
				_m.get("health") == 64 and _m.get("is_raging") == true)
			_check("rage: the eruption takes the sprite (%s)"
				% _sprite_of(_m).animation, _sprite_of(_m).animation == &"rage_side")
			_check("rage: and it drops whatever he was swinging (%s)"
				% ("nothing" if str(_m.get("attack")) == "" else str(_m.get("attack"))),
				str(_m.get("attack")) == "")
		150:
			# 34 frames in: past the blast at 0.51 s, well inside the 0.95 s.
			_check("rage: the blast throws the room harder than any punch (%.2f px)"
				% _throw_last, is_equal_approx(_throw_last, 6.0))
			_check("rage: he throws nothing while he burns (%d attacks)"
				% (_seq.size() - _seq_at_rage), _seq.size() == _seq_at_rage)
			_m.call("take_damage", 1)
		153:
			_check("rage: and cannot be staggered out of it (%s)"
				% _sprite_of(_m).animation, _sprite_of(_m).animation == &"rage_side")
			_check("rage: though the hits still land - it is a free window (%s hp)"
				% _m.get("health"), _m.get("health") == 63)
		200:
			_check("rage: the eruption ends and he fights again (%s)"
				% _sprite_of(_m).animation, _sprite_of(_m).animation != &"rage_side")
			_check("rage: but the fire stays lit - it never comes back down",
				_m.get("is_raging") == true)
			_m.call("take_damage", 39)
		206:
			_check("rage: crossing the line again does not re-light him (%s hp)"
				% _m.get("health"),
				_m.get("health") == 24 and _m.get("is_raging") == true)
			_m.call("take_damage", 500)
		212:
			_check("rage: at zero he still concedes, fire and all (%s)"
				% _m.get("has_conceded"), _m.get("has_conceded") == true and _conceded)
			_check("rage: and the concede is what gets the last word (%s)"
				% _sprite_of(_m).animation, _sprite_of(_m).animation == &"concede_side")
			_check("rage: the hold on his sprite always lets go (speed %.1f)"
				% _sprite_of(_m).speed_scale,
				is_equal_approx(_sprite_of(_m).speed_scale, 1.0))
			_finish()


func _on_shook(strength: float, _seconds: float) -> void:
	_throw_last = strength


func _sprite_of(boss: Node2D) -> AnimatedSprite2D:
	return boss.get_node("AnimatedSprite2D") as AnimatedSprite2D


func _parts() -> Array:
	var parts := []
	for path in ["RageGround", "RageBurst", "Bell/RageScreen"]:
		var node := _m.get_node_or_null(path)
		if node != null:
			parts.append(str(node.get("part")))
	return parts


## Seconds at which a frame of `rage` starts.
func _boundaries() -> Array:
	var out := [0.0]
	var t := 0.0
	for f in Poses.ANIMS["rage"]:
		t += float(f["dur"])
		out.append(snappedf(t, 0.001))
	return out


func _beats_on_frames() -> bool:
	var Rage := load("res://game/bosses/mostafa/rage.gd") as GDScript
	var bounds := _boundaries()
	var beats: Array = (Rage.get_script_constant_map()["PULSES"] as Array).duplicate()
	beats.append(Rage.get_script_constant_map()["BLAST"])
	for beat in beats:
		var hit := false
		for edge in bounds:
			if is_equal_approx(float(edge), float(beat)):
				hit = true
				break
		if not hit:
			return false
	return true
