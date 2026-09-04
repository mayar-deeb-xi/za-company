extends RefCounted
## The one desk in Khaled's office, and the point of it is what is NOT on it.
## Every other desk in the building is buried - the workstation has a cup
## nobody washed, the dev desk has a duck and a keyboard, the call station has
## a queue counter running. This one is a polished slab with a pen laid square
## to the edge, and that emptiness is the whole characterisation: a man who
## does no work in the room where the work is decided.
##
## Bigger than any of them too, at 84 px, but not the widest - the boardroom
## table is 96, and a desk that out-measured the table people are made to sit
## at would be saying something about him this room does not mean.

const Brush := preload("../_brush.gd")

const SIZE := Vector2i(84, 40)
const BLOCKS := Vector2(80, 8)


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var w: int = SIZE.x
	var accent: Color = Color(spec["accent"])
	# The top, polished to a mirror: it takes the window at the back and goes
	# almost black at the front. Written as an explicit ramp rather than with
	# slab(), whose five percent a row is pitched at a three-row surface and
	# falls off a cliff across one twenty-four deep - the first draft got this
	# look by accident, out of a clamp, which is not a thing to leave standing.
	var top := Rect2i(0, 2, w, 24)
	for y in top.size.y:
		var t: float = lerpf(0.86, 0.22, float(y) / float(top.size.y - 1))
		for x in top.size.x:
			Brush.pixel(img, top.position + Vector2i(x, y),
				Brush.shade(spec, t if x < top.size.x - 2 else t - 0.10))
	Brush.outline(img, spec, top)
	# The two lifted rows across the back are the city, in the desk.
	for x in range(3, w - 3):
		Brush.pixel(img, Vector2i(x, 4), Brush.shade(spec, 0.92))
		Brush.pixel(img, Vector2i(x, 5), Brush.shade(spec, 0.80))
	# One inlaid line the length of it, a hand's width in from the front edge.
	for x in range(5, w - 5):
		Brush.pixel(img, Vector2i(x, 21), accent.darkened(0.30))
	# The pen. It is the only object on the desk and it is square to the edge,
	# which is a decision rather than an accident - nothing here is where it
	# fell.
	for x in range(30, 46):
		Brush.pixel(img, Vector2i(x, 15), Brush.shade(spec, 0.12))
		Brush.pixel(img, Vector2i(x, 16), Brush.shade(spec, 0.30))
	for x in range(44, 48):
		Brush.pixel(img, Vector2i(x, 15), accent.lightened(0.20))
		Brush.pixel(img, Vector2i(x, 16), accent.darkened(0.20))
	# The front: one unbroken panel, no drawers, no handles. A desk with
	# nothing to open is a desk nothing is kept in.
	Brush.panel(img, spec, Rect2i(2, 25, w - 4, 11), 0.20)
	for x in range(4, w - 4):
		Brush.pixel(img, Vector2i(x, 30), Brush.shade(spec, 0.34))
	# It stands clear of the floor on a recessed plinth, which is the detail
	# that makes a heavy thing look like it is floating and costs six rows.
	Brush.panel(img, spec, Rect2i(8, 35, w - 16, 3), 0.10)
	for x in range(6, w - 6):
		Brush.pixel(img, Vector2i(x, 39), Brush.shade(spec, 0.06))
	return img
