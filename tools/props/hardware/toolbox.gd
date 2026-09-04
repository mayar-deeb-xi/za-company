extends RefCounted
## An open toolbox: the prop that says the junk around it is being worked on
## rather than simply dumped.

const Brush := preload("../_brush.gd")

const SIZE := Vector2i(20, 14)
const BLOCKS := Vector2(16, 6)


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var art: Vector2i = SIZE
	Brush.panel(img, spec, Rect2i(1, 4, art.x - 2, art.y - 4), 0.36)
	Brush.slab(img, spec, Rect2i(0, 3, art.x, 5), 0.74)
	# The carry handle. This is the pixel that makes a box a TOOLbox at this
	# size - without it the silhouette is a bench, which is what it read as.
	for x in range(6, 14):
		Brush.pixel(img, Vector2i(x, 0), Brush.shade(spec, Brush.OUTLINE))
	for at in [Vector2i(5, 1), Vector2i(14, 1), Vector2i(5, 2), Vector2i(14, 2)]:
		Brush.pixel(img, at, Brush.shade(spec, Brush.OUTLINE))
	# A band of the biome's accent, because a toolbox is the one thing on this
	# floor somebody bought new.
	for x in range(3, art.x - 3):
		Brush.pixel(img, Vector2i(x, 9), Color(spec["accent"]))
	# A screwdriver left lying on the lid.
	for x in range(13, 18):
		Brush.pixel(img, Vector2i(x, 4), Brush.shade(spec, 0.95))
	Brush.pixel(img, Vector2i(11, 4), Color(spec["accent"]).darkened(0.35))
	Brush.pixel(img, Vector2i(12, 4), Color(spec["accent"]).darkened(0.35))
	return img
