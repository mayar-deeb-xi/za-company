extends RefCounted
## Litter: offcut wire, dropped screws, a snapped cable tie, a chip of board.
## Deliberately drawn WITHOUT an outline, unlike every other prop here - an
## outline is what gives a prop volume, and this has none. It is meant to read
## as marks on the floor you walk over, not as something in the way.
##
## Nothing in it is red or gold: the heart pickup is red and the hazard's sparks
## are gold, and litter that borrows either colour is litter the player walks
## across the room to try to pick up.

const Brush := preload("_brush.gd")

const SIZE := Vector2i(24, 9)
const BLOCKS := Vector2.ZERO


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	# A loop of offcut wire.
	for at in [Vector2i(2, 5), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 5),
			Vector2i(5, 6), Vector2i(4, 7), Vector2i(3, 7), Vector2i(2, 6)]:
		Brush.pixel(img, at, Brush.shade(spec, 0.08))
	for at in [Vector2i(6, 6), Vector2i(7, 7), Vector2i(8, 7)]:
		Brush.pixel(img, at, Brush.shade(spec, 0.12))
	# Screws, bright enough to catch the eye and small enough not to hold it.
	for at in [Vector2i(11, 3), Vector2i(14, 7), Vector2i(19, 4)]:
		Brush.pixel(img, at, Brush.shade(spec, 0.96))
		Brush.pixel(img, at + Vector2i(0, 1), Brush.shade(spec, 0.24))
	# A chip of board, and the cable tie somebody cut and dropped.
	Brush.pixel(img, Vector2i(16, 5), Brush.PCB)
	Brush.pixel(img, Vector2i(17, 5), Brush.PCB.darkened(0.3))
	Brush.pixel(img, Vector2i(17, 6), Brush.PCB.darkened(0.5))
	for at in [Vector2i(20, 7), Vector2i(21, 6), Vector2i(22, 6)]:
		Brush.pixel(img, at, Color(spec["accent"]).darkened(0.35))
	# Plastic fragments.
	for at in [Vector2i(9, 2), Vector2i(10, 2), Vector2i(13, 4), Vector2i(22, 3)]:
		Brush.pixel(img, at, Brush.shade(spec, 0.72))
	return img
