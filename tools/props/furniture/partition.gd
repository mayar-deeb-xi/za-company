extends RefCounted
## One bay of glass office partitioning. A ROW of these is a wall: the art
## abuts at 32 px spacing and so does the collision box, so a floor draws an
## office by listing segments and leaving a gap where the doorway is.
##
## The glazing is genuinely translucent, and that is load-bearing rather than
## decorative. A prop's art is drawn upwards from its foot, so a waist-high
## wall covers everything standing behind it - the lesson asset recovery's
## dividers taught, where an enemy parked on a divider's x simply could not be
## seen. An office you can walk into has to be an office you can be seen in,
## so the upper two thirds of this is glass you read through and only the kick
## panel below it is solid.

const Brush := preload("../_brush.gd")

const SIZE := Vector2i(32, 40)
## Full width, so segments placed 32 px apart block as one continuous wall.
const BLOCKS := Vector2(32, 6)

## How much of the room behind the glass comes through. Low enough that the
## frame still reads as a wall, high enough that a character behind it is a
## character rather than a smear.
const GLAZE_ALPHA := 0.34


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var w: int = SIZE.x
	var accent := Color(spec["accent"])
	# Head rail along the top, which is what stops a run of glass from reading
	# as a hole in the floor.
	for x in w:
		Brush.pixel(img, Vector2i(x, 0), Brush.shade(spec, 0.24))
		Brush.pixel(img, Vector2i(x, 1), Brush.shade(spec, 0.94))
		Brush.pixel(img, Vector2i(x, 2), Brush.shade(spec, 0.62))
	# The glazing.
	for y in range(3, 29):
		for x in w:
			var glass := Brush.shade(spec, 0.58).lerp(accent, 0.22)
			glass.a = GLAZE_ALPHA
			if x == 5:
				glass = Brush.shade(spec, 0.98)
				glass.a = 0.5                      # the sheen down one pane
			Brush.pixel(img, Vector2i(x, y), glass)
	# A transom rail across the panes. Partitioning comes in a frame, and one
	# horizontal line is what stops twenty-six rows of glass from reading as a
	# hole in the wall - drawn before the mullions so the posts cross it.
	for x in w:
		var rail := Brush.shade(spec, 0.92)
		rail.a = 0.62
		Brush.pixel(img, Vector2i(x, 15), rail)
		var under := Brush.shade(spec, 0.18)
		under.a = 0.45
		Brush.pixel(img, Vector2i(x, 16), under)
	# Mullions: one at each edge and one in the middle, so a run of segments
	# gets an even post every half bay and the seam between two of them reads
	# as one post lit from the left.
	for post: Array in [[0, 0.66], [w - 1, 0.12], [15, 0.60], [16, 0.14]]:
		var at_x: int = post[0]
		var tone: float = post[1]
		for y in range(1, 33):
			Brush.pixel(img, Vector2i(at_x, y), Brush.shade(spec, tone))
	# Sill and kick panel: the solid part, and the only part that hides
	# anything.
	for x in w:
		Brush.pixel(img, Vector2i(x, 28), Brush.shade(spec, 0.88))
	Brush.panel(img, spec, Rect2i(0, 29, w, 9), 0.40)
	for x in range(2, w - 2):
		Brush.pixel(img, Vector2i(x, 33), Brush.shade(spec, 0.52))
	# The shadow it casts on the floor, which is what sets it down on the tiles
	# instead of floating over them.
	for x in w:
		Brush.pixel(img, Vector2i(x, 38), Brush.shade(spec, 0.14))
		var edge := Brush.shade(spec, 0.04)
		edge.a = 0.45
		Brush.pixel(img, Vector2i(x, 39), edge)
	return img
