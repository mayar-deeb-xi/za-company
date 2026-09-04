extends RefCounted
## The front desk: a bright slab overhanging a panel with the sign on it. Reads
## as a counter from the front, which is the only side the player ever sees.

const Brush := preload("../_brush.gd")

const SIZE := Vector2i(96, 22)
const BLOCKS := Vector2(90, 9)


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var w: int = SIZE.x
	Brush.panel(img, spec, Rect2i(2, 6, w - 4, 16), 0.44)
	Brush.slab(img, spec, Rect2i(0, 0, w, 7), 0.90)
	# Panel joints, so 90 px of counter front is not one flat field of grey.
	for seam in [10, w - 11]:
		for y in range(8, 21):
			Brush.pixel(img, Vector2i(seam, y), Brush.shade(spec, 0.26))
			Brush.pixel(img, Vector2i(seam + 1, y), Brush.shade(spec, 0.56))
	# The sign, inset into the panel so it reads as mounted rather than painted.
	var plaque := Rect2i(16, 8, w - 32, 11)
	Brush.fill(img, spec, plaque, 0.14)
	Brush.outline(img, spec, plaque)
	Brush.text(img, "RECEPTION", Vector2i(0, 11), Brush.shade(spec, 1.0), w)
	return img
