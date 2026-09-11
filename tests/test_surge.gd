extends "res://tests/helpers.gd"
## The call floor's wiring: four runs of trunking, each dull, then flaring, then
## putting something very fast down its length.
##
## Its own suite for the reason test_studio.gd is: a cycle takes 2.4 seconds and
## the interesting checks are two periods apart, which is not a wait to put in
## the middle of test_flow.gd's walk through twelve floors. The room's
## composition - eighteen dividers, the ranks of desks, the five enemies - is
## test_flow.gd's and is not re-checked here.
##
## ## What it is actually asking
##
## The headline is the third check below: **no run reaches the door lane.** A
## surge is the second thing in this game that could threaten x 246-300 without
## ever being PLACED in it, and unlike the dolly there are four of them, so the
## rule is checked against every run rather than against a rig. It is also what
## makes the ARRIVAL safe - a player walks in at (272, 240), on the lane, while
## the first run is already charging.
##
## The other one worth naming is "one pass is one hit". The head crosses a
## standing player in about a tenth of a second against a grace window six times
## that, so a run costs exactly one blow however it catches you. That is the
## whole argument for having four, and it is arithmetic rather than a promise:
## the check reads the node's own scaled `damage` and asserts the drop is
## exactly that, not merely that health fell.
##
## ## Why the room is emptied on arrival
##
## Two slowers, three guards and a jammed copier all reach health, and this
## suite measures health to the point. The three beats go too, and the last two
## are the ones that would be missed: clearing the room is the cue for Ivan,
## who arrives with a heart per head and would HEAL the player in the middle of
## a damage check.

const CALL_CENTER := "res://game/levels/call_center/call_center.tscn"

## The authored cycle, in frames at 60fps. Checked against the scene's own
## exports at +2 so a retune fails with a number rather than as six mysteries.
const PERIOD := 144      # 2.4s
const CHARGE := 30       # 0.5s
## 208 px at 260 px/s.
const TRAVEL := 48

## The lane every floor keeps walkable, top to bottom.
const LANE := Vector2(246, 300)

## On the first run's line, west of the door lane and clear of the copier at
## (120, 152), of the dividers' feet at y 80/160 and of every desk. The head
## reaches it a little over half way along.
const ON_LINE := Vector2(128, 128)

var _t0 := 0
var _damage := 0


func _tick(frame: int) -> void:
	if _t0 == 0:
		_lobby(frame)
		if _runs().size() > 0:
			_t0 = frame
		return
	_call_floor(frame - _t0)


func _lobby(frame: int) -> void:
	match frame:
		2:
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		17:
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
		32:
			_level().get_node("Props/Exit").travelled.emit(CALL_CENTER, &"start")


func _call_floor(at: int) -> void:
	match at:
		2:
			_arrive()
		CHARGE - 8:
			# Flaring end to end, and that is all it is doing. The charge is the
			# whole of what makes four of these fair rather than four things
			# that hit you from off-screen.
			_check("charge: the line is warning, not firing (phase %d)"
				% _phase(0), _phase(0) == 1)
			_check("charge: and a warning costs nothing (%d -> %d)"
				% [_health_mark, _player().health],
				_player().health == _health_mark)
		CHARGE + 6:
			_check("run: the charge lands on a run (phase %d)" % _phase(0),
				_phase(0) == 2)
			_check("run: the head has left the near end (%.0f px along)"
				% _head(0).x, _head(0).x > 4.0)
			_check("run: and has not reached the player yet (%d -> %d)"
				% [_health_mark, _player().health],
				_player().health == _health_mark)
		CHARGE + TRAVEL - 4:
			_check("run: the head reached whoever was standing on the line "
				+ "(%d -> %d)" % [_health_mark, _player().health],
				_player().health == _health_mark - _damage)
		CHARGE + TRAVEL + 30:
			# Past, and gone. A surge is a tax on crossing at the wrong moment,
			# never a lane you can be held inside - so the SECOND hit this
			# would have landed is the one that must not exist.
			_check("run: one pass is exactly one hit (%d, expected %d)"
				% [_player().health, _health_mark - _damage],
				_player().health == _health_mark - _damage)
			_check("wait: the line goes dull again (phase %d)" % _phase(0),
				_phase(0) == 0)
			_check("wait: and the head parks off the run (%.0f px along)"
				% _head(0).x, _head(0).x < 0.0)
			# Nothing fires as one. Checked as the four authored offsets rather
			# than as four live phases, because two runs DO overlap by design -
			# what must not happen is two of them being the same line of data.
			var offsets: Array = _runs().map(
				func(n: Node) -> float: return float(n.get("after")))
			var distinct := {}
			for o: float in offsets:
				distinct[o] = true
			_check("stagger: the four runs are spread across the cycle (%s)"
				% [offsets], distinct.size() == _runs().size())
		PERIOD + CHARGE + TRAVEL - 4:
			# A whole cycle later the same line goes again. This is the check
			# that says it is a rhythm rather than something that happened once.
			_check("cycle: it comes round again (%d, expected %d)"
				% [_player().health, _health_mark - 2 * _damage],
				_player().health == _health_mark - 2 * _damage)
			_finish()


## The checks about how the floor is WIRED rather than how it fires.
func _arrive() -> void:
	var runs := _runs()
	_check("wiring: the call floor is wired, in four runs (%d)" % runs.size(),
		runs.size() == 4)

	# The rule. Every run, both ends, against the lane every floor keeps.
	var across: Array = runs.filter(func(n: Node) -> bool:
		var a: Vector2 = n.get("from")
		var b: Vector2 = n.get("to")
		return maxf(a.x, b.x) > LANE.x and minf(a.x, b.x) < LANE.y)
	_check("wiring: no run reaches the door lane (%d of %d cross it)"
		% [across.size(), runs.size()], across.is_empty())

	var first := runs[0] as Node2D
	_check("wiring: it carries the floor's authored cycle (%.2f/%.2f)"
		% [first.get("period"), first.get("charge")],
		is_equal_approx(first.get("period"), PERIOD / 60.0)
			and is_equal_approx(first.get("charge"), CHARGE / 60.0))
	# The conduit is part of the building and takes the building's metal; only
	# what FIRES is fixed white and gold. A conduit that came out bright would
	# mean the two had been confused, and the lane would read as live all the
	# time.
	var conduit: Color = first.get("conduit")
	_check("wiring: the conduit is the room's own metal, not a spark (%.2f)"
		% conduit.get_luminance(), conduit.get_luminance() < 0.3)
	_check("wiring: every run has a head to hurt with",
		runs.all(func(n: Node) -> bool:
			return n.get_node_or_null("CollisionShape2D") != null))
	# It draws itself, so it is the one hazard in the game with no picture.
	_check("wiring: and no art file to go stale",
		first.get_node_or_null("Sprite2D") == null)

	# One cause for health, and one only - see the header. The last two are the
	# ones that matter: a cleared room is Ivan's cue, and Ivan heals.
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	for beat: String in ["Reinforcements", "Relief", "Briefing"]:
		var node := _level().get_node_or_null(beat)
		if node != null:
			node.queue_free()

	_player().global_position = ON_LINE
	_player().call("heal", 100)
	_health_mark = _player().health
	_damage = int(first.get("damage"))


func _runs() -> Array:
	var level := _level()
	if level == null:
		return []
	return level.get_node("Props").get_children().filter(
		func(n: Node) -> bool: return n.name.begins_with("Surge"))


## A run's phase, as surge.gd's enum: 0 waiting, 1 charging, 2 running.
func _phase(i: int) -> int:
	return int((_runs()[i] as Node).get("_phase"))


## Where that run's head is, relative to the run's near end. Read off the
## collision shape rather than off any number the script keeps, because the
## shape IS the thing that hurts.
func _head(i: int) -> Vector2:
	var run := _runs()[i] as Node2D
	return (run.get_node("CollisionShape2D") as Node2D).position
