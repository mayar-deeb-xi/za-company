extends RefCounted
## The founder, in oils, in a gilt frame, with a brass plaque under him. The
## only sign in the game that is a PICTURE with a caption rather than a caption
## on its own - and the caption is one word, because a portrait that has to
## explain who it is of is not a portrait of anybody important.
##
## The sitter is painted in varnish rather than in skin: a hundred years of
## nicotine and linseed have taken the whole canvas brown, which is what an old
## commissioned portrait actually looks like and which means the prop makes no
## claim about whose face it is. What reads is the shape - shoulders, collar,
## tie - and that is all a portrait at this size can carry.

const Brush := preload("../_brush.gd")

const TEXT := "FOUNDER"

## Varnish, and the shadow it has gone to in the corners of the canvas.
const VARNISH := Color("9a7355")
const VARNISH_DARK := Color("4b3628")

const SIZE := Vector2i(44, 50)
const BLOCKS := Vector2.ZERO
## Top-left, like every sign: it hangs on the wall, so it sorts before
## everything in the room.
const PIN := Vector2i(0, 0)


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var w: int = SIZE.x
	var accent: Color = Color(spec["accent"])
	# The frame, three courses of it, lit from the left like everything else -
	# and the middle course is the brightest, which is what makes moulding read
	# as moulding rather than as a border.
	for inset in 3:
		var tone: Color = [accent.darkened(0.30), accent.lightened(0.30),
			accent.darkened(0.05)][inset]
		Brush.ring(img, Rect2i(inset, inset, w - inset * 2, 40 - inset * 2),
			tone)
	# The canvas: darkest at the corners, which is where the varnish goes first.
	for y in range(3, 37):
		for x in range(3, w - 3):
			var to_edge: float = minf(
				minf(float(x - 3), float(w - 4 - x)) / 8.0,
				minf(float(y - 3), float(36 - y)) / 8.0)
			Brush.pixel(img, Vector2i(x, y), VARNISH_DARK.lerp(
				VARNISH.darkened(0.35), clampf(to_edge, 0.0, 1.0)))
	# The sitter: shoulders across the bottom of the canvas, a head above them,
	# a collar and a tie. Nothing else - no features, because five pixels of
	# face either read as a person or as a mistake, and this way they read as
	# a person seen across a dark room.
	for y in range(24, 37):
		var half: int = 9 + (y - 24) / 2
		for x in range(w / 2 - half, w / 2 + half):
			Brush.pixel(img, Vector2i(x, y), VARNISH_DARK.darkened(0.35))
	for y in range(14, 25):
		var half: int = 5 if y > 15 and y < 23 else 4
		for x in range(w / 2 - half, w / 2 + half):
			var c := VARNISH if x < w / 2 + 1 else VARNISH.darkened(0.22)
			Brush.pixel(img, Vector2i(x, y), c)
	for y in range(13, 17):
		for x in range(w / 2 - 5, w / 2 + 5):
			if y == 13 or x < w / 2 - 4 or x > w / 2 + 3:
				Brush.pixel(img, Vector2i(x, y), VARNISH_DARK.darkened(0.5))
	for y in range(25, 30):
		var half: int = 4 - (y - 25) / 2
		for x in range(w / 2 - half, w / 2 + half):
			Brush.pixel(img, Vector2i(x, y), Brush.PAPER.darkened(0.28))
	for y in range(26, 34):
		Brush.pixel(img, Vector2i(w / 2 - 1, y), accent.darkened(0.45))
		Brush.pixel(img, Vector2i(w / 2, y), accent.darkened(0.60))
	# The plaque, screwed to the wall under the frame: brass, engraved dark.
	var plate := Rect2i(6, 42, w - 12, 7)
	Brush.block(img, plate, accent.darkened(0.20), accent.darkened(0.55))
	Brush.text(img, TEXT, Vector2i(6, 43), Brush.INK, w - 12)
	return img
