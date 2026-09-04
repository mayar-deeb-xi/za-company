extends RefCounted
## The drinks trolley in the boardroom. A small prop doing a lot of work: it is
## the one piece of furniture in the building that exists purely to be poured
## from, and a floor that has one is a floor where deals are closed rather than
## tickets are closed.
##
## The decanter is the fourth fixed colour in the catalogue - water, coffee,
## trophies, and now this. Whisky is amber in every room for the same reason
## coffee is brown in every room.

const Brush := preload("../_brush.gd")

const WHISKY := Color("a5591f")
const WHISKY_LIT := Color("d08c3a")

const SIZE := Vector2i(26, 28)
const BLOCKS := Vector2(22, 6)


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var w: int = SIZE.x
	var accent: Color = Color(spec["accent"])
	# The frame: two brass uprights and the rail you push it by. Brass rather
	# than the ramp, because a trolley is a frame before it is a surface and
	# the frame is the only part with a colour of its own.
	for y in range(4, 26):
		Brush.pixel(img, Vector2i(2, y), accent.darkened(0.10))
		Brush.pixel(img, Vector2i(w - 3, y), accent.darkened(0.42))
	for x in range(2, w - 2):
		Brush.pixel(img, Vector2i(x, 4), accent.lightened(0.25))
	# Two shelves, the upper one served and the lower one stock.
	Brush.slab(img, spec, Rect2i(1, 9, w - 2, 3), 0.86)
	Brush.slab(img, spec, Rect2i(1, 21, w - 2, 3), 0.72)
	# The decanter: a squat body, a neck and a stopper, filled two thirds.
	for y in range(2, 9):
		for x in range(5, 11):
			var narrow := y < 5 and (x < 7 or x > 8)
			if narrow:
				continue
			var c := WHISKY if y > 5 else WHISKY_LIT
			if x == 5:
				c = c.lightened(0.30)
			elif x == 10:
				c = c.darkened(0.30)
			Brush.pixel(img, Vector2i(x, y), c)
	for x in range(6, 10):
		Brush.pixel(img, Vector2i(x, 1), Brush.shade(spec, 0.94))
	Brush.pixel(img, Vector2i(5, 5), Brush.shade(spec, 0.98))
	# Two tumblers beside it, poured and not yet drunk.
	for at: Vector2i in [Vector2i(13, 5), Vector2i(18, 6)]:
		for y in 4:
			for x in 4:
				var c := Brush.shade(spec, 0.98 if x == 0 else 0.70)
				if y >= 2:
					c = WHISKY.lightened(0.1 if x == 0 else 0.0)
				Brush.pixel(img, at + Vector2i(x, y), c)
		Brush.pixel(img, at + Vector2i(1, 0), Brush.shade(spec, 0.40))
	# The stock on the lower shelf: three bottles, unopened, in the dark green
	# every bottle in the world is.
	for at_x: int in [4, 10, 16]:
		for y in range(14, 21):
			for x in range(at_x, at_x + 4):
				if y < 17 and (x == at_x or x == at_x + 3):
					continue
				Brush.pixel(img, Vector2i(x, y), Brush.PCB.darkened(
					0.45 if x > at_x + 1 else 0.15))
	# Castors, and they are what say a trolley rather than a sideboard.
	for at_x: int in [4, w - 7]:
		for x in 3:
			Brush.pixel(img, Vector2i(at_x + x, 25), Brush.shade(spec, 0.12))
			Brush.pixel(img, Vector2i(at_x + x, 26), Brush.shade(spec, 0.20))
	for x in range(2, w - 2):
		Brush.pixel(img, Vector2i(x, 27), Brush.shade(spec, 0.08))
	return img
