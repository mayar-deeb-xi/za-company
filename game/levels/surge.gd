extends "res://game/levels/hazard_base.gd"
## A short running the cable trunking: the conduit lies on the floor doing
## nothing, then the whole run lights up, then something very bright and very
## fast goes down it. One node is one run. A floor gets several.
##
## ## What it is for, and why it is not the dolly again
##
## The studio's rig is ONE slow heavy thing crossing a room, and what it asks of
## the player is patience - you watch it, you wait, you go. The call floor's
## lesson is the opposite one: this is the denial floor, where two slowers and
## three guards mean the thing being taken away from you is your movement, and
## the room needs a threat that punishes being slow rather than one that
## rewards waiting. So a surge is small, fast, frequent and there are four of
## them, staggered, so something in the room is always going off.
##
## The two are deliberately the same shape underneath - a hazard that moves
## along an authored segment, cued by a visible telegraph - and deliberately
## nothing like each other to play against. 78 px/s and one rig is furniture
## with a schedule. 260 px/s and four lines is a floor you cross between beats.
##
## ## It draws its own trunking, and that is the point
##
## The studio's rail is a painted marking authored to match the dolly's two
## ends, with nothing checking that the pair agrees - survivable for one rig and
## a liability for six runs. This draws the conduit AND the spark from the same
## two points, so the lane the player reads and the lane that hurts cannot come
## apart. It is the first thing in this game that hurts you and has no art file
## at all.
##
## The conduit takes the room's own metal, handed in by the generator, because
## it is a piece of the building. Everything that FIRES is fixed white and gold,
## the same rule that fixes fire, sparks and the heart: a hazard that took the
## room's palette would camouflage itself in it, and this one has 0.8 seconds to
## be understood.
##
## ## The three phases, and why the middle one is not optional
##
##   WAIT    the conduit is dull. Nothing is going to happen for a while.
##   CHARGE  the WHOLE run lights and stutters. Nothing hurts yet.
##   RUN     the head goes, end to end, and it hurts.
##
## Charging the entire line rather than warning at one end is the whole trick: a
## player standing anywhere along a run finds out that THIS run is the one going
## off, without having to work out which direction it comes from or how long
## they have. It is the studio clock's cue phase argued from the other side -
## there the room warms and the danger is a place, here the lane flares and the
## danger is a moment.
##
## ## One surge is one hit
##
## The head crosses a standing player in about a tenth of a second, and the
## player's grace window is more than six times that, so a run costs exactly one
## blow no matter how it catches you. That is deliberate and it is what makes
## four of these fair: they are a tax on crossing at the wrong moment, never a
## grinder you can be trapped inside. It is also why the damage is below the
## copier's - the copier is one place you chose to stand in, and these are four
## lanes you have to cross.

## Fixed, like every spark in this game. Lifted off
## tools/props/fixtures/hazard.gd so the fault reads as the same electricity the
## jammed copier throws.
const CORE := Color("fff8e0")
const BODY := Color("ffd45e")
const EDGE := Color("ff8a3c")

## Where the head is drawn, in whole pixels: a core, a warm cross, and the
## branches that jump off it. Spelled out rather than computed because at this
## size a spark is a specific eight pixels, exactly as the polisher's scatter is.
const HALO: Array[Vector2i] = [
	Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -2), Vector2i(0, 2),
	Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
]

## How long the tail behind the head is, in pixels. Long enough to say which way
## the thing is travelling in a single frame, which is the one piece of
## information a player needs and cannot get from a dot.
const TAIL := 22

## Authored per run in the floor's `surge` key - see tools/biomes/call_center.gd.
@export var from := Vector2.ZERO
@export var to := Vector2.ZERO
## Pixels per second. Fast on purpose: this is a short, not a vehicle.
@export var speed := 260.0
## The whole cycle, charge and run included.
@export var period := 2.4
## How long the line flares before it fires.
@export var charge := 0.5
## This run's offset into the cycle. It is what keeps four lines from firing as
## one, and it is the only per-run number that is not geometry.
@export var after := 0.0
## The room's own metal, handed in by build_levels.gd. The conduit is part of
## the building; only what fires is fixed.
@export var conduit := Color("3e4a3c")

enum { WAIT, CHARGE, RUN }

var _phase := WAIT
var _elapsed := 0.0
## 0 to 1 along the run. Only meaningful while firing.
var _along := 0.0
var _travel := 0.0
var _shape: CollisionShape2D = null


func _ready() -> void:
	super()
	_travel = from.distance_to(to) / maxf(speed, 1.0)
	# A cycle shorter than the thing it has to fit is a line that is always
	# firing, which is not a hazard, it is a wall. Widened rather than rejected:
	# the authored numbers are a floor's to tune and this only catches a typo.
	period = maxf(period, charge + _travel + 0.2)
	_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	position = from
	_park()


func _process(delta: float) -> void:
	_elapsed += delta
	# Subtracted, so `after` genuinely delays: a run authored at 0.6 charges
	# six tenths of a second later than one authored at 0.
	var t := fposmod(_elapsed - after, period)
	var was := _phase
	if t < charge:
		_phase = CHARGE
		_park()
	elif t < charge + _travel:
		_phase = RUN
		_along = (t - charge) / maxf(_travel, 0.001)
		if _shape != null:
			_shape.position = (to - from) * _along
	else:
		_phase = WAIT
		_park()
	# The charge stutters and the head moves, so both of those redraw every
	# frame; a waiting line is a static dull conduit and redraws only as it
	# becomes one.
	if _phase != WAIT or was != WAIT:
		queue_redraw()


## Hurts only while the head is actually running. A charging line is the
## promise, not the blow - see the header.
func _physics_process(delta: float) -> void:
	if _phase != RUN:
		return
	super(delta)


## The collision shape off the end of the run, where nothing stands. Parking it
## rather than switching `monitoring` keeps one thing true: the box is always
## exactly where the head is drawn, and the head is nowhere between runs.
func _park() -> void:
	if _shape != null:
		_shape.position = from - to


func _draw() -> void:
	var span := to - from
	var along := span.normalized()
	# The conduit itself, always. Two courses, the far one darker, which is the
	# same light direction everything else in the room is drawn with.
	var thick := Vector2(-along.y, along.x)
	draw_line(Vector2.ZERO, span, conduit.darkened(0.35), 1.0)
	draw_line(thick, span + thick, conduit, 2.0)
	# Junction boxes, so a line has two ends rather than running off the map.
	for at: Vector2 in [Vector2.ZERO, span]:
		draw_rect(Rect2(at - Vector2(2, 2), Vector2(5, 5)), conduit, true)
		draw_rect(Rect2(at - Vector2(2, 2), Vector2(5, 5)),
			conduit.darkened(0.5), false, 1.0)

	if _phase == CHARGE:
		_draw_charge(span)
	elif _phase == RUN:
		_draw_head(span, along)


## The whole run lights and stutters. Drawn along the conduit rather than as a
## glow around it, so what the player sees lighting up is exactly the strip that
## is about to be dangerous.
func _draw_charge(span: Vector2) -> void:
	var lit := BODY
	# Stutters between two alphas frame to frame. A steady glow reads as a lamp
	# switching on; an unsteady one reads as something wrong with the wiring.
	lit.a = 0.35 + 0.35 * randf()
	draw_line(Vector2.ZERO, span, lit, 2.0)
	# A few sparks already jumping at random points along it, which is what
	# says the charge is IN the line rather than painted on it.
	for _i in 3:
		var at: Vector2 = span * randf()
		draw_rect(Rect2(at.round() - Vector2.ONE, Vector2(2, 2)), CORE, true)


## The head, its tail, and the branches coming off it.
func _draw_head(span: Vector2, along: Vector2) -> void:
	var at: Vector2 = (span * _along).round()
	# The tail, drawn back up the run and fading out. Whole-pixel rects rather
	# than a gradient line, like every effect the bosses draw.
	var steps := TAIL / 2
	for step in range(1, steps):
		var back: Vector2 = (at - along * float(step * 2)).round()
		var fade := EDGE
		fade.a = 0.7 * (1.0 - float(step) / float(steps))
		draw_rect(Rect2(back, Vector2(2, 2)), fade, true)
	# The branches: two short jagged arcs jumping off the head, sideways and
	# jittered, redrawn every frame. This is the whole of what makes it read as
	# electrical rather than as a bullet.
	var side := Vector2(-along.y, along.x)
	for way: float in [1.0, -1.0]:
		var tip: Vector2 = at
		for step in 3:
			tip += (side * way * (1.0 + randf() * 2.0)
				- along * (randf() * 2.0 - 1.0))
			draw_rect(Rect2(tip.round(), Vector2(1, 1)), BODY, true)
	# The head last, so nothing is drawn over it: a warm cross around a white
	# core, which is how every spark in this game is built.
	for step: Vector2i in HALO:
		draw_rect(Rect2(at + Vector2(step), Vector2(1, 1)), BODY, true)
	draw_rect(Rect2(at - Vector2.ONE, Vector2(3, 3)), CORE, true)
