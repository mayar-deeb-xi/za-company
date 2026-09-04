extends RefCounted
## The low table in front of the sofa, with something to read on it.

const Brush := preload("../_brush.gd")

const SIZE := Vector2i(26, 11)
const BLOCKS := Vector2(24, 6)


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var w: int = SIZE.x
	Brush.slab(img, spec, Rect2i(0, 2, w, 5), 0.88)
	for y in range(6, 11):
		Brush.row(img, spec, y, 3, 7, 0.26)
		Brush.row(img, spec, y, w - 7, w - 3, 0.20)
	for x in range(5, w - 5):
		Brush.pixel(img, Vector2i(x, 8), Brush.shade(spec, 0.34))
	# A magazine, squared up with the table because someone tidies this lobby.
	var mag := Rect2i(8, 0, 11, 4)
	Brush.block(img, mag, Color(spec["accent"]), Color(spec["accent"]).darkened(0.5))
	for x in range(10, 17):
		img.set_pixel(x, 2, Color(spec["accent"]).lightened(0.45))
	return img
