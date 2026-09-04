extends RefCounted
## Waiting-area couch, upholstered in the biome's accent so the furniture reads
## as belonging to the room rather than dropped into it.

const Brush := preload("_brush.gd")

const SIZE := Vector2i(52, 17)
const BLOCKS := Vector2(50, 8)


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var w: int = SIZE.x
	var fabric: Color = Color(spec["accent"])
	var dark := fabric.darkened(0.45)
	var lit := fabric.lightened(0.18)
	# Backrest, then the arms, then the seat cushions in front of both.
	Brush.block(img, Rect2i(1, 0, w - 2, 8), fabric.darkened(0.15), dark)
	Brush.block(img, Rect2i(0, 4, 6, 9), fabric.darkened(0.30), dark)
	Brush.block(img, Rect2i(w - 6, 4, 6, 9), fabric.darkened(0.38), dark)
	Brush.block(img, Rect2i(5, 7, w - 10, 6), lit, dark)
	# The split between the two cushions.
	for y in range(7, 13):
		img.set_pixel(w / 2, y, dark)
	for x in range(2, w - 2):
		img.set_pixel(x, 8, fabric.lightened(0.35))
	# Legs.
	for y in range(13, 17):
		Brush.row(img, spec, y, 7, 11, 0.28)
		Brush.row(img, spec, y, w - 11, w - 7, 0.22)
	return img
