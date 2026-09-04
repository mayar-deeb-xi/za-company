extends RefCounted
## A paper backdrop on a crossbar, hanging down and sweeping onto the floor.
## The one prop in the catalogue that is a big flat SURFACE, which is exactly
## what it is for: it gives the studio a wall to shoot against, and it gives a
## very dark room one pale field to read everything else against.
##
## The sweep comes off the top of the biome's own ramp with a little accent in
## it rather than being fixed white, so it reads as paper lit by whatever this
## room is lit by - on this floor, neon.

const Brush := preload("../_brush.gd")

const SIZE := Vector2i(72, 44)
## The paper is a surface, not a thing you can stand where: it blocks nearly
## its whole width, which is what makes it read as the back of the room.
const BLOCKS := Vector2(64, 6)


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var w: int = SIZE.x
	var accent := Color(spec["accent"])
	# The paper. Brightest at the top where the light hits it, and the bottom
	# four rows are the sweep curving out towards the camera.
	for y in range(3, 40):
		for x in range(4, w - 4):
			var t := 0.90 - 0.006 * float(y)
			# Falls off towards both edges, so 64 px of paper is a lit surface
			# rather than a rectangle of one colour.
			var edge := minf(float(x - 4), float(w - 5 - x)) / 12.0
			t -= 0.22 * (1.0 - minf(edge, 1.0))
			var c := Brush.shade(spec, t).lerp(accent, 0.10)
			Brush.pixel(img, Vector2i(x, y), c)
	# The sweep: the paper leaves the vertical and runs along the floor, which
	# is the one detail that says backdrop rather than bedsheet.
	for y in range(40, 43):
		for x in range(2, w - 2):
			var t := 0.62 - 0.14 * float(y - 40)
			Brush.pixel(img, Vector2i(x, y), Brush.shade(spec, t).lerp(accent, 0.08))
	for x in range(2, w - 2):
		Brush.pixel(img, Vector2i(x, 43), Brush.shade(spec, 0.06))
	# A crease down the roll, because nobody re-rolls these properly.
	for y in range(6, 40):
		Brush.pixel(img, Vector2i(26, y), Brush.shade(spec, 0.52))
		Brush.pixel(img, Vector2i(27, y), Brush.shade(spec, 0.94))
	# The crossbar and the two uprights holding it up.
	Brush.slab(img, spec, Rect2i(0, 0, w, 4), 0.44)
	for post in [2, w - 6]:
		Brush.panel(img, spec, Rect2i(post, 2, 4, 40), 0.30)
	return img
