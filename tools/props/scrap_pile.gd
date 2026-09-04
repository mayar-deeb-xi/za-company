extends RefCounted
## A heap of e-waste: a keyboard on top, a fan, a board, a coil of wire. The
## filler prop, and the one a room gets several of - which is why it is a low
## irregular mound rather than another box.

const Brush := preload("_brush.gd")

const SIZE := Vector2i(28, 15)
const BLOCKS := Vector2(24, 6)


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var art: Vector2i = SIZE
	# The mound, highest a third of the way along so it does not read as a arch.
	for x in art.x:
		var t := float(x) / float(art.x - 1)
		var top: int = art.y - 4 - int(round(sin(pow(t, 0.7) * PI) * 7.0))
		for y in range(top, art.y):
			var shade := 0.30 if y > top + 1 else 0.46
			if x <= 1 or x >= art.x - 2 or y == art.y - 1:
				shade = Brush.OUTLINE
			Brush.pixel(img, Vector2i(x, y), Brush.shade(spec, shade))
	# A keyboard, tipped on the heap: a pale slab with key rows punched in it.
	for y in range(4, 8):
		for x in range(4, 17):
			Brush.pixel(img, Vector2i(x, y), Brush.shade(spec, 0.88 if y < 6 else 0.62))
	for x in range(5, 16, 2):
		Brush.pixel(img, Vector2i(x, 5), Brush.shade(spec, 0.16))
		Brush.pixel(img, Vector2i(x, 7), Brush.shade(spec, 0.16))
	# A case fan, and a bare board behind it.
	var fan := Rect2i(18, 5, 7, 7)
	Brush.fill(img, spec, fan, 0.24)
	Brush.outline(img, spec, fan)
	for y in range(7, 10):
		for x in range(20, 23):
			Brush.pixel(img, Vector2i(x, y), Brush.shade(spec, 0.66))
	for x in range(15, 19):
		Brush.pixel(img, Vector2i(x, 9), Brush.PCB)
		Brush.pixel(img, Vector2i(x, 10), Brush.PCB.darkened(0.35))
	# A coil of wire spilling off the side.
	for step in 7:
		Brush.pixel(img, Vector2i(2 + step, art.y - 3 - (step % 3)),
			Brush.shade(spec, 0.08))
	return img
