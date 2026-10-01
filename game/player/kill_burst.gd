extends Node2D
## A body that dies breaks apart into its own pixels instead of vanishing on
## the frame it is freed.
##
## The enemy is `queue_free()`d inside the very `take_damage()` that killed it,
## so this is built by player.gd on that frame, while the sprite can still be
## read, and is left in the body's PARENT - the room - where it outlives the
## body and goes with the room on a door. It takes the frame the body was
## showing, mirrored if the body was, and throws every other opaque pixel of
## it (a checkerboard, so a 32 px body is about a hundred) outward from the
## chest and away from the player, white for the first 0.06 s and then its own
## colour, bouncing once off the floor. A ring opens at the feet in the spark
## colour.
##
## Every pixel carries a height above the floor point it stands over, the way
## spark_burst.gd's do, so the pieces of a head fall a head's height before
## they land. Picked from the Combo Lab preview and shipped as previewed.

const GRAVITY := 260.0
const BOUNCE := 0.3
const WHITE_SECONDS := 0.06
const LIFE_FROM := 0.5
const LIFE_TO := 0.8
const RING_FROM := 3.0
const RING_TO := 16.0
const RING_SECONDS := 0.25
const RING_SQUASH := 0.45
## How hard the pieces are thrown away from whoever struck the blow.
const AWAY := 25.0

var colour := Color.WHITE
var _feet := Vector2.ZERO
var _age := 0.0
## [floor position, height, floor velocity, vertical speed, colour, life, bounce]
var _bits: Array = []


## Breaks `body` apart. `away` is the direction the blow travelled (from the
## player to the body), `spark` the striker's colour. Does nothing to a body
## with no readable sprite - a missing burst is only a missing burst.
static func shatter(body: Node2D, away: Vector2, spark: Color) -> void:
	var sprite := body.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	var world := body.get_parent()
	if sprite == null or sprite.sprite_frames == null or world == null:
		return
	var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if tex == null:
		return
	var img := tex.get_image()
	if img == null:
		return
	if img.is_compressed():
		img.decompress()
	var node: Node2D = (load("res://game/player/kill_burst.gd") as GDScript).new()
	world.add_child(node)
	node.setup(body.global_position, sprite, img, away, spark)


func setup(feet: Vector2, sprite: AnimatedSprite2D, img: Image, away: Vector2,
		spark: Color) -> void:
	top_level = true
	global_position = Vector2.ZERO
	z_index = 1
	_feet = feet
	colour = spark
	var size := Vector2(img.get_width(), img.get_height())
	var corner := feet + sprite.position + sprite.offset
	if sprite.centered:
		corner -= size / 2.0
	var chest := feet + Vector2(0, -10)
	var push := signf(away.x) if away.x != 0.0 else 1.0
	for y in img.get_height():
		for x in img.get_width():
			if (x + y) % 2 != 0:
				continue
			var src_x := img.get_width() - 1 - x if sprite.flip_h else x
			var c := img.get_pixel(src_x, y)
			if c.a <= 0.5:
				continue
			var at := corner + Vector2(x, y)
			var d := at - chest
			_bits.append([Vector2(at.x, feet.y), feet.y - at.y,
				Vector2(d.x * 3.0 + randf_range(-10, 10) + push * AWAY,
					d.y * 0.6 + randf_range(-8, 8)),
				20.0 + randf() * 50.0, Color(c, 1.0),
				randf_range(LIFE_FROM, LIFE_TO), BOUNCE])


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE_TO:
		queue_free()
		return
	for b in _bits:
		b[0] += b[2] * delta
		b[1] += b[3] * delta
		b[3] -= GRAVITY * delta
		if b[1] < 0.0:
			b[1] = 0.0
			b[3] = -b[3] * b[6]
			b[2] *= 0.55
			b[6] = 0.0
	queue_redraw()


func _draw() -> void:
	var t := _age / RING_SECONDS
	if t < 1.0:
		var e := 1.0 - pow(1.0 - t, 2.0)
		var ink := Color.WHITE.lerp(colour, t)
		ink.a = 1.0 - t
		draw_polyline(_ellipse(_feet + Vector2(0, -1), lerpf(RING_FROM, RING_TO, e)), ink, 1.0)
	for b in _bits:
		var life: float = b[5]
		if _age >= life:
			continue
		var k := _age / life
		var c: Color = Color.WHITE if _age < WHITE_SECONDS else b[4]
		c.a = (1.0 - k) / 0.3 if k > 0.7 else 1.0
		draw_rect(Rect2((b[0] - Vector2(0, b[1])).round(), Vector2.ONE), c)


static func _ellipse(centre: Vector2, r: float, segments := 28) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments + 1:
		var angle := TAU * i / segments
		points.append((centre + Vector2(cos(angle) * r, sin(angle) * r * RING_SQUASH)).round())
	return points
