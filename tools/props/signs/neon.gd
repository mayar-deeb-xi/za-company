extends RefCounted
## The studio's wall sign, in neon: DESIGN.md's LIVE LAUGH ENGAGE, which is the
## company's version of a sign you have seen in somebody's kitchen.
##
## Tubing and nothing else - no board, no frame, no paper. That is what makes it
## neon rather than a poster, and in a room this dark a sign that is only its own
## light is the right kind of loud. The glyphs are the biome's accent pushed
## bright, and the bloom around them is real alpha, so the words read as lit
## rather than painted.

const Brush := preload("../_brush.gd")

## Three lines because it is a parody of a three-word sign, and because the
## third word is the joke: nobody hangs ENGAGE on a wall by accident.
const TEXT := ["LIVE", "LAUGH", "ENGAGE"]
const SIZE := Vector2i(46, 40)
const BLOCKS := Vector2.ZERO
## Fixed to the wall by its top-left corner, like every other sign.
const PIN := Vector2i(0, 0)

## The eight neighbours the glow spreads into. A typed constant rather than an
## inline array, because the bloom pass adds them to a Vector2i and an untyped
## element makes that sum untyped too.
const AROUND: Array[Vector2i] = [
	Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),
	Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
]


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var accent := Color(spec["accent"])
	var tube: Color = accent.lightened(0.55)
	for i in TEXT.size():
		Brush.text(img, TEXT[i], Vector2i(0, 6 + i * 10), tube, SIZE.x)
	_bloom(img, accent)
	# The transformer and the cable it runs off, tucked into the bottom corner:
	# neon that is plugged into nothing is a decal.
	Brush.panel(img, spec, Rect2i(2, SIZE.y - 6, 8, 6), 0.34)
	for step in 5:
		Brush.pixel(img, Vector2i(10 + step, SIZE.y - 3 + step / 3),
			Brush.shade(spec, 0.10))
	return img


## One pass of glow around whatever is already lit: every empty pixel touching a
## tube takes the accent at low alpha, and the diagonals take half of it. Read
## back off the image rather than drawn from the text twice, so a floor can
## change the words without touching the glow.
static func _bloom(img: Image, accent: Color) -> void:
	var lit: Array[Vector2i] = []
	for y in SIZE.y:
		for x in SIZE.x:
			if img.get_pixel(x, y).a > 0.5:
				lit.append(Vector2i(x, y))
	for at: Vector2i in lit:
		for step: Vector2i in AROUND:
			var to := at + step
			if to.x < 0 or to.y < 0 or to.x >= SIZE.x or to.y >= SIZE.y:
				continue
			if img.get_pixel(to.x, to.y).a > 0.0:
				continue
			var glow := accent
			glow.a = 0.45 if step.x == 0 or step.y == 0 else 0.22
			img.set_pixel(to.x, to.y, glow)
