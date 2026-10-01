extends Node2D
## A static charge going off: a ring opening round the chest and ten sparks
## thrown out level with it that skip once on the floor. static_charge.gd's,
## split out because it has to outlive the body it went off on - the arc that
## sets a charge off is often the blow that kills.
##
## Top-level in WORLD pixels, drawn live, frees itself. The sparks carry a
## height (`z`) above the floor point they stand over, so a bounce is a bounce
## on the floor and not on an invisible line at chest height.

const RING_FROM := 2.0
const RING_TO := 12.0
const RING_SECONDS := 0.22
## The ring is nearly round - it is at chest height, in the air, not lying on
## the floor like the charge ring.
const RING_SQUASH := 0.8
const SPARKS := 10
const SPARK_SECONDS := 0.4
const GRAVITY := 240.0
const BOUNCE := 0.45

var colour := Color.WHITE
var _at := Vector2.ZERO
var _age := 0.0
## [floor position, height, velocity on the floor, vertical speed, colour]
var _sparks: Array = []


func setup(at: Vector2, spark: Color) -> void:
	top_level = true
	global_position = Vector2.ZERO
	z_index = 1
	_at = at
	colour = spark
	for i in SPARKS:
		var t := TAU * i / SPARKS
		_sparks.append([at + Vector2(0, 10), 10.0, Vector2(cos(t) * 70.0, sin(t) * 30.0),
			40.0 + randf() * 30.0, Color.WHITE if i % 2 == 1 else spark, BOUNCE])


func _process(delta: float) -> void:
	_age += delta
	if _age >= SPARK_SECONDS:
		queue_free()
		return
	for s in _sparks:
		s[0] += s[2] * delta
		s[1] += s[3] * delta
		s[3] -= GRAVITY * delta
		if s[1] < 0.0:
			s[1] = 0.0
			s[3] = -s[3] * s[5]
			s[2] *= 0.55
			s[5] = 0.0
	queue_redraw()


func _draw() -> void:
	var t := _age / RING_SECONDS
	if t < 1.0:
		var e := 1.0 - pow(1.0 - t, 2.0)
		var ink := Color.WHITE.lerp(colour, t)
		ink.a = 1.0 - t
		draw_polyline(_ellipse(_at, lerpf(RING_FROM, RING_TO, e), RING_SQUASH), ink, 1.0)
	var life := _age / SPARK_SECONDS
	var alpha := (1.0 - life) / 0.3 if life > 0.7 else 1.0
	for s in _sparks:
		var c: Color = s[4]
		c.a = alpha
		draw_rect(Rect2((s[0] - Vector2(0, s[1])).round(), Vector2.ONE), c)


## A flat ellipse in whole pixels, the shape charge_ring.gd draws its own from.
static func _ellipse(centre: Vector2, r: float, squash: float, segments := 28) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments + 1:
		var angle := TAU * i / segments
		points.append((centre + Vector2(cos(angle) * r, sin(angle) * r * squash)).round())
	return points
