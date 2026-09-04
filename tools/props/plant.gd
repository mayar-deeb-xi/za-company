extends RefCounted
## The pot plant, alive or not. DESIGN.md gives floor 1 a dead one; the droop is
## the whole difference, so both come out of one painter rather than two.

const Brush := preload("_brush.gd")

## Foliage has no biome either: alive is green and dead is brown on any floor.
const LEAF := Color("3f9151")
const LEAF_LIT := Color("62b96a")
const LEAF_DEAD := Color("8a6a3a")
const LEAF_DEAD_LIT := Color("a88a52")
const SOIL := Color("42301f")

const SIZE := Vector2i(20, 24)
const BLOCKS := Vector2(12, 5)


static func paint(spec: Dictionary) -> Image:
	return grow(spec, false)


static func grow(spec: Dictionary, dead: bool) -> Image:
	var img := Brush.blank(SIZE)
	var crown := Vector2(10.0, 14.0)
	# Leaves radiate from the crown. A dead plant's fall instead of reaching:
	# every direction is pulled downwards, which is what reads as dying at this
	# size - a browner green alone just looks like a different plant.
	var reach := [
		Vector2(-1.0, -0.45), Vector2(-0.8, -0.75), Vector2(-0.5, -1.0),
		Vector2(-0.15, -1.1), Vector2(0.2, -1.05), Vector2(0.55, -0.9),
		Vector2(0.85, -0.6), Vector2(-1.0, 0.2), Vector2(1.0, 0.15),
	]
	var body := LEAF_DEAD if dead else LEAF
	var tip := LEAF_DEAD_LIT if dead else LEAF_LIT
	for dir in reach:
		var d: Vector2 = dir
		if dead:
			d = Vector2(d.x * 0.85, absf(d.y) * 0.55 + 0.25)
		_leaf(img, crown, d.normalized(), 8.0 if dead else 10.0, body, tip)
	# Stem, then the pot: rim lit, soil showing at the top.
	for y in range(10, 18):
		Brush.pixel(img, Vector2i(9, y), body.darkened(0.35))
		Brush.pixel(img, Vector2i(10, y), body.darkened(0.1))
	Brush.slab(img, spec, Rect2i(3, 16, 14, 4), 0.80)
	for x in range(5, 15):
		Brush.pixel(img, Vector2i(x, 18), SOIL)
	Brush.panel(img, spec, Rect2i(4, 19, 12, 5), 0.46)
	for x in range(5, 15):
		Brush.pixel(img, Vector2i(x, 23), Brush.shade(spec, Brush.OUTLINE))



	return img


## One tapering leaf, drawn as a walk out from the crown.
static func _leaf(img: Image, from: Vector2, dir: Vector2, length: float,
		body: Color, tip: Color) -> void:
	var steps := int(length)
	for i in steps:
		var along := from + dir * float(i)
		# Thick at the crown, one pixel at the tip: a frond, not a wire.
		var thick := 3 if i < steps / 2 else (2 if i < steps - 3 else 1)
		var c := body if i < steps - 2 else tip
		for w in thick:
			Brush.pixel(img, Vector2i(int(round(along.x)) + w - thick / 2,
				int(round(along.y))), c)


