extends "res://tests/helpers.gd"
## The hub's floor scrubbers, and the fourth way the world reaches the player.
##
## Its own suite because what is under test is BEHAVIOUR OVER TIME with no
## authored route to check against. The dolly is at a known place on a known
## frame and the surge fires on a cycle; a wanderer is at none of those, so
## every check here is a property rather than a position - it stayed in its pen,
## it visited more than one place, it turned when it hit something, it pushed
## whoever it walked into.
##
## ## Randomness is exactly what makes the checks weaker, so they are chosen
##
## A test that watched one machine for one run and asserted where it ended up
## would pass or fail on a seed. The three that carry weight are the ones that
## must hold for EVERY seed:
##
## - **the pen**, sampled every frame for hundreds of frames. It is what keeps
##   the door lane walkable on a floor whose hazard has no route to inspect, so
##   it is the one thing here that is a rule rather than a tendency.
## - **it actually moves**, and to more than one place. A machine wedged in a
##   corner on frame ten passes a pen check perfectly.
## - **the shove**, driven rather than waited for: the player is put in front of
##   a machine on purpose instead of standing about hoping to be found.
##
## ## Why the room is left alone this time
##
## Unlike the studio and the call floor, the enemies stay: the machines have to
## bounce off SOMETHING, and a room stripped of everything that stops them is
## not the room they were tuned in. What is cleared is only what would touch
## health during the shove check, and that is done by parking the player away
## from all of it rather than by deleting anybody.

const HUB := "res://game/levels/the_hub/the_hub.tscn"

## Long enough that a machine has bounced many times over, at 60fps.
const WATCH := 420

## Somewhere in the east half with nothing standing in it: the corridor between
## the two glass bays, clear of both offices' drains and of the power strip
## across on the call side.
const CLEAR_SPOT := Vector2(392, 160)
## The door lane, which neither pen may reach - so it is the one place in the
## room where a machine provably cannot interfere with a measurement.
const ON_THE_LANE := Vector2(272, 200)
## Where the staged bump happens: open carpet in the corridor between the two
## glass bays, inside the east machine's pen, and outside every drain in the
## room - 146 px from the south office's 120 px reach, which is what makes the
## health check below measure the machine and nothing else.
const BUMP_SPOT := Vector2(355, 150)

var _t0 := 0
var _seen: Array[Vector2] = []
var _escapes := 0
var _one_push := 0.0
var _knocked := 0.0


func _tick(frame: int) -> void:
	if _t0 == 0:
		_lobby(frame)
		if _bots().size() > 0:
			_t0 = frame
		return
	_hub(frame - _t0)


func _lobby(frame: int) -> void:
	match frame:
		2:
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		17:
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
		32:
			_level().get_node("Props/Exit").travelled.emit(HUB, &"start")


func _hub(at: int) -> void:
	# Every frame of the watch: the pen is a rule, so it is checked as one.
	if at > 2 and at <= WATCH:
		for bot: Node2D in _bots():
			var pen: Rect2 = bot.get("within")
			if not pen.grow(2.0).has_point(bot.global_position):
				_escapes += 1
			if _seen.is_empty() or _seen[-1].distance_to(bot.global_position) > 24.0:
				_seen.append(bot.global_position)
	# The staged bump, sampled as a PEAK rather than read off one frame. A
	# machine that shoves the player and then trundles back into them can put
	# them near where they started, so "how far were they pushed" is the
	# furthest they got, not where they happen to be when the check runs.
	if at > WATCH and at <= WATCH + 50:
		_knocked = maxf(_knocked, _player().global_position.distance_to(_mark))

	match at:
		2:
			_arrive()
		WATCH:
			_check("pen: neither machine left its rectangle in %d frames (%d escapes)"
				% [WATCH, _escapes], _escapes == 0)
			# A machine wedged against a desk would pass the pen check perfectly,
			# so being somewhere ELSE repeatedly is its own question.
			_check("wander: they covered ground rather than sitting still (%d marks)"
				% _seen.size(), _seen.size() >= 6)
			# The point of the pen, stated as the rule it exists for.
			var lane := 0
			for mark: Vector2 in _seen:
				if mark.x > 246.0 and mark.x < 300.0:
					lane += 1
			_check("pen: and neither of them was ever on the door lane (%d of %d)"
				% [lane, _seen.size()], lane == 0)
			# THE BUMP, staged rather than waited for. Standing the player near
			# a machine and watching for ninety frames is a check that passes or
			# fails on a seed - it might turn away, it might catch them twice
			# and put them back where they started. So the machine is aimed:
			# both are placed in known open floor inside the east pen, close
			# enough to touch within a frame or two, and the machine is pointed
			# at the player and set rolling. Starting them far apart was tried
			# and is what made this check flaky: the contact frame then depends
			# on the travel, and a shove measured from too late in its own decay
			# is a shove that looks like it barely happened.
			_player().global_position = BUMP_SPOT
			_player().call("heal", 100)
			_health_mark = _player().health
			_mark = _player().global_position
			var bot := _bots()[1] as Node2D
			bot.global_position = BUMP_SPOT - Vector2(18, 0)
			bot.set("_heading", Vector2.RIGHT)
			bot.set("_aim", Vector2.RIGHT)
			bot.set("_state", 0)
			bot.set("_left", 0.0)
		WATCH + 50:
			# Fifty frames is well past both the contact and the shove's own
			# half-second decay, so the peak below is the whole push. A bump
			# costs health AND position, and the pair is the point: this is the
			# only hazard in the game that moves you, and a version of it that
			# only took health would be a torch that walks.
			_check("bump: it walks into the player and hurts them (%d -> %d)"
				% [_health_mark, _player().health],
				_player().health < _health_mark)
			_check("bump: and pushes them out of its way (%.1f px)" % _knocked,
				_knocked > 6.0)
		WATCH + 95:
			# Onto the door lane for the rest of it. Every check below is about
			# the PUSH rather than about a machine, and a wanderer blundering
			# into the middle of one would measure two things at once - so the
			# player goes to the one strip of floor neither pen can reach, which
			# is the rule under test doing a favour to the test.
			_player().global_position = ON_THE_LANE
			_player().call("heal", 100)
		WATCH + 100:
			_mark = _player().global_position
			_shove_directly()
		WATCH + 104:
			_one_push = _player().global_position.distance_to(_mark)
			_check("shove: a push moves the player who was standing still (%.1f px)"
				% _one_push, _one_push > 2.0)
		WATCH + 125:
			# Well past SHOVE_SECONDS, so whatever is happening now is not the
			# push any more.
			_mark = _player().global_position
		WATCH + 145:
			# It expires on its own, like a slow and unlike a blow. If it did
			# not, the player would still be travelling a second later.
			var drift := _player().global_position.distance_to(_mark)
			_check("shove: and it wears off rather than carrying on (%.1f px)"
				% drift, drift < 2.0)
			_health_mark = _player().health
			_mark = _player().global_position
			_shove_directly()
			_shove_directly()
			_shove_directly()
		WATCH + 149:
			# Shoves REFRESH, they do not compound - the rule a slow already
			# keeps. Measured against ONE push over the same four frames rather
			# than against a number typed here, so it stays true if the force is
			# ever retuned. It is also the guarantee that nothing can be posted
			# through a wall: three machines cannot add up to a launch.
			var three := _player().global_position.distance_to(_mark)
			_check("shove: three at once move you no further than one "
				+ "(%.1f px vs %.1f)" % [three, _one_push],
				three < _one_push * 1.5)
			_check("shove: and a push on its own costs no health (%d -> %d)"
				% [_health_mark, _player().health],
				_player().health == _health_mark)
			_finish()


func _arrive() -> void:
	var bots := _bots()
	_check("hub: two machines, one per half (%d)" % bots.size(),
		bots.size() == 2)
	_check("hub: they are solid bodies, not triggers",
		bots.all(func(n: Node) -> bool: return n is CharacterBody2D))
	# The rule the pen exists for, checked on the DATA as well as on the walk
	# above - a pen that overlapped the lane would only sometimes show up as a
	# machine standing on it.
	var trespass: Array = bots.filter(func(n: Node) -> bool:
		var pen: Rect2 = n.get("within")
		return pen.position.x < 300.0 and pen.end.x > 246.0)
	_check("pen: no pen overlaps the door lane (%d of %d)"
		% [trespass.size(), bots.size()], trespass.is_empty())
	# One per half, which is what keeps the two halves two halves.
	_check("pen: one is penned west and one east (%.0f | %.0f)"
		% [(bots[0].get("within") as Rect2).end.x,
			(bots[1].get("within") as Rect2).position.x],
		(bots[0].get("within") as Rect2).end.x <= 246.0
			and (bots[1].get("within") as Rect2).position.x >= 300.0)
	_check("hub: and they are slower than a walk (%.0f)" % bots[0].get("speed"),
		float(bots[0].get("speed")) < 90.0)
	# The player has to have grown a fourth way to be reached, or none of the
	# rest of this floor works.
	_check("player: carries a shove", _player().has_method("shove"))

	_player().global_position = CLEAR_SPOT
	_player().call("heal", 100)
	_health_mark = _player().health


## A shove straight from the test, with no machine involved: the push is the
## player's API and is worth checking on its own terms, away from whatever a
## random machine happens to be doing.
func _shove_directly() -> void:
	_player().call("shove", Vector2.DOWN, 70.0)


func _bots() -> Array:
	var level := _level()
	if level == null:
		return []
	return level.get_node("Props").get_children().filter(
		func(n: Node) -> bool: return n.name.begins_with("Scrubber"))
