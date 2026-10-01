extends Node2D
## SUPERNOVA - what the heavy leaves on the floor the frame it goes off: two
## shockwaves rolling out from the feet and nine cracks that cool from white
## through the spark colour to dark scars, and then fade.
##
## The rest of the supernova is elsewhere, on purpose: the embers are
## charge_ring.gd's, because they belong to the stance, and the hit-stop, the
## shake and the flash are asked of game.gd and screen_flash.gd by player.gd,
## because they belong to whatever owns the clock and the camera. This is only
## the part that is a picture on the floor.
##
## Top-level in world pixels at the ring's own depth (z -1 under the player, the
## way charge_ring.gd draws), so it lies on the floor rather than over the
## bodies standing on it. Picked from the Combo Lab preview and shipped as
## previewed: rings 6 -> 36 over 0.28 s and 4 -> 26 over 0.3 s, 0.06 s late;
## cracks 11 - 24 px, glowing for 0.8 s, gone by 1.8.

const SQUASH := 0.45
## [from, to, seconds, delay, width]
const WAVES := [[6.0, 36.0, 0.28, 0.0, 2.0], [4.0, 26.0, 0.3, 0.06, 1.0]]
const CRACKS := 9
const CRACK_MIN := 11.0
const CRACK_MAX := 24.0
const GLOW_SECONDS := 0.8
const COOL_SECONDS := 0.4
const SCAR_UNTIL := 1.1
const LIFE := 1.8
const SCAR := Color(12 / 255.0, 10 / 255.0, 18 / 255.0)

var colour := Color.WHITE
var _feet := Vector2.ZERO
var _age := 0.0
var _cracks: Array[PackedVector2Array] = []


func setup(feet: Vector2, spark: Color) -> void:
	top_level = true
	global_position = Vector2.ZERO
	z_index = -1
	_feet = feet
	colour = spark
	var rng := RandomNumberGenerator.new()
	for i in CRACKS:
		var t := TAU * i / CRACKS + rng.randf_range(-0.25, 0.25)
		var length := rng.randf_range(CRACK_MIN, CRACK_MAX)
		var points := PackedVector2Array([feet])
		var d := 4.0
		while d < length:
			points.append((feet + Vector2(cos(t) * d + rng.randf_range(-1.5, 1.5),
				sin(t) * d * 0.5 + rng.randf_range(-0.75, 0.75))).round())
			d += 4.0
		_cracks.append(points)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var scar := Color(SCAR, 0.7 if _age < SCAR_UNTIL else 0.7 * (1.0 - (_age - SCAR_UNTIL) / (LIFE - SCAR_UNTIL)))
	for c in _cracks:
		draw_polyline(c, scar, 1.0)
	if _age < GLOW_SECONDS:
		var glow := Color.WHITE.lerp(colour, minf(1.0, _age / COOL_SECONDS))
		glow.a = 1.0 - _age / GLOW_SECONDS
		for c in _cracks:
			draw_polyline(c, glow, 1.0)
	for w in WAVES:
		var t: float = (_age - w[3]) / w[2]
		if t < 0.0 or t >= 1.0:
			continue
		var e := 1.0 - pow(1.0 - t, 2.0)
		var ink := Color.WHITE.lerp(colour, t)
		ink.a = 1.0 - t
		draw_polyline(_ellipse(_feet + Vector2(0, -1), lerpf(w[0], w[1], e)), ink, w[4])


static func _ellipse(centre: Vector2, r: float, segments := 28) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments + 1:
		var angle := TAU * i / segments
		points.append((centre + Vector2(cos(angle) * r, sin(angle) * r * SQUASH)).round())
	return points
