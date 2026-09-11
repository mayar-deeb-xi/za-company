extends CharacterBody2D
## A floor scrubber left running: a low, heavy, autonomous machine trundling
## around the hub, turning whenever it hits something, and shoving whoever it
## walks into.
##
## ## The third shape, and the only one with no path
##
## The studio's dolly runs a rail and the call floor's surges run four fixed
## lines, so both are learned as GEOMETRY - you find out where the danger is and
## then you time it. That is two floors teaching the same kind of lesson, and a
## third fixed path would have been the same lesson again. This one has no path
## at all:
##
##   F2 dolly     one fixed rail    -> patience. Watch it, wait, go.
##   F3 surge     four fixed lines  -> timing. Cross between beats.
##   F5 scrubber  nothing authored  -> awareness. You cannot learn where it is.
##
## And the randomness is not a mechanic bolted onto an office prop; it is what
## these machines actually do, the same way the dolly is an actual camera dolly.
## Nothing about where it goes is authored: it picks a heading, runs until the
## room stops it, and picks another. **The cubicle dividers, the desks and the
## glass office walls are what decide its route**, which is the whole reason it
## belongs on this floor rather than any other - the hub is the room with two
## completely different interiors, so the same machine behaves unlike itself in
## each half.
##
## ## It takes your POSITION, not your health
##
## The other two hazards on this floor's neighbours burn. This one bumps: a low
## `damage` and a real `shove()`, which is the fourth way anything in this game
## reaches the player (game/player/CLAUDE.md). On a floor whose two drain fields
## sit inside the glass offices and whose power strip sits in the middle
## corridor, being moved three feet is worth more than the six points.
##
## It is a solid body rather than an area, which is the other half of being an
## obstacle: it is in the way even when it is standing still, and the player can
## be cornered by one the way they can be cornered by furniture that moves.
##
## ## Why it cannot pin anybody
##
## The failure mode of a wandering solid is a machine that traps you against a
## wall and grinds. It cannot, because **a bump always ends in a turn AWAY from
## whatever was bumped**: the new heading is the old one reflected off the
## contact normal, and the player is a contact like any other. It backs off by
## construction rather than by a rule about players.
##
## ## Random, but penned
##
## `within` is the rectangle it may not leave. That is what keeps the door lane
## walkable on a floor whose hazard has no route to inspect: the dolly and the
## surges keep x 246-300 clear by being authored to stop short of it, and a
## wanderer keeps it clear by being fenced out of it. It is also what makes the
## hub's two halves stay two halves - one machine each, neither able to cross
## into the other's furniture.
##
## ## The turn is the telegraph
##
## A bump does not snap the heading round. The machine STOPS, swings its scanner
## to where it has decided to go, and only then drives off - which is both what
## one of these actually does and the only warning a random thing can honestly
## give. You cannot be told where it will be in three seconds; you can always be
## told where it is about to go next.

## The scanner, and it is deliberately COLD. Every hazard in this game that
## takes health is warm - fire, sparks, a lamp at full output - so the one that
## takes position instead reads in the other direction, and the player learns a
## rule rather than a list: warm burns, cold moves you. Fixed rather than taken
## from the room's accent, on the same argument that fixes the flame: a machine
## that borrowed the carpet's colour would be a machine you walk into.
const SCAN := Color("bff4ff")
const SCAN_DIM := Color("5c9fb8")

## How far the scanner reaches out of the shell, in pixels.
const SCAN_REACH := 9.0

## Authored per machine in the floor's `scrubbers` key.
@export var within := Rect2()
## Pixels per second. Under the player's 90, like the dolly and for the same
## reason: it can herd you and it can corner you, and it can never run you down.
@export var speed := 60.0
## What a bump costs in health - little. The push is the point.
@export var damage := 6
## And in position. Capped again by the player at MAX_SHOVE.
@export var push := 70.0
## How long it sits still after a bump, deciding. The telegraph.
@export var turn_seconds := 0.45

enum { ROLL, TURN }

var _state := ROLL
var _heading := Vector2.RIGHT
## Where the scanner is pointing. Follows `_heading` while rolling and leads it
## while turning, which is what makes a turn readable before it happens.
var _aim := Vector2.RIGHT
var _next := Vector2.RIGHT
var _left := 0.0
var _hurt := 0


func _ready() -> void:
	# Per mode, at spawn, exactly like every other thing the world deals -
	# levels are re-instantiated per entry so a new run rescales cleanly. The
	# PUSH is deliberately not scaled: difficulty changes what being hit costs,
	# and being moved is the same distance for everybody.
	_hurt = roundi(damage * Difficulty.damage_scale())
	# A pen that was never authored is the whole room, which is survivable
	# rather than correct - it would let the machine onto the door lane. The
	# warning is what gets somebody to write one.
	if within.size == Vector2.ZERO:
		push_warning("%s has no `within` pen and may wander the door lane"
			% name)
	_heading = Vector2.RIGHT.rotated(randf() * TAU)
	_aim = _heading
	_next = _heading


func _physics_process(delta: float) -> void:
	if _state == TURN:
		velocity = Vector2.ZERO
		_left -= delta
		# The scanner swings across during the wait, so the new heading is
		# readable for the whole of it rather than announced at the end.
		_aim = _aim.slerp(_next, clampf(delta / maxf(_left, 0.001), 0.0, 1.0))
		if _left <= 0.0:
			_heading = _next
			_aim = _next
			_state = ROLL
		queue_redraw()
		return

	velocity = _heading * speed
	move_and_slide()
	_aim = _heading
	queue_redraw()

	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		_shove_anybody(hit.get_collider())
		_turn_from(hit.get_normal())
		return
	_keep_penned()


## Whatever it just walked into gets moved, if it is the kind of thing that can
## be. Reached by group and `has_method` like everything else in this game -
## the machine has no idea what a player is.
func _shove_anybody(body: Object) -> void:
	if body == null or not (body as Node).is_in_group("player"):
		return
	var who := body as Node2D
	# Pushed away from the MACHINE rather than along its heading: what a person
	# feels when something heavy catches them is a shove out of its way, and at
	# a glancing contact the two directions are nothing like each other.
	if who.has_method("shove"):
		who.call("shove", who.global_position - global_position, push)
	if who.has_method("take_damage"):
		who.call("take_damage", _hurt)


## Turns off a surface: reflect, then scatter. The reflection is what stops it
## driving back into the thing it just hit; the scatter is what stops two
## machines in one room ever settling into a pattern, which is the failure a
## purely physical bounce has - a rectangle bounced around a rectangular room
## finds a loop and runs it forever.
func _turn_from(normal: Vector2) -> void:
	var away := _heading.bounce(normal).rotated(randf_range(-0.7, 0.7))
	# A scatter wide enough to be worth having is wide enough to point the
	# machine back at the wall, so the result is checked rather than trusted.
	if away.dot(normal) < 0.15:
		away = normal.rotated(randf_range(-0.7, 0.7))
	_next = away.normalized()
	_state = TURN
	_left = turn_seconds


## The pen. Checked after the move rather than before it, so the machine is
## turned by its fence exactly the way it is turned by a wall - and put back
## inside first, because a fence it can be standing outside of is not a fence.
func _keep_penned() -> void:
	if within.size == Vector2.ZERO or within.has_point(global_position):
		return
	var inside := global_position.clamp(within.position, within.end)
	var normal := (inside - global_position).normalized()
	global_position = inside
	if normal != Vector2.ZERO:
		_turn_from(normal)


## The scanner sweeping out of the shell. Drawn rather than baked because it is
## the one part of the machine that MOVES independently of it - the shell is the
## same picture at every angle, which is most of why this hazard is a disc.
func _draw() -> void:
	var tip := _aim * SCAN_REACH
	# Two courses: a dim wash the width of the sweep, and the bright line down
	# the middle of it. Whole pixels, like every effect in this game.
	for step in [-0.35, 0.35]:
		var side := _aim.rotated(step) * (SCAN_REACH - 2.0)
		draw_line(Vector2(0, -6), Vector2(side.x, side.y - 6), SCAN_DIM, 1.0)
	draw_line(Vector2(0, -6), Vector2(tip.x, tip.y - 6), SCAN, 1.0)
	# The lamp itself, on top of the shell, brighter while it is deciding.
	draw_rect(Rect2(-1, -8, 2, 2), SCAN if _state == TURN else SCAN_DIM, true)
