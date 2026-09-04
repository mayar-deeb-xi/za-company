extends RefCounted
## A tower with its side panel off and its insides showing - mid-repair, or
## mid-abandonment, which on this floor is the same thing.

const Brush := preload("../_brush.gd")

const SIZE := Vector2i(18, 20)
const BLOCKS := Vector2(14, 6)


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var art: Vector2i = SIZE
	Brush.panel(img, spec, Rect2i(1, 4, art.x - 2, art.y - 4), 0.34)
	Brush.slab(img, spec, Rect2i(1, 2, art.x - 2, 4), 0.60)
	# The open bay: a board, a drive, and a fan opening.
	var bay := Rect2i(4, 7, 10, 11)
	Brush.fill(img, spec, bay, 0.06)
	for y in range(9, 15):
		for x in range(5, 11):
			Brush.pixel(img, Vector2i(x, y), Brush.PCB if (x + y) % 3 != 0 else Brush.PCB.darkened(0.4))
	for x in range(5, 13):
		Brush.pixel(img, Vector2i(x, 8), Brush.shade(spec, 0.90))
	Brush.pixel(img, Vector2i(12, 10), Brush.LED_OK)
	Brush.pixel(img, Vector2i(12, 16), Color(spec["accent"]))
	# The panel that came off, leaning against the case.
	for y in range(6, art.y):
		Brush.pixel(img, Vector2i(0, y), Brush.shade(spec, 0.52))
		Brush.pixel(img, Vector2i(1, y), Brush.shade(spec, Brush.OUTLINE))
	return img
