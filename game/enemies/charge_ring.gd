extends Node2D
## The warden's area, drawn rather than animated.
##
## What has to be visible here is 48 px of floor - six times the width of the
## body - and no animation on a 32 px sprite can say where that ends. So the
## area draws itself, the same way the HUD's hearts and the biome's columns do:
## it is a shape with a value in it, not art, and it has to stay in step with a
## number.
##
## Two questions, one shape. A dashed rim is always there, so the zone can be
## routed around BEFORE stepping into it - the whole point of an area-denial
## enemy. Inside it, a frosted disc grows out from the warden's feet as the
## wind-up fills and reaches the rim exactly as the slow lands, so how far the
## area reaches and how long is left are read off one thing: standing inside
## the frost means you are already too slow to leave. Past the commit point the
## disc's edge blinks white, and when the effect lands the whole area ices over
## and thaws in step with the four seconds the player is slowed.
##
## The pixels themselves are `charge_ring.gdshader`, so every edge is a hard
## pixel edge at 1x; this script owns the numbers and hands them over as
## uniforms. It never carries the radius itself: warden.gd copies in the Touch
## shape's own radius and offset on _ready, so retuning the area in the editor
## moves the field with it and the drawing can never lie about the reach.
##
## Draw order is the thing to get right, and it was got wrong once: the level's
## Floor tilemap sits at z 0, so a child of the warden with a negative z_index
## draws UNDER the floor and is never seen. This node stays at z 0 and is the
## warden's first child, above the tiles and beneath the body.

const SHADER := preload("res://game/enemies/charge_ring.gdshader")

## How long the landing flash and shards take; the field keeps animating for at
## least this long after `land()` even when the slow itself is short.
const LAND_SECONDS := 0.45
## The frost is full until this much of the slow is left, then thaws out.
const THAW_SECONDS := 1.5

## Declared before `radius` so its setter can reach it.
var _material := ShaderMaterial.new()

## Set by warden.gd from the Touch shape after this node's _ready, so it has to
## reach the shader whenever it changes, not only once at start.
@export var radius := 48.0:
	set(value):
		radius = value
		_material.set_shader_parameter("radius", radius)
		queue_redraw()

var progress := 0.0
var _since_land := -1.0
var _slow_left := 0.0
var _time := 0.0


func _ready() -> void:
	_material.shader = SHADER
	material = _material
	_material.set_shader_parameter("radius", radius)
	set_process(false)


func _process(delta: float) -> void:
	_time += delta
	if _since_land >= 0.0:
		_since_land += delta
		_slow_left = maxf(_slow_left - delta, 0.0)
		if _slow_left <= 0.0 and _since_land >= LAND_SECONDS:
			_since_land = -1.0
	_push()
	if progress <= 0.0 and _since_land < 0.0:
		set_process(false)


## Where the wind-up is, 0..1. Whether the field is past the commit point is
## the warden's to say - it knows its own `commit_fraction`.
func set_progress(value: float, committed := false) -> void:
	value = clampf(value, 0.0, 1.0)
	var was := progress
	progress = value
	_material.set_shader_parameter("progress", progress)
	_material.set_shader_parameter("committed", committed and progress > 0.0)
	if progress > 0.0 and was <= 0.0:
		set_process(true)


## The effect landing on everyone in the circle. The area says so - flash,
## shards - then stays iced for as long as the slow it just dealt.
func land(slow_seconds: float) -> void:
	_since_land = 0.0
	_slow_left = maxf(slow_seconds, 0.0)
	set_process(true)
	_push()


func _push() -> void:
	_material.set_shader_parameter("since_land", _since_land)
	_material.set_shader_parameter("fade", clampf(_slow_left / THAW_SECONDS, 0.0, 1.0))
	_material.set_shader_parameter("time", _time)


func _draw() -> void:
	# One quad; the shader decides every pixel in it. Two pixels of slack so the
	# rim's outer edge is never clipped by the quad it is drawn on.
	var half := radius + 2.0
	draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), Color.WHITE)
