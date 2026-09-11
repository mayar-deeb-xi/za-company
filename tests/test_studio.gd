extends "res://tests/helpers.gd"
## The content studio's clock, and the two things that read it: the five ring
## lights going hot and the dolly running its rail.
##
## Its own suite because it needs a room left ALONE for eleven seconds. The
## clock's whole contract is a rhythm - five seconds of rest, a second and a
## half of warning, four and a half of danger - and the only way to check a
## rhythm is to stand still in it and watch, which is the exact opposite of
## every other suite in this project. Threaded into test_flow.gd it would have
## put a 660-frame wait in the middle of a walk through twelve floors.
##
## The room's own composition - five lights, the fallen sixth, three drains and
## the boy - is test_flow.gd's and is not re-checked here. What IS checked here
## is everything that only exists while the room is running.
##
## ## The one check that happens before the studio
##
## `ring_light` is a catalogue prop and any floor may stand one. The promise is
## that a lamp only burns on a floor that runs a clock, so the first thing this
## suite does is stand one of the studio's own lamps in the LOBBY, park the
## player in its pool, and watch nothing happen. A promise about absence has to
## be tested where the thing is absent.
##
## ## Why the enemies are cleared on arrival
##
## Three drain fields reach most of this room and a drain sits outside the grace
## window in both directions, so a health check inside one is measuring two
## things. The fight is test_flow.gd's and test_combat.gd's; what is under test
## here is whether a lamp burns at the right moment, which needs health to have
## exactly one cause. The second beat goes with them - clearing the room is four
## kills, and a beat firing would walk two more drains back in.
##
## ## Anchored on the clock, not on frame 1
##
## Every check below is offset from the frame the `Studio` node first appears,
## because getting there costs a fade whose length is game.gd's business. The
## offsets themselves are the authored seconds times 60, and the authored
## seconds are checked as data on arrival - so a retuned biome fails the first
## check with a number in the message rather than failing six timing checks with
## nothing to read.

const RING_LIGHT := "res://game/levels/content_studio/props/hardware/ring_light.tscn"
const STUDIO := "res://game/levels/content_studio/content_studio.tscn"

## The authored clock, in frames at 60fps. Kept here as the suite's own
## expectation and checked against the scene's exports at +2, which is what
## makes a retune a one-line failure rather than a puzzle.
const REST := 300
const LEAD := 90
const TAKE := 270

## The door lane every floor keeps walkable, top to bottom. The dolly is the
## first thing in this game that could threaten it without ever being PLACED in
## it, so the rail's span is checked against it directly.
const LANE_LEFT := 246

## A ring light standing clear of every sight radius in the room: 105 px from
## the boy's 80 and 177 from the nearest drain's 120, so a player parked in its
## pool is being touched by the lamp and by nothing else.
const LONE_LIGHT := Vector2(336, 100)
## In the pool, below the tripod's own box.
const IN_POOL := Vector2(336, 108)
## On the rail, far enough along it that the rig takes a full second to reach
## them - long enough that the hit is the dolly ARRIVING rather than the player
## being placed inside it.
const ON_RAIL := Vector2(134, 168)

var _t0 := 0
var _lamp: Node2D = null
var _cue_heat := 0.0


func _tick(frame: int) -> void:
	if _t0 == 0:
		_lobby(frame)
		if _studio() != null:
			_t0 = frame
		return
	_studio_floor(frame - _t0)


## Before the studio: the same lamp, on a floor with no clock.
func _lobby(frame: int) -> void:
	match frame:
		2:
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		17:
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
		32:
			_lamp = (load(RING_LIGHT) as PackedScene).instantiate()
			_lamp.position = LONE_LIGHT
			_level().get_node("Props").add_child(_lamp)
			_check("clock: a lamp carries its heat wherever it is stood",
				_lamp.get_node_or_null("Burn") != null)
			_player().global_position = Vector2(
				LONE_LIGHT.x, LONE_LIGHT.y + 8.0)
			_health_mark = _player().health
		110:
			# Long past a take, a cue and most of a rest, had there been one.
			_check("clock: with no clock in the room the lamp is furniture (%d -> %d)"
				% [_health_mark, _player().health], _player().health == _health_mark)
			_lamp.queue_free()
			_level().get_node("Props/Exit").travelled.emit(STUDIO, &"start")


func _studio_floor(at: int) -> void:
	match at:
		2:
			_arrive()
		60:
			_check("rest: nothing is rolling and nothing is warm (%.2f)"
				% _heat(), not _rolling() and _heat() == 0.0)
			_check("rest: the dolly is parked at its mark (%s)"
				% _dolly().position, _dolly().position == _park())
			_check("rest: the sign is cold (%.2f)" % _neon_level(),
				_neon_level() < 0.5)
			_check("rest: standing in a pool costs nothing (%d -> %d)"
				% [_health_mark, _player().health], _player().health == _health_mark)
		REST - 10:
			_check("rest: still cold on the last frames of it (%.2f)"
				% _heat(), _heat() == 0.0 and not _rolling())
		REST + 45:
			# Halfway through the lead-in. The pool is open on the floor and the
			# sign is coming up, and NOTHING has happened yet - which is the
			# whole of what makes a room that switches on fair.
			_cue_heat = _heat()
			_check("cue: the room warms before it burns (%.2f)" % _cue_heat,
				_cue_heat > 0.05 and _cue_heat < 0.95)
			_check("cue: warming is not yet rolling", not _rolling())
			_check("cue: the sign comes up with the pools (%.2f)"
				% _neon_level(), _neon_level() > 0.5)
			_check("cue: a telegraph does not hurt (%d -> %d)"
				% [_health_mark, _player().health], _player().health == _health_mark)
			_check("cue: the dolly waits for action too (%s)"
				% _dolly().position, _dolly().position == _park())
		REST + LEAD + 10:
			_check("take: the cue lands on a take (%.2f)" % _heat(),
				_rolling() and _heat() == 1.0)
			_check("take: the sign is at full output (%.2f)" % _neon_level(),
				_neon_level() > 0.99)
		REST + LEAD + 60:
			_check("take: the pool burns once it is rolling (%d -> %d)"
				% [_health_mark, _player().health], _player().health < _health_mark)
			# Onto the rail for the other half of the floor. Healed first, so
			# the next check is measuring the rig and not the lamp it just left.
			_player().global_position = ON_RAIL
			_player().call("heal", 100)
			_health_mark = _player().health
		REST + LEAD + 130:
			_check("take: the rig leaves its mark and runs (%s)"
				% _dolly().position, _dolly().position.x > _park().x + 20.0)
			_check("take: and shoves whoever is standing on the track (%d -> %d)"
				% [_health_mark, _player().health], _player().health < _health_mark)
			_health_mark = _player().health
		REST + LEAD + TAKE + 10:
			_check("rest: the take ends and the room goes cold (%.2f)"
				% _heat(), not _rolling() and _heat() == 0.0)
			# Standing ON the mark for the rest of the rest. The rig is on its
			# way back to exactly this spot and comes to a stop inside the
			# player, which is the hardest version of the promise: a cold rig
			# does not hurt even when it is parked on top of you.
			_player().global_position = _park()
			_player().call("heal", 100)
			_health_mark = _player().health
		REST + LEAD + TAKE + 150:
			_check("rest: the rig is back on its mark before the next take (%s)"
				% _dolly().position, _dolly().position == _park())
			_check("rest: and a rig being pushed back does not hurt, even parked "
				+ "on somebody (%d -> %d)"
				% [_health_mark, _player().health], _player().health == _health_mark)
			_finish()


## The checks that are about how the room is BUILT rather than how it runs.
func _arrive() -> void:
	var studio := _studio()
	_check("clock: the studio floor runs one, found by group",
		studio != null and studio.is_in_group("studio"))
	_check("clock: it carries the floor's authored seconds (%s/%s/%s)"
		% [studio.get("rest"), studio.get("lead"), studio.get("take")],
		is_equal_approx(studio.get("rest"), REST / 60.0)
			and is_equal_approx(studio.get("lead"), LEAD / 60.0)
			and is_equal_approx(studio.get("take"), TAKE / 60.0))

	var lamps := _lamps()
	_check("clock: all five lamps are wired to it (%d)" % lamps.size(),
		lamps.size() == 5)
	# A lamp with no Burn child is furniture that will never hurt anybody, and a
	# Burn with no script is a trigger that does nothing. Both are silent
	# failures the room would look perfectly fine with, so both are counted.
	var bare: Array = lamps.filter(func(n: Node) -> bool:
		var burn := n.get_node_or_null("Burn")
		return burn == null or burn.get_script() == null)
	_check("clock: every one of them carries its own heat (%d bare)"
		% bare.size(), bare.is_empty())

	var rig := _dolly()
	_check("dolly: the rig is in the room", rig != null)
	_check("dolly: parked at the end it starts every take from (%s vs %s)"
		% [rig.position, rig.get("from")], rig.position == _park())
	# The invariant a moving hazard is the first thing that could break. The
	# lane is x 246-300 at every y; a rail that reached it would put a timed
	# threat on the one walk every floor keeps safe.
	var from: Vector2 = rig.get("from")
	var to: Vector2 = rig.get("to")
	_check("dolly: its rail stops short of the door lane (%.0f..%.0f vs %d)"
		% [minf(from.x, to.x), maxf(from.x, to.x), LANE_LEFT],
		maxf(from.x, to.x) < float(LANE_LEFT))
	_check("dolly: and it is slower than a walk (%.0f)" % rig.get("speed"),
		float(rig.get("speed")) < 90.0)
	_check("dolly: the track is painted under it",
		_level().get_node_or_null("Props/Rail1") != null)

	# One cause for health, and one only - see the header.
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	var beats := _level().get_node_or_null("Reinforcements")
	if beats != null:
		beats.queue_free()

	_player().global_position = IN_POOL
	_player().call("heal", 100)
	_health_mark = _player().health


func _studio() -> Node:
	return get_first_node_in_group("studio")


func _dolly() -> Node2D:
	return _level().get_node_or_null("Props/Dolly") as Node2D


func _park() -> Vector2:
	return _dolly().get("from")


func _heat() -> float:
	return float(_studio().call("heat"))


func _rolling() -> bool:
	return bool(_studio().call("rolling"))


func _lamps() -> Array:
	return _level().get_node("Props").get_children().filter(
		func(n: Node) -> bool: return n.name.begins_with("RingLight"))


## How lit the sign is. Read off the sprite's own modulate, which is the one
## thing on_air.gd touches.
func _neon_level() -> float:
	var sign := _level().get_node_or_null("Props/Neon1")
	if sign == null:
		return -1.0
	return (sign.get_node("Sprite2D") as CanvasItem).modulate.r
