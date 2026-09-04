extends Node2D
## The warden's area, drawn rather than animated.
##
## What has to be visible here is 48 px of floor - six times the width of the
## body - and no animation on a 32 px sprite can say where that ends. So the
## area draws itself, the same way the HUD's hearts and the biome's columns do:
## it is a shape with a value in it, not art, and it has to stay in step with a
## number.
##
## Two questions, one element. The faint outline is always there, so the zone
## can be routed around BEFORE stepping into it - which is the whole point of an
## area-denial enemy. The arc sweeping round that outline is the wind-up
## filling, so the two seconds can be seen running out and walked out of.
##
## It never carries the radius itself: warden.gd copies in the Touch shape's own
## radius and offset on _ready, so retuning the area in the editor moves the
## ring with it and the drawing can never lie about the reach.

## Matches warden.gd's CHARGE_TINT - the body tinting violet and the ring
## filling violet are one telegraph, not two.
const RING := Color(0.55, 0.45, 1.0)
## The outline dormant, and at the moment the effect lands. Faint at rest so a
## warden across the room marks its ground without shouting.
const IDLE_ALPHA := 0.20
const CHARGED_ALPHA := 0.60
## The wash inside the circle. Deliberately weak even when full - it has to read
## as ground that is claimed, not as a wall.
const FILL_IDLE_ALPHA := 0.05
const FILL_CHARGED_ALPHA := 0.18
## The sweep hand itself, which is the part actually being read.
const SWEEP_ALPHA := 0.95
const SWEEP_WIDTH := 2.0

const FLASH_COLOR := Color(0.85, 0.80, 1.0)
const FLASH_SECONDS := 0.28

const SEGMENTS := 72

@export var radius := 48.0

var progress := 0.0
var _flash := 0.0


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	if _flash <= 0.0:
		set_process(false)
	queue_redraw()


## Where the wind-up is, 0..1. Redraws only when it actually moved, so a dormant
## warden costs nothing.
func set_progress(value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	if is_equal_approx(value, progress):
		return
	progress = value
	queue_redraw()


## The effect landing. Everything in the circle was just slowed, so the circle
## says so - and it is the one moment the ring is allowed to be loud.
func flash() -> void:
	_flash = FLASH_SECONDS
	set_process(true)
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius,
		Color(RING, lerpf(FILL_IDLE_ALPHA, FILL_CHARGED_ALPHA, progress)))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, SEGMENTS,
		Color(RING, lerpf(IDLE_ALPHA, CHARGED_ALPHA, progress)), 1.0)
	if progress > 0.0:
		# From the top and clockwise, the way a clock is read.
		var start := -PI / 2.0
		draw_arc(Vector2.ZERO, radius, start, start + progress * TAU, SEGMENTS,
			Color(RING, SWEEP_ALPHA), SWEEP_WIDTH)
	if _flash > 0.0:
		var t := _flash / FLASH_SECONDS
		draw_circle(Vector2.ZERO, radius, Color(FLASH_COLOR, 0.30 * t))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, SEGMENTS,
			Color(FLASH_COLOR, t), SWEEP_WIDTH)
