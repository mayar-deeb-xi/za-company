extends RefCounted
## A swivel chair seen from behind the desk it belongs to.

const Brush := preload("../_brush.gd")

const SIZE := Vector2i(14, 15)
const BLOCKS := Vector2(11, 5)


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var back := Rect2i(2, 0, 10, 8)
	Brush.fill(img, spec, back, 0.38)
	Brush.outline(img, spec, back)
	Brush.slab(img, spec, Rect2i(0, 7, 14, 4), 0.66)
	for y in range(11, 13):
		Brush.row(img, spec, y, 6, 8, 0.26)
	var base := Rect2i(2, 12, 10, 3)
	Brush.fill(img, spec, base, 0.32)
	Brush.outline(img, spec, base)
	return img
