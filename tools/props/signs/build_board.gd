extends RefCounted
## The screen on the wall that tells the floor whether the build is passing. It
## is not. Under the word is the run history, one square per build, and the red
## ones have been red for a while.
##
## The call floor's `wallboard` counts calls in red and this counts builds in
## red, which is deliberate: a lit board on a wall is how a company tells a
## whole room something it would rather not say out loud, and each floor gets
## its own number to be unhappy about.

const Brush := preload("../_brush.gd")

const TEXT := ["BUILD", "FAILED"]
const SIZE := Vector2i(56, 34)
const BLOCKS := Vector2.ZERO
const PIN := Vector2i(0, 0)

## The last twelve runs, oldest first. It went red on the fourth and nobody has
## fixed it since - which is the joke, and it is told in twelve pixels.
const HISTORY := [true, true, true, false, false, true, false, false,
	false, false, false, false]


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var art := SIZE
	Brush.panel(img, spec, Rect2i(0, 0, art.x, art.y), 0.28)
	var face := Rect2i(3, 3, art.x - 6, art.y - 6)
	for y in face.size.y:
		for x in face.size.x:
			Brush.pixel(img, face.position + Vector2i(x, y), Brush.SCREEN)
	Brush.ring(img, face, Brush.shade(spec, 0.10))
	for y in range(4, art.y - 4, 3):
		for x in range(4, art.x - 4):
			Brush.pixel(img, Vector2i(x, y), Brush.SCREEN.lightened(0.10))
	Brush.text(img, TEXT[0], Vector2i(0, 6), Color(spec["accent"]).lightened(0.2),
		art.x)
	Brush.text(img, TEXT[1], Vector2i(0, 15), Brush.LED_BAD, art.x)
	# The history strip: two pixels per run, green where it passed.
	var x0: int = (art.x - HISTORY.size() * 3) / 2
	for i in HISTORY.size():
		var passed: bool = HISTORY[i]
		for y in range(24, 27):
			for x in range(0, 2):
				Brush.pixel(img, Vector2i(x0 + i * 3 + x, y),
					Brush.LED_OK.darkened(0.2) if passed else Brush.LED_BAD)
	return img
