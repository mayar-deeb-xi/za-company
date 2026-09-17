extends "res://tests/helpers.gd"
## The floor that is not a rectangle, and the two things a shaped room can break
## that a rectangular one never could.
##
## Eleven floors are the 34 x 19 box the building was designed around, and every
## rule about placement in this project was written while that was true of all
## of them. The call floor is 40 x 34 with its north-west quarter taken out, so
## its two doors are not in line with each other and the walk between them has
## two corners in it. That is worth its own suite for the same reason
## test_steering.gd is: the checks need a room arranged in a way no other floor
## is, and the failures they catch are silent rather than loud.
##
## ## The two failures
##
## **A room you cannot cross.** Every other check in this project assumes the
## player can get from one door to the other; on a shaped floor that is a thing
## that can simply stop being true, and nothing else would notice. A prop moved
## twenty pixels, a cut redrawn one tile lower, a lane leg left where the room
## used to be - each one is a floor nobody can finish, and each one looks fine
## in the data. So the walk is sampled end to end against the masonry, on every
## floor in the chain rather than on this one, because a rule about shapes that
## only looks at the shaped floor is a rule that will be broken by the next one.
##
## **A body that cannot get round the corner.** Enemies have no pathfinding:
## steering is `walk at the player` plus a committed sidestep when that stops
## making ground (see test_steering.gd). Every obstacle in the game has so far
## been furniture-sized, and the thing between a body in this floor's arm and a
## player in its hall is a corner of the BUILDING - eight tiles of it. If a body
## wedges there the room is a walkover and the only symptom is a fight that
## feels thin.
##
## What is NOT a symptom, and was the first thing this suite got wrong: a beat
## that arrives and then stands in the arm. A reinforcement is `unleash()`d, so
## it has no post - and a body with no post has no PATIENCE either, which means
## it hunts only what it can actually see. Two boys arriving at the top of the
## stairs while the player is at the far end of the hall are 620 px away and
## notice nothing, on this floor exactly as on the eleven rectangular ones. They
## are holding the corridor the player has to climb, which is the arrival doing
## its job rather than failing to. So the corner is staged at the range the
## question is actually asked at: close enough to be seen, with the masonry in
## between.
##
## What is deliberately NOT here: the floor's composition, its wiring and its
## dressing, which are test_flow.gd's and test_surge.gd's and have not changed
## their address just because the room changed shape.

const CHAIN := ["lobby", "content_studio", "call_center", "ahmed_office",
	"the_hub", "marble_hall", "innovation_lab", "conflict_resolution",
	"asset_recovery", "hellfire", "executive_floor", "khaled_office"]

const CALL_CENTER := "res://game/levels/call_center/call_center.tscn"
const GUARD := "res://game/enemies/office_boy/office_boy.tscn"

## Sampled along and across each leg of a walk. A quarter of a tile, so nothing
## the size of a wall can hide between two samples.
const STEP := 4.0

## Where the beat comes in: the arm's own door, at the top of the stairs.
const ARM_DOOR := Vector2(480, 80)
## The corner case, at the range it is really asked at. Both bodies are in the
## arm and the player is in the hall west of it, inside a guard's 80 px sight -
## which is the only range at which the question exists, because a guard that
## cannot see the player is not trying to reach them. The building's own corner
## is on the line between them, so walking straight at the player walks into
## masonry and arriving at all means going round.
##
## Getting this wrong is instructive and cost two runs of this suite: a body
## staged 85 px away stands perfectly still for four seconds and reads exactly
## like a body wedged in a corner.
const IN_THE_ARM := Vector2(372, 254)
const SECOND_BODY := Vector2(386, 244)
const ROUND_THE_CORNER := Vector2(330, 296)
## The arm ends and the hall begins here. A body south of it has turned the
## corner; one north of it is still in the corridor.
const HALL_TOP := 280.0
## Four seconds at 50 px/s is 200 px for a journey of about 100, which leaves
## room for a sidestep or two without the check passing by accident.
const PATIENCE := 240

var _t0 := 0
var _beat: Array[CharacterBody2D] = []
var _closest := INF


func _tick(frame: int) -> void:
	if _t0 == 0:
		_shapes()
		_lobby(frame)
		if _level() != null and _level().name == "CallCenter":
			_t0 = frame
		return
	_arm(frame - _t0)


## Every floor's walk, read off disk, against every floor's walls. This is the
## check that generalizes: a floor added next month in a shape nobody has drawn
## yet is crossable or it is not, and this says which without anybody playing it.
func _shapes() -> void:
	if _checks > 0:
		return
	var uncrossable: Array[String] = []
	var unreachable: Array[String] = []
	var buried: Array[String] = []
	for name: String in CHAIN:
		var room := (load("res://game/levels/%s/%s.tscn" % [name, name])
			as PackedScene).instantiate()
		var walls := room.get_node("Walls") as TileMapLayer
		var tile: int = walls.tile_set.tile_size.x
		# A wall is the FACE the building turns to the room and nothing behind
		# it is painted, so what a cut comes out as is a hole showing the clear
		# colour rather than a slab of the level's own rock. Read back as the
		# absence of a wall tile with no floor anywhere around it: the rule was
		# already true of the eleven rectangles, so this only bites on a shaped
		# floor - and it bites the moment a regeneration fills one in again,
		# which is a change nothing else here would notice.
		var floors := room.get_node("Floor") as TileMapLayer
		for cell in walls.get_used_cells():
			var faces := false
			for x in [-1, 0, 1]:
				for y in [-1, 0, 1]:
					if floors.get_cell_source_id(cell + Vector2i(x, y)) != -1:
						faces = true
			if not faces:
				buried.append("%s at %s" % [name, cell])
		for leg: Rect2 in room.call("walk_lane"):
			var x := leg.position.x
			while x < leg.end.x:
				var y := leg.position.y
				while y < leg.end.y:
					var cell := Vector2i(int(x) / tile, int(y) / tile)
					if walls.get_cell_source_id(cell) != -1:
						uncrossable.append("%s at (%.0f, %.0f)" % [name, x, y])
					y += STEP
				x += STEP
		# And it has to be the walk between the DOORS rather than a corridor
		# somewhere else in the room: both thresholds stand on it.
		for door: String in ["Exit", "Return"]:
			var node := room.get_node_or_null("Props/" + door) as Node2D
			if node == null:
				continue   # the ends of the chain have only one way out
			# A door is cut into the wall, so the walk reaches the floor just
			# inside it rather than the threshold itself.
			var inside := node.position + Vector2(0, tile if door == "Exit" else -tile)
			if room.call("lane_clearance", inside) > 0.0:
				unreachable.append("%s %s" % [name, door])
		room.free()
	_check("shape: every floor's walk is floor, end to end (%d in masonry%s)"
		% [uncrossable.size(), "" if uncrossable.is_empty()
			else " -> " + ", ".join(uncrossable.slice(0, 3))],
		uncrossable.is_empty())
	_check("shape: and it runs between the two doors rather than past them (%s)"
		% ("all twelve" if unreachable.is_empty() else ", ".join(unreachable)),
		unreachable.is_empty())
	_check("shape: a wall is the face the room turns to you, one tile of it "
		+ "(%d buried%s)" % [buried.size(), "" if buried.is_empty()
			else " -> " + ", ".join(buried.slice(0, 3))],
		buried.is_empty())

	# The call floor is the instance, and these are the numbers the rest of this
	# suite leans on. Stated here so a reshaped room fails with its own
	# dimensions rather than as a mysterious timeout below.
	var call_floor := (load(CALL_CENTER) as PackedScene).instantiate()
	var box: Rect2 = call_floor.call("bounds")
	_check("shape: the call floor is the dogleg, 640 x 592 (%s)" % box.size,
		box.size == Vector2(640, 592))
	var up := (call_floor.get_node("Props/Exit") as Node2D).position
	var back := (call_floor.get_node("Props/Return") as Node2D).position
	_check("shape: its two doors are not in line with each other (%.0f vs %.0f)"
		% [up.x, back.x], absf(up.x - back.x) > 100.0)
	_check("shape: and its walk has the corners to join them (%d legs)"
		% (call_floor.call("walk_lane") as Array).size(),
		(call_floor.call("walk_lane") as Array).size() == 3)
	call_floor.free()


func _lobby(frame: int) -> void:
	match frame:
		2:
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		17:
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
		32:
			_level().get_node("Props/Exit").travelled.emit(CALL_CENTER, &"start")


func _arm(at: int) -> void:
	match at:
		2:
			# The room emptied of everything that could reach the pair being
			# watched, so what they walk into is the ROOM rather than a fight.
			# The beat is then staged by hand at the door it really uses, the
			# way test_reinforcements.gd stages its own.
			for enemy in get_nodes_in_group("enemies"):
				enemy.queue_free()
			for beat: String in ["Reinforcements", "Relief", "Briefing"]:
				var node := _level().get_node_or_null(beat)
				if node != null:
					node.queue_free()
			_player().global_position = ROUND_THE_CORNER
			_check("beat: it arrives at the arm's own door (%s)"
				% _level().call("spawn_position", &"returned"),
				_level().call("spawn_position", &"returned") == ARM_DOOR)
		6:
			for spot: Vector2 in [IN_THE_ARM, SECOND_BODY]:
				var guard := (load(GUARD) as PackedScene).instantiate() as CharacterBody2D
				_level().get_node("Props").add_child(guard)
				guard.global_position = spot
				# A reinforcement has no post to be held near, which is the one
				# thing that could keep it in the corridor: a leashed body walks
				# home rather than round a corner.
				if guard.has_method("unleash"):
					guard.call("unleash")
				_beat.append(guard)
			_check("beat: two bodies standing in the arm (%d)" % _beat.size(),
				_beat.size() == 2)
			# The premise, measured rather than asserted: each body can see the
			# player, and each one has masonry on the straight line to them. A
			# staging that quietly lost either would make the checks below pass
			# or fail for reasons that have nothing to do with the corner.
			var seen := _beat.filter(func(n: CharacterBody2D) -> bool:
				return n.global_position.distance_to(_player().global_position) 					<= float(n.get("sight_radius")))
			_check("corner: both can see the player from the arm (%d of 2)"
				% seen.size(), seen.size() == 2)
			var walled := _beat.filter(func(n: CharacterBody2D) -> bool:
				return _crosses_masonry(n.global_position, _player().global_position))
			_check("corner: and the building is between them and it (%d of 2)"
				% walled.size(), walled.size() == 2)
		PATIENCE:
			var where: Array[String] = []
			var out := _beat.filter(func(n: CharacterBody2D) -> bool:
				where.append("(%.0f, %.0f)" % [n.global_position.x, n.global_position.y])
				return is_instance_valid(n) and n.global_position.y > HALL_TOP)
			_check("corner: both got out of the arm and into the hall (%d of 2, at %s)"
				% [out.size(), ", ".join(where)], out.size() == 2)
			_check("corner: and reached the player round it (%.0f px away)"
				% _closest, _closest < 24.0)
			_finish()
		_:
			for guard in _beat:
				if is_instance_valid(guard):
					_closest = minf(_closest,
						guard.global_position.distance_to(_player().global_position))


## Whether the straight line between two points passes through a wall - which is
## what makes this a corner rather than an open room, and the one thing about
## the staging that cannot be read off a coordinate.
func _crosses_masonry(from: Vector2, to: Vector2) -> bool:
	var walls := _level().get_node("Walls") as TileMapLayer
	var tile: int = walls.tile_set.tile_size.x
	var steps := int(from.distance_to(to) / STEP)
	for i in steps + 1:
		var point := from.lerp(to, float(i) / steps)
		if walls.get_cell_source_id(
				Vector2i(int(point.x) / tile, int(point.y) / tile)) != -1:
			return true
	return false
