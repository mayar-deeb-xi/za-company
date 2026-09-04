extends RefCounted
## A rack of servers: perforated units, status lights, and cabling spilling out
## of the bottom because nobody dressed it.

const Brush := preload("../_brush.gd")

const SIZE := Vector2i(22, 32)
const BLOCKS := Vector2(18, 7)


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var art: Vector2i = SIZE
	Brush.panel(img, spec, Rect2i(1, 2, art.x - 2, art.y - 2), 0.20)
	Brush.slab(img, spec, Rect2i(0, 0, art.x, 4), 0.56)
	# Six units, each a slot with a pair of lights. One of them is red - the
	# reason there is a maintenance floor at all.
	for unit in 6:
		var y := 6 + unit * 4
		Brush.row(img, spec, y, 3, art.x - 3, 0.09)
		Brush.row(img, spec, y + 1, 3, art.x - 3, 0.30)
		Brush.pixel(img, Vector2i(4, y + 1), Brush.LED_BAD if unit == 2 else Brush.LED_OK)
		Brush.pixel(img, Vector2i(6, y + 1), Brush.LED_OK if unit != 4 else Brush.LED_BAD)
	# The cable bundle, hanging out of the bottom and pooling on the floor.
	for strand in [Vector2i(5, 27), Vector2i(8, 27), Vector2i(12, 27)]:
		for step in 4:
			Brush.pixel(img, strand + Vector2i(-step / 2, step), Brush.shade(spec, 0.07))
	return img
