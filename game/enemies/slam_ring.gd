extends Node2D
## The brute's slam area, drawn rather than animated.
##
## Same argument as the warden's field (charge_ring.gd), one archetype along: an
## attack that lands as a RING around the enemy's own feet has a reach no
## animation on the body can state. A swing is read off the sprite because the
## sprite is where it happens; a circle of floor is not, so the floor says it.
##
## Two questions, one shape. A dashed rim is always there, so the area can be
## routed around BEFORE stepping into it. Inside it, an ember disc grows from
## his feet as the wind-up fills and reaches the rim exactly as the blow lands,
## so how far it reaches and how long is left are one thing to look at: the
## moment the disc touches you, leaving is no longer free.
##
## **Nothing persists, and that is the difference from the warden's field.**
## His stays iced for the whole four seconds of the slow, because a slow is a
## state the player is still carrying and the floor is the readout for it. A
## slam is finished on the frame it lands, so `land()` runs a flourish, clears
## itself, and the floor goes back to being floor. That is also why this node
## takes no duration: there is nothing left over to time.
##
## The pixels are `slam_ring.gdshader`; this script owns the numbers and hands
## them over as uniforms. It never carries the radius itself - brute_base.gd
## copies in the Touch shape's own radius and offset on _ready, so retuning the
## area in the editor moves the drawing with it and the drawing can never lie
## about the reach.
##
## Draw order is the thing to get right, and the warden paid for this lesson
## once: the level's Floor tilemap sits at z 0, so a child with a negative
## z_index draws UNDER the floor and is never seen. This node stays at z 0 and
## is the brute's first child, above the tiles and beneath the body.

const SHADER := preload("res://game/enemies/slam_ring.gdshader")

## How long the landing flash and its wave take. The shader is told this rather
## than repeating it, so retiming the flourish is one edit here.
const LAND_SECONDS := 0.45

## Declared before `radius` so its setter can reach it.
var _material := ShaderMaterial.new()

## Set by brute_base.gd from the Touch shape after this node's _ready, so it has
## to reach the shader whenever it changes, not only once at start.
@export var radius := 28.0:
	set(value):
		radius = value
		_material.set_shader_parameter("radius", radius)
		queue_redraw()

var progress := 0.0
var _since_land := -1.0
var _time := 0.0


func _ready() -> void:
	_material.shader = SHADER
	material = _material
	_material.set_shader_parameter("radius", radius)
	_material.set_shader_parameter("land_seconds", LAND_SECONDS)
	set_process(false)


func _process(delta: float) -> void:
	_time += delta
	if _since_land >= 0.0:
		_since_land += delta
		if _since_land >= LAND_SECONDS:
			_since_land = -1.0
	_push()
	# Idle again: nothing winding up and nothing left of the last landing. The
	# rim is still drawn - it is a static quad and costs nothing - but the
	# per-frame work stops until something asks for it.
	if progress <= 0.0 and _since_land < 0.0:
		set_process(false)


## Where the wind-up is, 0..1. Whether it is past the commit point is the
## brute's to say - it knows its own `commit_fraction`.
func set_progress(value: float, committed := false) -> void:
	value = clampf(value, 0.0, 1.0)
	var was := progress
	progress = value
	_material.set_shader_parameter("progress", progress)
	_material.set_shader_parameter("committed", committed and progress > 0.0)
	if progress > 0.0 and was <= 0.0:
		set_process(true)


## The blow landing. Takes no duration because nothing it does outlives the
## flourish - see the header.
func land() -> void:
	_since_land = 0.0
	set_process(true)
	_push()


func _push() -> void:
	_material.set_shader_parameter("since_land", _since_land)
	_material.set_shader_parameter("time", _time)


func _draw() -> void:
	# One quad; the shader decides every pixel in it. Two pixels of slack so the
	# rim's outer edge is never clipped by the quad it is drawn on.
	var half := radius + 2.0
	draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), Color.WHITE)
