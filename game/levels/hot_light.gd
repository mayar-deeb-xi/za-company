extends "res://game/levels/hazard_base.gd"
## The heat coming off a ring light that is rolling. One of these hangs under
## each of the studio's five standing lights, and it is what turns the floor's
## dressing into the floor's threat.
##
## ## The light was always the hazard
##
## This floor's hazard art is a ring light KNOCKED OVER and left at full output,
## and standing beside it are five identical lights still upright. That was the
## joke and it was also the waste: the room said "these things burn" five times
## and meant it once. Nothing new is drawn here - the same lamp, on a clock.
##
## ## The pool is the telegraph and the damage, and they are one number
##
## `_draw()` lays a warm pool on the floor at the light's foot, and its alpha is
## the studio clock's `heat()`: invisible at rest, opening across the cue,
## solid through the take. The area that burns is `$CollisionShape2D`, and the
## pool is measured FROM that shape rather than from a constant - so there is no
## way for a light to draw a footprint it does not burn in, or to burn outside
## one it drew. A hazard whose telegraph is a separate number is a hazard whose
## telegraph goes stale the first time somebody retunes the box.
##
## It is drawn as an ELLIPSE half as tall as it is wide, which is the same
## squash tools/props/markings/rug.gd puts on anything lying flat: the room is
## looked down on at an angle, and a circular pool of light reads as a sphere
## standing up in it.
##
## ## Why it is allowed to draw over the player
##
## The pool sits inside the light's own Y-sorted slot, so a player standing
## NORTH of the lamp's foot has the warm wash drawn over their boots. That is
## not a bug being tolerated - it is what a lamp lying at floor level does to
## somebody standing in front of it, and at the alpha this draws at it reads as
## light falling ON the player rather than as a sprite on top of them.
##
## ## A floor with no clock has five ordinary lamps
##
## `_studio` is found through the `studio` group, and a floor that never asked
## for one simply has nobody in it. Then this draws nothing and burns nothing,
## for ever, with no branch anywhere else in the game - the same deal every
## enemy's missing sound gets. `ring_light` is a catalogue prop and any floor
## may stand one anywhere; only a floor that also runs a clock makes it dangerous.

## The lamp's own colours, lifted from tools/props/fixtures/hazard.gd's fallen
## light. It is deliberately the same three: this IS that lamp, upright, and a
## pool in some other warm would say there are two kinds of light in the room.
const POOL := Color("ffab3d")
const POOL_CORE := Color("ffedc4")

## How much of the floor the pool ever hides, at full heat. Low on purpose -
## the player has to be able to read the tiles, the cable and anybody standing
## in it THROUGH the warning, or the telegraph costs more sight than it buys.
const POOL_ALPHA := 0.42
const CORE_ALPHA := 0.30

var _studio: Node = null
## Half-extents of the box this burns in, read off the collision shape in
## _ready so the drawing and the damage can never disagree.
var _reach := Vector2.ZERO
## What the last redraw was drawn at. The cue ramps every frame and the take
## and the rest do not, so this is what keeps the redraws to the frames that
## would actually look different.
var _drawn := -1.0


func _ready() -> void:
	super()
	_studio = get_tree().get_first_node_in_group("studio")
	var box := get_node_or_null("CollisionShape2D") as CollisionShape2D
	var shape := (box.shape if box != null else null) as RectangleShape2D
	if shape != null:
		_reach = shape.size * 0.5
	# Nothing to read and nothing to draw: this is furniture on this floor.
	set_process(_studio != null)
	set_physics_process(_studio != null)


func _process(_delta: float) -> void:
	if absf(_heat() - _drawn) > 0.01:
		queue_redraw()


## Burns only while a take is ROLLING - never through the cue, which is the
## whole of the promise the pool makes. The base presses damage every physics
## frame and the player's grace window meters it, so a light burns at exactly
## the rate the fallen one does; what differs is that this one stops.
func _physics_process(delta: float) -> void:
	if _studio == null or not bool(_studio.call("rolling")):
		return
	super(delta)


func _draw() -> void:
	_drawn = _heat()
	if _drawn <= 0.01 or _reach == Vector2.ZERO:
		return
	# Scanlines rather than a polygon, like every effect the bosses draw: this
	# is a pixel-art game and a smooth edge on a 640x360 viewport is a blurred
	# one. Each row of the ellipse is one whole-pixel rect.
	_pool(_reach, POOL, POOL_ALPHA * _drawn)
	_pool(_reach * 0.55, POOL_CORE, CORE_ALPHA * _drawn)


func _pool(reach: Vector2, tint: Color, alpha: float) -> void:
	var col := tint
	col.a = alpha
	var rows := int(reach.y)
	for step in range(-rows, rows + 1):
		# Half-width of the ellipse at this row.
		var t := float(step) / maxf(reach.y, 1.0)
		var half := roundf(reach.x * sqrt(maxf(1.0 - t * t, 0.0)))
		if half < 1.0:
			continue
		draw_rect(Rect2(-half, float(step), half * 2.0, 1.0), col)


func _heat() -> float:
	return 0.0 if _studio == null else float(_studio.call("heat"))
