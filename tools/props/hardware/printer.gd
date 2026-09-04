extends RefCounted
## A photocopier with the lid propped open and paper jammed in the front. The
## one machine every office recognises as broken on sight.

const Brush := preload("../_brush.gd")

const SIZE := Vector2i(30, 20)
const BLOCKS := Vector2(28, 7)


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var art: Vector2i = SIZE
	# The lid, standing up at the back rather than lying shut.
	Brush.slab(img, spec, Rect2i(4, 0, art.x - 8, 5), 0.62)
	Brush.panel(img, spec, Rect2i(1, 6, art.x - 2, art.y - 6), 0.46)
	Brush.slab(img, spec, Rect2i(0, 4, art.x, 5), 0.82)
	# Control panel and the light that says why nobody is using it.
	var pad := Rect2i(3, 10, 9, 5)
	Brush.fill(img, spec, pad, 0.14)
	Brush.outline(img, spec, pad)
	Brush.pixel(img, Vector2i(5, 12), Brush.LED_BAD)
	Brush.pixel(img, Vector2i(9, 12), Color(spec["accent"]))
	# Output slot, with the jam still in it.
	var slot := Rect2i(14, 11, art.x - 17, 4)
	Brush.fill(img, spec, slot, 0.08)
	for x in range(16, art.x - 5):
		Brush.pixel(img, Vector2i(x, 12), Brush.PAPER)
	Brush.pixel(img, Vector2i(art.x - 6, 11), Brush.PAPER)
	Brush.pixel(img, Vector2i(art.x - 5, 13), Brush.PAPER)
	return img
