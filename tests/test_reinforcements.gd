extends "res://tests/helpers.gd"
## Reinforcement test: the trigger, the single-file arrival, the door they use,
## the hold while the player stands in it, that a beat fires ONCE, and that the
## group scales with how many players are in the room.
##
## Boots into the empty lobby like test_combat.gd and test_bosses.gd and builds
## the beat by hand rather than walking nine floors to the one biome that has
## one: what is under test is reinforcements.gd's counting, not asset recovery's
## dressing - test_flow.gd already walks that room and asserts its four.
##
## Every enemy PLACED here has its sight zeroed, so nobody chases and nobody
## swings; the arrivals keep their own sight, and the player is parked 140 px up
## the room, outside it. The room is a counting problem on purpose - the
## fighting is test_combat's job - and an enemy that never moves is also an
## enemy still standing where it spawned when a check asks.
##
## Frame budget: RELEASE_INTERVAL is 0.6s and the suite runs at --fixed-fps 60,
## so one arrival follows another 36 frames later. Every wait below is that
## interval plus slack.

const REINFORCEMENTS := preload("res://game/levels/reinforcements.gd")
const OFFICE_BOY := "res://game/enemies/office_boy/office_boy.tscn"
const AHMED := "res://game/bosses/ahmed/ahmed.tscn"

var _beats: Node2D
var _placed: Array[Node2D] = []
var _door := Vector2.ZERO

# The boss cue, fought last in the same room once the counting is done.
var _ahmed: Node2D
var _boss_beats: Node2D


func _tick(frame: int) -> void:
	match frame:
		2:
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		17:
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
		32:
			_check("reinforcements: the lobby starts empty, so the beat is placed (%d)"
				% get_nodes_in_group("enemies").size(),
				get_nodes_in_group("enemies").is_empty())
			_door = _level().call("spawn_position", &"start")
			# Out of the doorway and out of an arrival's 80 px sight, so the
			# pair stands where it lands. Standing IN it is its own check, at
			# frame 120.
			_player().global_position = Vector2(272, 100)
			for at in [Vector2(104, 60), Vector2(436, 64), Vector2(120, 248)]:
				_placed.append(_place(at))
			_beats = Node2D.new()
			_beats.name = "Reinforcements"
			_beats.set_script(REINFORCEMENTS)
			# Two beats: the first is asset recovery's own shape, the second is
			# there to be doubled by a second head at frame 118.
			_beats.set("waves", [
				{"after_kills": 2, "from": "start",
					"enemies": ["office_boy", "office_boy"]},
				{"after_kills": 5, "from": "start",
					"enemies": ["office_boy"]},
			])
			_level().add_child(_beats)
		34:
			_check("reinforcements: three placed, none arrived (%d)"
				% get_nodes_in_group("enemies").size(),
				get_nodes_in_group("enemies").size() == 3)
		36:
			_placed[0].call("take_damage", 999)
		40:
			_check("reinforcements: one dead is under the threshold, so nobody comes (%d)"
				% get_nodes_in_group("enemies").size(),
				get_nodes_in_group("enemies").size() == 2)
		42:
			_placed[1].call("take_damage", 999)
		48:
			# Two dead and the beat fires - but ONE of the pair walks in, not
			# both. A doorway is single file, and the release interval is what
			# makes it one.
			_check("reinforcements: the second kill brings one in, alone (%d)"
				% get_nodes_in_group("enemies").size(),
				get_nodes_in_group("enemies").size() == 2)
			var arrived := _arrivals()
			_check("reinforcements: exactly one has arrived (%d)"
				% arrived.size(), arrived.size() == 1)
			if not arrived.is_empty():
				var first := (arrived[0] as Node2D).global_position
				_check("reinforcements: it walked in through the south door (%s vs %s)"
					% [first, _door], first.distance_to(_door) < 1.0)
				_check("reinforcements: an office boy, so a guard's health (%s)"
					% arrived[0].get("max_health"),
					arrived[0].get("max_health") == 24)
		60:
			_check("reinforcements: still single file part-way through the interval (%d)"
				% _arrivals().size(), _arrivals().size() == 1)
		90:
			_check("reinforcements: the interval passes and the second follows (%d)"
				% _arrivals().size(), _arrivals().size() == 2)
			_check("reinforcements: three alive - one placed, two arrived (%d)"
				% get_nodes_in_group("enemies").size(),
				get_nodes_in_group("enemies").size() == 3)
		110:
			# Finite: long past both releases, the spent beat sends nothing more.
			_check("reinforcements: a beat fires once and stays fired (%d)"
				% _arrivals().size(), _arrivals().size() == 2)
		118:
			# The multiplayer seam, tested rather than promised. A second node in
			# the `player` group is a second head, and it has to exist BEFORE the
			# beat fires - the count is read when the group is assembled, which
			# is the honest moment: a room decides how many are coming as they
			# set off, not one at a time as they arrive.
			#
			# Parked in the far corner, out of the doorway's 64 px hold radius
			# and out of anybody's sight, so it is a head and nothing else.
			var second := Node2D.new()
			second.name = "SecondPlayer"
			second.add_to_group("player")
			_level().add_child(second)
			second.global_position = Vector2(80, 80)
		120:
			# Stand in the doorway and clear the room. The next beat's threshold
			# is met on the same frame, but an arrival must never land on top of
			# anybody, so nothing may come until the player moves.
			_player().global_position = _door
			for enemy in get_nodes_in_group("enemies"):
				enemy.call("take_damage", 999)
		126:
			_check("reinforcements: the room is empty and the next beat is owed (%d)"
				% get_nodes_in_group("enemies").size(),
				get_nodes_in_group("enemies").is_empty())
		150:
			_check("reinforcements: it holds while the player stands in the doorway (%d)"
				% get_nodes_in_group("enemies").size(),
				get_nodes_in_group("enemies").is_empty())
			_player().global_position = Vector2(272, 100)
		156:
			_check("reinforcements: the held beat lands once the doorway clears (%d)"
				% get_nodes_in_group("enemies").size(),
				get_nodes_in_group("enemies").size() == 1)
		200:
			var here := get_nodes_in_group("enemies")
			_check("reinforcements: two heads doubled a one-enemy beat (%d)"
				% here.size(), here.size() == 2)
			var tough := here.filter(func(e: Node) -> bool:
				return e.get("max_health") != 24)
			_check("reinforcements: more bodies, never tougher ones (%d off breakpoint)"
				% tough.size(), tough.is_empty())
		240:
			_check("reinforcements: both beats spent, nothing else arrives (%d)"
				% get_nodes_in_group("enemies").size(),
				get_nodes_in_group("enemies").size() == 2)
			# ---- The boss cue -------------------------------------------
			# A boss floor's beat is cued by his HEALTH, because kills cannot
			# serve it: a boss is in the `enemies` group and is never freed, so
			# he never counts as a kill and `_killed()` can only ever reach 0
			# on a floor whose whole population is him.
			#
			# The room is cleared back to one head first. The head count is
			# asserted above and doubling it here would only make the arrivals
			# harder to count; what is under test now is the CUE.
			var second := _level().get_node_or_null("SecondPlayer")
			if second != null:
				second.queue_free()
			for enemy in get_nodes_in_group("enemies"):
				enemy.free()
			# Named "Boss" and under Props because that is where build_levels.gd
			# puts him and therefore where _due() looks - a wrong path here is
			# a beat that never fires and never complains, which is the failure
			# this section exists to catch. Sight zeroed like the placed boys:
			# the room stays a counting problem, and his own fight is
			# test_bosses.gd's.
			_ahmed = (load(AHMED) as PackedScene).instantiate() as Node2D
			_ahmed.name = "Boss"
			_level().get_node("Props").add_child(_ahmed)
			_ahmed.global_position = Vector2(120, 60)
			_ahmed.set("sight_radius", 0.0)
			_boss_beats = Node2D.new()
			_boss_beats.name = "BossBeats"
			_boss_beats.set_script(REINFORCEMENTS)
			# Ahmed's own floor: one boy at each third of his 96.
			_boss_beats.set("waves", [
				{"at_boss_health": 64, "from": "start",
					"enemies": ["office_boy"]},
				{"at_boss_health": 32, "from": "start",
					"enemies": ["office_boy"]},
			])
			_level().add_child(_boss_beats)
		246:
			_check("boss cue: a boss at full health owes nothing (%d)"
				% _arrivals().size(), _arrivals().is_empty())
			_check("boss cue: and he does not count as a kill against it (%s)"
				% _ahmed.get("health"), _ahmed.get("health") == 96)
		248:
			_ahmed.call("take_damage", 40)
		258:
			_check("boss cue: down to a third and security arrives (%s HP, %d in)"
				% [_ahmed.get("health"), _arrivals().size()],
				_ahmed.get("health") == 56 and _arrivals().size() == 1)
		300:
			_check("boss cue: one threshold is one beat, not a stream (%d)"
				% _arrivals().size(), _arrivals().size() == 1)
		302:
			# Straight to zero, crossing the second threshold and conceding on
			# the same blow.
			_ahmed.call("take_damage", 999)
		306:
			_check("boss cue: he conceded (%s)" % _ahmed.get("has_conceded"),
				_ahmed.get("has_conceded") == true)
		340:
			# THE GUARD. He concedes AT zero, which satisfies every threshold at
			# once, so without the concede check in _due() the last beat of a
			# fight lands on the frame the fight ends - reinforcements walking
			# in to a room whose boss is already kneeling.
			_check("boss cue: conceding does not cash in the beats he outlived (%d)"
				% _arrivals().size(), _arrivals().size() == 1)
			_baked()
			_finish()


## The one thing the beat above cannot check, because it sets `waves` by hand:
## that the list SURVIVES the round trip through build_levels.gd and the .tscn.
## A biome dictionary is written out as an export and read back as one, and a
## generator quietly writing an empty array would leave every check above
## passing and the actual floor silent.
func _baked() -> void:
	var room := (load("res://game/levels/asset_recovery/asset_recovery.tscn")
		as PackedScene).instantiate()
	var node := room.get_node_or_null("Reinforcements")
	_check("reinforcements: asset recovery carries the node the biome asked for",
		node != null)
	if node != null:
		var waves: Array = node.get("waves")
		_check("reinforcements: its one beat came back off disk (%d)"
			% waves.size(), waves.size() == 1)
		if waves.size() == 1:
			var beat: Dictionary = waves[0]
			_check("reinforcements: two office boys at three kills, by the south door (%s)"
				% beat,
				int(beat.get("after_kills", 0)) == 3
					and String(beat.get("from", "")) == "start"
					and beat.get("enemies", []) == ["office_boy", "office_boy"])
	room.free()
	# The health cue makes the same round trip, and a boss floor is where an
	# empty array would be invisible: the room looks right, the boss fights,
	# and the adds his biome asked for simply never come.
	for floor_name in ["ahmed_office", "conflict_resolution"]:
		var arena := (load("res://game/levels/%s/%s.tscn"
			% [floor_name, floor_name]) as PackedScene).instantiate()
		var beats := arena.get_node_or_null("Reinforcements")
		var waves: Array = [] if beats == null else beats.get("waves")
		var cued: Array = waves.filter(func(w: Dictionary) -> bool:
			return w.has("at_boss_health") and not w.has("after_kills"))
		_check("reinforcements: %s carries two health-cued beats (%d of %d)"
			% [floor_name, cued.size(), waves.size()],
			waves.size() == 2 and cued.size() == 2)
		# A boss floor's adds must not ALSO be placed: an add standing in the
		# arena from the first frame is the thing the cue exists to avoid.
		var standing: Array = arena.get_node("Props").get_children().filter(
			func(n: Node) -> bool:
				return n.is_in_group("enemies") and n.name != "Boss")
		_check("reinforcements: and nobody stands in %s but the boss (%d)"
			% [floor_name, standing.size()], standing.is_empty())
		arena.free()
	# The executive floor's marker, which is the half of its beat that can go
	# missing quietly: spawn_position falls back to the middle of the room on an
	# unknown name, and here that is 16 px from the real thing.
	var exam := (load("res://game/levels/executive_floor/executive_floor.tscn")
		as PackedScene).instantiate()
	var marker := exam.get_node_or_null("Spawns/chokepoint")
	_check("reinforcements: the executive floor has a chokepoint to arrive at (%s)"
		% ("<missing>" if marker == null else marker.position),
		marker != null and marker.position == Vector2(272, 168))
	exam.free()


## An office boy standing where it is put: sight zeroed so it never chases and
## never swings, which is what keeps this file a counting test.
func _place(at: Vector2) -> Node2D:
	var enemy := (load(OFFICE_BOY) as PackedScene).instantiate() as Node2D
	_level().get_node("Props").add_child(enemy)
	enemy.global_position = at
	enemy.set("sight_radius", 0.0)
	return enemy


## Everything reinforcements.gd has sent in, told from the hand-placed three by
## the name the spawner gives them.
func _arrivals() -> Array:
	return get_nodes_in_group("enemies").filter(func(e: Node) -> bool:
		return e.name.begins_with("Reinforcement"))
