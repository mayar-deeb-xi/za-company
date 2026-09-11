extends "res://tests/helpers.gd"
## Dominique test: the FOURTH beat, the one that hands over information instead
## of a heart. That they wait for a fight rather than for a quiet room, that
## they come DOWN the north door while Ivan comes up the south one, that they
## cross to the authored spot, that they can be talked to after arriving late,
## and that nothing is healed by any of it.
##
## Its own suite rather than a section of test_ivan.gd for the reason every
## suite here is its own: that one ends by hurting the player and counting
## hearts on the floor, and this one has to prove no heart is ever thrown. A
## file that does both has to keep the two arrivals out of each other's way
## frame by frame, which is the shape the split exists to avoid.
##
## Boots into the empty lobby and builds the beat by hand, the way test_ivan.gd
## and test_reinforcements.gd do: what is under test is relief.gd's cue driving
## a briefing rather than which three floors got one. The floors are checked off
## disk at the end, in `_baked()`, and the RULE behind those three floors - a
## briefing under every boss and nowhere else - in `_chain()`, which is the one
## check that would notice a fourth boss being added without a warning for it.
##
## Frame budget: they walk at 45 px/s and the run is --fixed-fps 60, so the
## 94 px from the lobby's north door to the spot below is about 125 frames.
## Every wait below is that plus slack.

const RELIEF := preload("res://game/levels/relief.gd")
const SAY := "res://game/npcs/dominique/before_ahmed.gd"
const OFFICE_BOY := "res://game/enemies/office_boy/office_boy.tscn"

## The chain, in order, so `_chain()` can ask what is on the floor ABOVE each
## one. Hard-coded like test_flow.gd's walk for the same reason: a floor
## inserted into the middle of the building is a thing a test should be made to
## notice, not something it should quietly absorb.
const CHAIN := ["lobby", "content_studio", "call_center", "ahmed_office",
	"the_hub", "marble_hall", "innovation_lab", "conflict_resolution",
	"asset_recovery", "hellfire", "executive_floor", "khaled_office"]

## The three floors that carry a briefing, and what each one is for. Read back
## off disk at the end: everything above this builds its own beat, so without
## it all three biome entries could be empty and every check would still pass.
const BRIEFINGS := {
	"call_center": {
		"at": Vector2(340, 144),
		"say": "res://game/npcs/dominique/before_ahmed.gd",
	},
	"innovation_lab": {
		"at": Vector2(232, 120),
		"say": "res://game/npcs/dominique/before_mostafa.gd",
	},
	"executive_floor": {
		"at": Vector2(310, 97),
		"say": "res://game/npcs/dominique/before_silverman.gd",
	},
}

## Where this suite's beat sends them: west of the door line, clear of the
## lobby's reception at (168, 92) and its pillars at x 152 / 232, and nowhere
## near HR at (356, 226).
const STAND := Vector2(200, 140)

## Presses advance this often while the box is up - the same rate test_ivan.gd
## and test_dialogue.gd use. The first press of a line completes its reveal and
## the second advances it, so a line costs two.
const ADVANCE_EVERY := 6

var _beat: Node2D
var _boy: Node2D
var _dom: Node2D
var _door := Vector2.ZERO
## Where they were standing on the first frame they existed. Caught as it
## happens rather than read later: they are walking from the moment they
## arrive, so "came in through the north door" is a question about one frame.
var _entered := Vector2.INF
var _advancing := false
var _talked := false
var _said: Array[String] = []


func _tick(frame: int) -> void:
	if _dom == null:
		_dom = _npc_in_room()
		if _dom != null:
			_entered = _dom.global_position
	if _advancing:
		if frame % ADVANCE_EVERY == 0:
			_key(KEY_E, true)
		elif frame % ADVANCE_EVERY == 3:
			_key(KEY_E, false)
		# The box sets the WHOLE line and reveals it with visible_characters
		# (ui/dialogue/dialogue_box.gd), so the text changes once per beat rather
		# than once per typed character - this collects beats, not frames.
		#
		# Gated on the SPEAKER, which does two jobs: the box ships with
		# design-time placeholders in its scene ("..." over "HR") and is visible
		# with them for the frame before the first `say()` lands, and everything
		# collected here is then known to be hers rather than merely to have
		# been on screen.
		var line := _line().text
		if line != "" and _speaker() == "Dominique" \
				and (_said.is_empty() or _said[-1] != line):
			_said.append(line)

	match frame:
		2:
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		17:
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
		32:
			_check("briefing: the lobby starts empty, so the beat is ours (%d)"
				% get_nodes_in_group("enemies").size(),
				get_nodes_in_group("enemies").is_empty())
			_door = _level().call("spawn_position", &"returned")
			# Out of the doorway and out of a boy's 80 px sight: this suite is
			# about a cue and a conversation, and the fighting is test_combat's.
			_player().global_position = Vector2(272, 120)
			_beat = Node2D.new()
			_beat.name = "Briefing"
			_beat.set_script(RELIEF)
			_beat.set("npc", "dominique")
			_beat.set("from", &"returned")
			_beat.set("at", STAND)
			_beat.set("say", SAY)
			_level().add_child(_beat)
		44:
			# The same first guard Ivan's beat has, and it is the same mistake
			# here for a different reason: a warning delivered to somebody who
			# has not yet had a fight is a warning about a floor they have not
			# reached, and the room is clear on its first frame too.
			_check("briefing: an empty room is not a won one - nobody comes",
				_npc_in_room() == null)
			_boy = (load(OFFICE_BOY) as PackedScene).instantiate() as Node2D
			_level().get_node("Props").add_child(_boy)
			_boy.global_position = Vector2(120, 248)
			_boy.set("sight_radius", 0.0)
		52:
			_check("briefing: and nobody comes while somebody is still standing",
				_npc_in_room() == null)
			_boy.call("take_damage", 999)
		58:
			_check("briefing: the room clears and they walk in", _dom != null)
			if _dom != null:
				# THE ONE THING THIS BEAT DOES THAT RELIEF DOES NOT. Ivan comes
				# up the south door, the way the player did; a briefing comes
				# DOWN the north one, from the floor it is about - which is
				# also what keeps two arrivals on one cue out of one doorway.
				_check("briefing: through the NORTH door, not the player's (%s vs %s)"
					% [_entered, _door], _entered.distance_to(_door) < 1.0)
				_check("briefing: friendly by group, like every other NPC",
					_dom.is_in_group("npcs")
						and not _dom.is_in_group("enemies")
						and not _dom.is_in_group("player"))
				_check("briefing: and they are on their way somewhere",
					bool(_dom.call("walking")))
		200:
			_check("briefing: they cross to the spot the biome chose (%s vs %s)"
				% [_dom.global_position, STAND],
				_dom.global_position.distance_to(STAND) < 6.0)
			_check("briefing: and stop there", not bool(_dom.call("walking")))
			# A guide is not a healer, and the whole of what makes that true is
			# that ivan.gd is not on this scene. Checked as a missing METHOD
			# rather than as a missing heart, because the heart count below
			# would also be zero if the gift were simply broken.
			_check("briefing: they carry no gift - npc_base and nothing else",
				not _dom.has_method("has_given"))
			_player().global_position = Vector2(215, 155)
			# Mashing STOPS at the end of the first run. Standing next to them with
			# the key down otherwise starts the briefing over - which is the right
			# behaviour and the wrong measurement, and is what made four beats read
			# as nine.
			_dialogue().connect("finished", func(_npc) -> void:
				_talked = true
				_advancing = false)
		210:
			_check("briefing: their prompt comes up in range",
				(_dom.get_node("Prompt") as Control).visible)
			# THE WIRING THIS SUITE SHARES WITH test_ivan.gd's, and it is worth
			# having twice: they were added to the room long after game.gd swept
			# it for NPCs, so if the director is only wired at build time the
			# prompt comes up and the key does nothing - silent on three floors.
			_advancing = true
		330:
			_advancing = false
			_key(KEY_E, false)
			_check("briefing: the conversation runs and ends (%d lines)"
				% _said.size(), _talked)
			# Against the file rather than against a number, so a line added to
			# the briefing is carried here instead of failing a count.
			var beats: Array = (load(SAY) as GDScript) \
				.get_script_constant_map().get("BEATS", [])
			var written: Array[String] = []
			for beat in beats:
				written.append(String(beat["text"]))
			_check("briefing: they say every beat in the file, in order (%d of %d: %s)"
				% [_said.size(), written.size(),
					" / ".join(_said.map(func(s: String) -> String:
						return s.substr(0, 10)))],
				_said == written)
			# What they are FOR: the fight upstairs is named. Checked on the
			# text rather than on a beat index so rewording a line cannot
			# quietly turn a briefing into small talk.
			var script := " ".join(_said).to_lower()
			_check("briefing: the fight upstairs is named (%s)"
				% script.substr(0, 28), script.contains("ahmed"))
			_check("briefing: and nothing was healed by any of it (%d hearts)"
				% _hearts_on_floor().size(), _hearts_on_floor().is_empty())
			_clips()
			_baked()
			_chain()
			_finish()


## Every line of all three briefings names a clip, and every clip named is
## really there - the pair of checks test_dialogue.gd holds over HR and
## test_ivan.gd over Ivan. A mistyped path is SILENT at runtime, so nothing but
## a check like this would ever report one.
func _clips() -> void:
	var voiced := 0
	var silent: Array[String] = []
	var missing: Array[String] = []
	var names := {}
	for path in BRIEFINGS.values().map(func(b: Dictionary) -> String: return b["say"]):
		for beat in (load(path) as GDScript).get_script_constant_map().get("BEATS", []):
			var clip := String(beat.get("voice", ""))
			if clip == "":
				silent.append(String(beat.get("text", "")).substr(0, 24))
				continue
			voiced += 1
			names[clip] = names.get(clip, 0) + 1
			if not ResourceLoader.exists(clip):
				missing.append(clip.get_file())
	_check("voice: every line in all three briefings names a clip (%d%s)"
		% [voiced, "" if silent.is_empty() else ", missing " + ", ".join(silent)],
		voiced > 0 and silent.is_empty())
	_check("voice: and every clip is on disk (%s)"
		% ("all there" if missing.is_empty() else ", ".join(missing)),
		missing.is_empty())
	# Three conversations cut into ONE folder, so a name reused across two of
	# them is a floor playing another floor's warning - and cut.py would have
	# cut it once and never said so. See tools/voice/dominique.py.
	var shared := names.keys().filter(func(c: String) -> bool: return names[c] > 1)
	_check("voice: and no two floors share a clip (%s)"
		% ("all distinct" if shared.is_empty() else ", ".join(shared)),
		shared.is_empty())


## The three floors that actually carry the beat, read back off disk.
func _baked() -> void:
	for name in BRIEFINGS:
		var want: Dictionary = BRIEFINGS[name]
		var room := (load("res://game/levels/%s/%s.tscn" % [name, name])
			as PackedScene).instantiate()
		var node := room.get_node_or_null("Briefing")
		_check("briefing: %s carries the beat its biome asked for" % name,
			node != null)
		if node != null:
			_check("briefing: %s sends Dominique, not somebody else (%s)"
				% [name, node.get("npc")], String(node.get("npc")) == "dominique")
			_check("briefing: %s brings them down the north door (%s)"
				% [name, node.get("from")], String(node.get("from")) == "returned")
			_check("briefing: %s stands them at %s (%s)"
				% [name, want["at"], node.get("at")], node.get("at") == want["at"])
			_check("briefing: and hands them the right floor's warning on %s (%s)"
				% [name, String(node.get("say")).get_file()],
				String(node.get("say")) == want["say"])
			# THE FURNITURE RULE, on a person who walks to their spot: the lane
			# between the two doors is x 246-300 at every y, and a 64 px body
			# standing in it is one the player goes round on every later visit.
			var at: Vector2 = node.get("at")
			_check("briefing: and keeps them off the door line on %s (x %.0f)"
				% [name, at.x], at.x <= 240.0 or at.x >= 306.0)
			# Where Ivan is on the same floor, the two must not share a door:
			# one cue, one threshold, two solid bodies. See game/levels/relief.gd.
			var relief := room.get_node_or_null("Relief")
			if relief != null:
				_check("briefing: %s lets them in by a different door than Ivan (%s vs %s)"
					% [name, node.get("from"), relief.get("from")],
					String(node.get("from")) != String(relief.get("from")))
				_check("briefing: and stands them apart on %s (%.0f px)"
					% [name, (at as Vector2).distance_to(relief.get("at"))],
					at.distance_to(relief.get("at")) > 40.0)
		room.free()


## THE RULE THE THREE FLOORS ARE ONLY AN INSTANCE OF: a briefing sits on the
## floor below a boss, and on no other floor. Derived from the chain and from
## what is actually standing in each room, so a fourth boss added later fails
## here rather than shipping unannounced - and so a briefing left on a floor
## whose boss moved fails too.
func _chain() -> void:
	var boss := {}
	var briefed := {}
	for name in CHAIN:
		var room := (load("res://game/levels/%s/%s.tscn" % [name, name])
			as PackedScene).instantiate()
		briefed[name] = room.get_node_or_null("Briefing") != null
		boss[name] = false
		for node in room.get_node("Props").get_children():
			if node.is_in_group("bosses"):
				boss[name] = true
		room.free()
	var wrong: Array[String] = []
	for i in CHAIN.size():
		var name: String = CHAIN[i]
		var upstairs := i + 1 < CHAIN.size() and bool(boss[CHAIN[i + 1]])
		if bool(briefed[name]) != upstairs:
			wrong.append("%s %s" % [name, "unwarned" if upstairs else "spurious"])
	_check("briefing: one under every boss floor and nowhere else (%s)"
		% ("the whole chain" if wrong.is_empty() else ", ".join(wrong)),
		wrong.is_empty())
	var bosses := CHAIN.filter(func(n: String) -> bool: return bool(boss[n]))
	_check("briefing: and the chain still has the three bosses it had (%s)"
		% ", ".join(bosses), bosses.size() == 3)


## The Dominique the beat walked in, or null. HR is ALREADY standing in this
## lobby, so the group alone is not the answer here the way it is in
## test_ivan.gd - and the node's name is not the answer either, since nothing
## in this game finds anybody by one. What tells the two apart is the thing
## that actually differs: the conversation each of them is carrying.
func _npc_in_room() -> Node2D:
	for node in get_nodes_in_group("npcs"):
		if String(node.get("conversation")) == SAY:
			return node as Node2D
	return null


## Anything a heart could be hiding in. A briefing throws none; this is the
## check that says so out loud.
func _hearts_on_floor() -> Array:
	return _level().get_node("Props").get_children().filter(
		func(n: Node) -> bool: return n.name.begins_with("IvansHeart"))
