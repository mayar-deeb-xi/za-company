extends "res://tests/helpers.gd"
## The arc - the combo's third hit - and the lightning it throws.
##
## Five guards stand where the preview put them: one in the blade's reach, two
## within a jump of each other beyond it, a fourth within a jump of the third
## (so the cap on jumps is what saves it, not distance), and one out of range
## of everything. All five are ROOTED (speed 0) so the geometry the checks are
## about is the geometry on the strike frame rather than wherever a chase left
## them. Then a full mash - swing, rising slash, arc - and the room is read:
##
## - the guard in reach dies on the third hit and nothing else, which is the
##   breakpoint (5 + 7 + 12 = 24) being real rather than documented;
## - the two the bolt reached took a swing's worth each; the fourth and the far
##   one took nothing, one for the jump cap and one for the range;
## - a bolt was drawn, in the character's own spark colour, through four points
##   (the blade, then three bodies);
## - the chain ENDS on the arc: the press after it is a fresh swing, and a late
##   press in the grace window after a rising slash still reaches the arc;
## - the numbers agree with player.gd's own: one cycle is the heavy, the jump is
##   a swing, and all seven sheets hold the three new rows.
##
## Its own suite because test_combat.gd measures duels and this is about a
## crowd standing still, and because the placement here is the check.

const Roster := preload("res://game/player/characters/roster.gd")

var _guards: Array[Node2D] = []
var _bolt_seen := false
var _bolt_points := 0
var _bolt_colour := ""


func _tick(frame: int) -> void:
	# The bolt lives 0.3 s and frees itself, so it is caught on the wing.
	if not _bolt_seen:
		var bolts := get_nodes_in_group("player_arcs")
		if not bolts.is_empty():
			_bolt_seen = true
			var chains: Array = bolts[0].get("chains")
			_bolt_points = chains[0].size() if not chains.is_empty() else 0
			_bolt_colour = (bolts[0].get("colour") as Color).to_html(false)
	match frame:
		2:
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		17:
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
		32:
			_check("arc: the lobby starts empty (%d)" % get_nodes_in_group("enemies").size(),
				get_nodes_in_group("enemies").is_empty())
			_player().global_position = Vector2(272, 140)
			var gs := load("res://game/enemies/regular/regular.tscn") as PackedScene
			for at in [Vector2(14, 0), Vector2(38, -13), Vector2(42, 11),
					Vector2(60, 30), Vector2(120, 0)]:
				var g := gs.instantiate() as Node2D
				_level().get_node("Props").add_child(g)
				g.global_position = Vector2(272, 140) + at
				g.set("speed", 0.0)
				_guards.append(g)
		40:
			_key(KEY_D, true)
		42:
			_key(KEY_D, false)
		44:
			_player().global_position = Vector2(272, 140)
			_check("arc: the player faces right (%s, left %s)"
				% [_player().get("_facing"), _player().get("_facing_left")],
				int(_player().get("_facing")) == 2 and _player().get("_facing_left") == false)
		50:
			_key(KEY_SPACE, true)
		54:
			_key(KEY_SPACE, false)
		58:
			_key(KEY_SPACE, true)
		62:
			_key(KEY_SPACE, false)
			_check("arc: the second press buffers the rising slash (%s)"
				% _player().get("_buffered"), _player().get("_buffered") == "attack2")
		74:
			_check("arc: the rising slash is playing (%s)" % _player().get("_attack"),
				_player().get("_attack") == "attack2")
			_key(KEY_SPACE, true)
		78:
			_key(KEY_SPACE, false)
			_check("arc: the third press buffers the arc (%s)"
				% _player().get("_buffered"), _player().get("_buffered") == "attack3")
		92:
			_check("arc: the arc is playing (%s)" % _player().get("_attack"),
				_player().get("_attack") == "attack3")
			_check("arc: and the sprite is on its own row (%s)"
				% _sprite().animation, _sprite().animation == "attack3_side")
		110:
			var hp := ""
			for g in _guards:
				hp += (str(g.get("health")) if is_instance_valid(g) else "dead") + " "
			_check("arc: the guard in reach dies to one cycle, 5 + 7 + 12 (%s)" % hp,
				not is_instance_valid(_guards[0]))
			_check("arc: the bolt jumps to the nearest body for a swing's worth (%s)" % hp,
				is_instance_valid(_guards[1]) and _guards[1].get("health") == 19)
			_check("arc: and once more from there (%s)" % hp,
				is_instance_valid(_guards[2]) and _guards[2].get("health") == 19)
			_check("arc: two jumps and no third - the body in range of the last is spared (%s)" % hp,
				is_instance_valid(_guards[3]) and _guards[3].get("health") == 24)
			_check("arc: a body out of range of everything is untouched (%s)" % hp,
				is_instance_valid(_guards[4]) and _guards[4].get("health") == 24)
			_check("arc: a bolt was drawn", _bolt_seen)
			_check("arc: through the blade and three bodies (%d points)" % _bolt_points,
				_bolt_points == 4)
			var spark: String = Roster.spark_hex(Roster.find("reem")["recipe"])
			_check("arc: in the character's own spark colour (%s vs %s)" % [_bolt_colour, spark],
				_bolt_colour == spark)
			_check("arc: the bolt has cleared the room", get_nodes_in_group("player_arcs").is_empty())
			_check("arc: the chain ended - no grace after the arc (%s, %.2f)"
				% [_player().get("_attack"), _player().get("_combo_grace")],
				_player().get("_attack") == "" and float(_player().get("_combo_grace")) == 0.0)
			_key(KEY_SPACE, true)
		112:
			_check("arc: so the press after it is a fresh swing (%s)" % _player().get("_attack"),
				_player().get("_attack") == "attack")
		114:
			_key(KEY_SPACE, false)
		# The swing started at 110 ends around 127; a press inside the 0.2 s
		# grace window chains WITHOUT a buffer - the late-press path.
		130:
			_check("arc: the swing is over and the window is open (%s, %.2f)"
				% [_player().get("_attack"), _player().get("_combo_grace")],
				_player().get("_attack") == "" and float(_player().get("_combo_grace")) > 0.0)
			_key(KEY_SPACE, true)
		132:
			_check("arc: a late press chains the rising slash (%s)" % _player().get("_attack"),
				_player().get("_attack") == "attack2")
		134:
			_key(KEY_SPACE, false)
		# The rising slash started at 130 ends around 147.
		150:
			_check("arc: over, window open again (%s, %.2f)"
				% [_player().get("_attack"), _player().get("_combo_grace")],
				_player().get("_attack") == "" and float(_player().get("_combo_grace")) > 0.0)
			_key(KEY_SPACE, true)
		152:
			_check("arc: a late press after the rising slash reaches the arc (%s)"
				% _player().get("_attack"), _player().get("_attack") == "attack3")
		154:
			_key(KEY_SPACE, false)
		175:
			_numbers()
			_sheets()
			_finish()


## The arithmetic the whole design rests on, off player.gd's own constants.
func _numbers() -> void:
	var c: Dictionary = _player().get_script().get_script_constant_map()
	var cycle: int = c["ATTACK_POWER"] + c["THRUST_POWER"] + c["ARC_POWER"]
	_check("arc: one cycle is exactly the heavy (%d vs %d)" % [cycle, c["HEAVY_POWER"]],
		cycle == c["HEAVY_POWER"])
	_check("arc: and exactly a guard (%d)" % cycle, cycle == 24)
	_check("arc: the jump is a swing's worth (%d vs %d)"
		% [c["ARC_JUMP_POWER"], c["ATTACK_POWER"]], c["ARC_JUMP_POWER"] == c["ATTACK_POWER"])
	_check("arc: two jumps, forty pixels (%d, %.0f)" % [c["ARC_JUMPS"], c["ARC_JUMP_RANGE"]],
		c["ARC_JUMPS"] == 2 and c["ARC_JUMP_RANGE"] == 40.0)
	var chain: Dictionary = c["LIGHT_NEXT"]
	_check("arc: the chain is swing, rising slash, arc, swing (%s)" % str(chain),
		chain["attack"] == "attack2" and chain["attack2"] == "attack3"
			and chain["attack3"] == "attack")


## Every character's frames carry the three new rows, and the sheet they were
## cut from is tall enough to hold them.
func _sheets() -> void:
	var img := Image.load_from_file(
		ProjectSettings.globalize_path("res://game/player/src/character_cc0.png"))
	_check("arc: the cast sheet has 24 rows (%d px)" % img.get_height(),
		img != null and img.get_height() == 24 * 32)
	var missing: Array[String] = []
	for entry in Roster.CHARACTERS:
		var frames := load(entry["frames"]) as SpriteFrames
		for facing in ["down", "up", "side"]:
			var anim := "attack3_%s" % facing
			if not frames.has_animation(anim) or frames.get_frame_count(anim) != 4:
				missing.append("%s/%s" % [entry["id"], anim])
	_check("arc: all seven characters have attack3 in three facings, four frames (%s)"
		% ("all" if missing.is_empty() else str(missing)), missing.is_empty())
