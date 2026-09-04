extends RefCounted
## The table decisions are announced at. The widest prop in the catalogue at
## 96 px - two thirds of the reception counter again - because a boardroom
## table is not furniture you walk around, it is the room's centre, and half of
## what makes the executive floor read as the executive floor is that this is
## the biggest flat thing in the building.
##
## Polished rather than lit: no screens on it, one speakerphone, and a brass
## inlay round the edge. The chairs are the existing `chair`, six of them, and
## the ones on the far side sort behind this and show as backs above it.

const Brush := preload("../_brush.gd")

const SIZE := Vector2i(96, 34)
## Nearly the full width: six people sit at it, so walking through it is not a
## thing the room should allow.
const BLOCKS := Vector2(92, 8)

## Where a notepad and a glass sit, as x offsets, near side then far side.
const PLACES_FAR := [10, 30, 50, 70]
const PLACES_NEAR := [16, 40, 64, 82]


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var w: int = SIZE.x
	var accent: Color = Color(spec["accent"])
	# The top. slab() already falls off towards the front, which is what makes
	# a 22 px plane read as a plane; the two lifted rows across the back are
	# the window this floor does not have, reflected.
	Brush.slab(img, spec, Rect2i(0, 2, w, 22), 0.84)
	for x in range(3, w - 3):
		Brush.pixel(img, Vector2i(x, 4), Brush.shade(spec, 0.98))
		Brush.pixel(img, Vector2i(x, 5), Brush.shade(spec, 0.90))
	# Grain, and it runs the LENGTH of the table: a 96 px top with no grain in
	# it is a slab of plastic.
	for streak: Array in [[8, 6, 58, 0.72], [12, 30, 88, 0.78],
			[16, 4, 44, 0.70], [20, 52, 92, 0.74]]:
		Brush.row(img, spec, streak[0], streak[1], streak[2], streak[3])
	# The brass inlay, inset from the edge. One line, all the way round, and it
	# is the whole difference between this and a canteen table.
	Brush.ring(img, Rect2i(3, 5, w - 6, 17), accent.darkened(0.12))
	# What is on it: a pad and a glass at each place. The pads are the only
	# paper in the room and they are all square to the table, which is its own
	# small joke - nobody has written on any of them.
	for at_x: int in PLACES_FAR:
		Brush.block(img, Rect2i(at_x, 7, 7, 4), Brush.PAPER,
			Brush.shade(spec, 0.30))
		_glass(img, spec, Vector2i(at_x + 9, 7))
	for at_x: int in PLACES_NEAR:
		Brush.block(img, Rect2i(at_x, 16, 7, 4), Brush.PAPER,
			Brush.shade(spec, 0.30))
		_glass(img, spec, Vector2i(at_x + 9, 16))
	# The speakerphone, dead centre, and the only dark thing on the table -
	# three legs and a ring of buttons, one of them lit.
	var mid: int = w / 2 - 5
	for y in range(11, 16):
		for x in range(mid, mid + 11):
			var edge := y == 11 or y == 15 or x == mid or x == mid + 10
			Brush.pixel(img, Vector2i(x, y),
				Brush.shade(spec, 0.14) if edge else Brush.SCREEN)
	Brush.pixel(img, Vector2i(mid + 5, 13), Brush.LED_OK)
	Brush.pixel(img, Vector2i(mid + 2, 13), accent.darkened(0.35))
	Brush.pixel(img, Vector2i(mid + 8, 13), accent.darkened(0.35))
	# Apron and two pedestals. A table this wide on four legs reads as a
	# trestle; on two blocks it reads as joinery.
	Brush.panel(img, spec, Rect2i(2, 23, w - 4, 7), 0.28)
	Brush.panel(img, spec, Rect2i(10, 29, 14, 4), 0.18)
	Brush.panel(img, spec, Rect2i(w - 24, 29, 14, 4), 0.18)
	for x in range(4, w - 4):
		Brush.pixel(img, Vector2i(x, 33), Brush.shade(spec, 0.08))
	return img


## A tumbler of water: three pixels of glass with a lit left edge.
static func _glass(img: Image, spec: Dictionary, at: Vector2i) -> void:
	for y in 4:
		for x in 3:
			Brush.pixel(img, at + Vector2i(x, y),
				Brush.shade(spec, 0.98 if x == 0 else 0.66))
	Brush.pixel(img, at + Vector2i(1, 0), Brush.shade(spec, 0.34))
