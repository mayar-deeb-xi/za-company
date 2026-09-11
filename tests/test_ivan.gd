extends "res://tests/helpers.gd"
## Ivan test: the third beat. That he waits for a fight and not merely for a
## quiet room, that he walks in through the door and crosses to his spot, that
## the hearts land on the last word of his lines, that they heal, that there is
## one per HEAD, and that there is only ever one lot of them. He is voiced, so
## it also reads his lines off disk and checks each one has a recording.
##
## Boots into the empty lobby and builds the beat by hand, the way
## test_reinforcements.gd does and for the same reason: what is under test is
## relief.gd's cue and ivan.gd's gift, not which six floors got one. The floors
## are checked off disk at the end, in `_baked()`.
##
## The lobby is also the one room where an arrival is legible - nothing else is
## standing in it - and the one where he is NOT placed, which keeps this suite's
## Ivan entirely its own.
##
## Frame budget: he walks at 45 px/s and the run is --fixed-fps 60, so the
## 76 px from the south door to his spot here is about 100 frames. Every wait
## below is that plus slack.

const RELIEF := preload("res://game/levels/relief.gd")
const IVAN := "res://game/npcs/ivan/ivan.tscn"
const OFFICE_BOY := "res://game/enemies/office_boy/office_boy.tscn"
const SAY := "res://game/npcs/ivan/after_the_fight.gd"

## Where this suite's beat sends him: clear of the lobby's furniture, clear of
## HR at (356, 226), and off the door line.
const STAND := Vector2(330, 190)

## Presses advance this often while the box is up - the same rate
## test_dialogue.gd uses. The first press of a line completes its reveal and the
## second advances it, so a line costs two.
const ADVANCE_EVERY := 6

var _beat: Node2D
var _boy: Node2D
var _ivan: Node2D
var _door := Vector2.ZERO
## Where he was standing on the first frame he existed. Caught as it happens
## rather than read a few frames later: he is walking from the moment he
## arrives, so "he came in through the door" is a question about one frame.
var _entered := Vector2.INF
var _advancing := false
var _talked := false
## The one heart he threw solo, kept so the collection check can walk onto it
## rather than onto where it was aimed.
var _heart: Area2D
var _health_before := 0
## The second Ivan, talked to with two heads in the room.
var _crowd_ivan: Node2D


func _tick(frame: int) -> void:
	if _ivan == null:
		_ivan = _ivan_in_room()
		if _ivan != null:
			_entered = _ivan.global_position
	if _advancing:
		if frame % ADVANCE_EVERY == 0:
			_key(KEY_E, true)
		elif frame % ADVANCE_EVERY == 3:
			_key(KEY_E, false)

	match frame:
		2:
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		17:
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
		32:
			_check("relief: the lobby starts empty, so the beat is ours (%d)"
				% get_nodes_in_group("enemies").size(),
				get_nodes_in_group("enemies").is_empty())
			_door = _level().call("spawn_position", &"start")
			# Out of the doorway and out of a boy's 80 px sight: this suite is
			# about a cue and a gift, and the fighting is test_combat's.
			_player().global_position = Vector2(272, 120)
			_beat = Node2D.new()
			_beat.name = "Relief"
			_beat.set_script(RELIEF)
			_beat.set("npc", "ivan")
			_beat.set("from", &"start")
			_beat.set("at", STAND)
			_beat.set("say", SAY)
			_level().add_child(_beat)
		44:
			# THE FIRST GUARD, and the one that is easy to leave out: a room is
			# clear on its first frame too. An Ivan who walks into a room where
			# nothing has happened yet is a vending machine standing in a
			# doorway, so the cue is a room that has been EMPTIED.
			_check("relief: an empty room is not a won one - nobody comes",
				_ivan_in_room() == null)
			_boy = (load(OFFICE_BOY) as PackedScene).instantiate() as Node2D
			_level().get_node("Props").add_child(_boy)
			_boy.global_position = Vector2(120, 248)
			_boy.set("sight_radius", 0.0)
		52:
			_check("relief: and he does not come while somebody is still standing",
				_ivan_in_room() == null)
			_boy.call("take_damage", 999)
		58:
			_check("relief: the room clears and he walks in", _ivan != null)
			if _ivan != null:
				_check("relief: through the south door, the way the player came (%s vs %s)"
					% [_entered, _door], _entered.distance_to(_door) < 1.0)
				_check("relief: friendly by group, like every other NPC",
					_ivan.is_in_group("npcs")
						and not _ivan.is_in_group("enemies")
						and not _ivan.is_in_group("player"))
				_check("relief: and he is on his way somewhere",
					bool(_ivan.call("walking")))
		170:
			_check("relief: he crosses to the spot the biome chose (%s vs %s)"
				% [_ivan.global_position, STAND],
				_ivan.global_position.distance_to(STAND) < 6.0)
			_check("relief: and stops there", not bool(_ivan.call("walking")))
			_check("relief: with nothing given until he has said it",
				_ivan.call("has_given") == false)
			_check("relief: no heart on the floor yet (%d)" % _hearts_thrown().size(),
				_hearts_thrown().is_empty())
			# Hurt on purpose: a heal is only readable against a bar that has
			# room in it, and the whole point of him is the floors where there
			# is no other way to get any back.
			_player().call("take_damage", 40)
		174:
			_health_before = int(_player().get("health"))
			_check("relief: the player has something to heal (%d of 100)"
				% _health_before, _health_before < 100)
			_player().global_position = Vector2(330, 214)
			# Stepped aside the moment he is done. He throws AT the player -
			# the fan is aimed at whoever he is talking to, so the open floor
			# is where they are standing - and a heart that lands under their
			# feet is collected on the frame it lands, which is the right game
			# and the wrong test: nothing would be left to look at. The throw
			# is set up in `set_talking(false)`, which _end() calls BEFORE it
			# emits this, so the landing spots are already chosen by now.
			_dialogue().connect("finished", func(_npc) -> void:
				_talked = true
				_player().global_position = Vector2(290, 262))
		186:
			_check("relief: his prompt comes up in range",
				(_ivan.get_node("Prompt") as Control).visible)
			# THE WIRING THIS SUITE EXISTS TO CATCH. He was added to the room
			# minutes after game.gd swept it for NPCs, so if the director is
			# only wired at build time his prompt comes up and the key does
			# nothing - a silent failure on six floors.
			_advancing = true
		300:
			_advancing = false
			_key(KEY_E, false)
			_check("relief: an NPC who arrived late can still be talked to",
				_talked)
			var thrown := _hearts_thrown()
			_check("relief: one head, one heart (%d)" % thrown.size(),
				thrown.size() == 1)
			_check("relief: and he has nothing left to give",
				_ivan.call("has_given") == true)
			if not thrown.is_empty():
				_heart = thrown[0]
				_check("relief: it landed live, not in his hands",
					_heart.monitoring)
				_check("relief: and within reach of the man who threw it (%.0f px)"
					% _heart.global_position.distance_to(_ivan.global_position),
					_heart.global_position.distance_to(_ivan.global_position) < 40.0)
		312:
			if _heart != null:
				_player().global_position = _heart.global_position
		322:
			_check("relief: walking onto it heals (%d -> %d)"
				% [_health_before, int(_player().get("health"))],
				int(_player().get("health")) > _health_before)
			_check("relief: and it is gone once taken",
				_heart == null or not is_instance_valid(_heart))
			# ---- One per head ------------------------------------------
			# The other half of `per_head`, read the other way round. A party
			# of four meeting four times the bodies and sharing one heart is
			# the same unfairness twice, and both numbers come out of
			# game/heads.gd - which is the whole reason that file exists.
			var second := Node2D.new()
			second.name = "SecondPlayer"
			second.add_to_group("player")
			_level().add_child(second)
			second.global_position = Vector2(80, 80)
			_crowd_ivan = (load(IVAN) as PackedScene).instantiate() as Node2D
			_crowd_ivan.name = "CrowdIvan"
			_level().get_node("Props").add_child(_crowd_ivan)
			_crowd_ivan.global_position = Vector2(200, 160)
		324:
			# Driven by the edges the director drives, without the box: what is
			# under test is the gift, and test_dialogue.gd owns the subtitles.
			_crowd_ivan.call("set_talking", true)
		326:
			_crowd_ivan.call("set_talking", false)
		380:
			var thrown := _hearts_thrown()
			_check("relief: two heads, two hearts (%d)" % thrown.size(),
				thrown.size() == 2)
			var live := thrown.filter(func(h: Area2D) -> bool: return h.monitoring)
			_check("relief: both of them live (%d)" % live.size(), live.size() == 2)
			# A lifeline, not a fountain: a room that can be talked at for
			# health is a room with no fight left in it.
			_crowd_ivan.call("set_talking", true)
		382:
			_crowd_ivan.call("set_talking", false)
		440:
			_check("relief: he gives once, however often he is asked (%d)"
				% _hearts_thrown().size(), _hearts_thrown().size() == 2)
			_clips()
			_baked()
			_finish()


## The other half of a voiced conversation, on test_dialogue.gd's exact terms:
## every line he speaks names a clip, and every clip named is really there. A
## mistyped path is SILENT at runtime - the box plays what exists and types on
## regardless - so nothing else in the game would ever report one. Both halves
## also need the WAVs imported, which is the one thing a fresh checkout has not
## done yet; that is the same miss every other sound here is allowed, and this
## is the one place it is not quiet about it.
func _clips() -> void:
	var beats: Array = (load(SAY) as GDScript) \
		.get_script_constant_map().get("BEATS", [])
	var silent: Array[String] = []
	var missing: Array[String] = []
	for beat in beats:
		var path := String(beat.get("voice", ""))
		if path == "":
			silent.append(String(beat.get("text", "")).substr(0, 24))
			continue
		if not ResourceLoader.exists(path):
			missing.append(path.get_file())
	_check("voice: every line he says names a clip (%d of them%s)"
		% [beats.size(),
			"" if silent.is_empty() else ", missing " + ", ".join(silent)],
		beats.size() > 0 and silent.is_empty())
	_check("voice: and every clip is on disk (%s)"
		% ("all there" if missing.is_empty() else ", ".join(missing)),
		missing.is_empty())


## The floors that actually carry the beat, read back off disk. Everything above
## builds its own, so without this the six biome entries could be empty and
## every check would still pass - the same hole `_baked()` closes in
## test_reinforcements.gd.
func _baked() -> void:
	var floors := {
		"call_center": Vector2(208, 168),
		"ahmed_office": Vector2(180, 160),
		"conflict_resolution": Vector2(412, 144),
		"asset_recovery": Vector2(80, 180),
		"executive_floor": Vector2(324, 196),
		"khaled_office": Vector2(400, 176),
	}
	for name in floors:
		var room := (load("res://game/levels/%s/%s.tscn" % [name, name])
			as PackedScene).instantiate()
		var node := room.get_node_or_null("Relief")
		_check("relief: %s carries the beat its biome asked for" % name,
			node != null)
		if node != null:
			_check("relief: %s sends him to %s (%s)"
				% [name, floors[name], node.get("at")],
				node.get("at") == floors[name])
			_check("relief: and gives him something to say on %s (%s)"
				% [name, node.get("say")], String(node.get("say")) == SAY)
		# THE FURNITURE RULE, on the one spot in the game that is authored for
		# somebody who walks to it: an NPC is a solid body, and one standing on
		# the straight walk between the two doors is one the player has to get
		# round on every future visit. The lane is x 246-300 at every y.
		if node != null:
			var at: Vector2 = node.get("at")
			_check("relief: and keeps him off the door line on %s (x %.0f)"
				% [name, at.x], at.x <= 240.0 or at.x >= 306.0)
		room.free()
	# The lobby is the one floor that hands out a heart for free, and the one
	# floor with no fight to be after. Both halves of that have to stay true.
	var lobby := (load("res://game/levels/lobby/lobby.tscn")
		as PackedScene).instantiate()
	_check("relief: the lobby has no beat - nothing to be after",
		lobby.get_node_or_null("Relief") == null)
	lobby.free()


## The Ivan the beat walked in, or null. Found by group rather than by node
## name, the same way everything else in this game finds anybody.
func _ivan_in_room() -> Node2D:
	for node in get_nodes_in_group("npcs"):
		if node.has_method("has_given"):
			return node as Node2D
	return null


## Every heart on the floor that came out of his hands, told from a level's own
## by the name the throw gives them.
func _hearts_thrown() -> Array:
	var found: Array = []
	for node in _level().get_node("Props").get_children():
		if node.name.begins_with("IvansHeart") and is_instance_valid(node):
			found.append(node)
	return found
