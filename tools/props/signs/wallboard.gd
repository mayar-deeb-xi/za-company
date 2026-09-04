extends RefCounted
## The call floor's wallboard: a lit board on the wall that tells the whole room,
## all day, exactly how far behind it is. The floor's joke in one prop - and the
## reason the pixel font learned digits.
##
## The number is red rather than the biome's accent, on the same argument that
## makes a rack's one bad light red: a number the room would rather not look at
## has to read as wrong at a glance, in any palette.

const Brush := preload("../_brush.gd")

## Two labels and the figure under them. Seven characters is the widest line
## the board holds at 5x5.
const TEXT := ["CALLS", "WAITING"]
const FIGURE := "142"
const SIZE := Vector2i(58, 40)
const BLOCKS := Vector2.ZERO
const PIN := Vector2i(0, 0)


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var art := SIZE
	# Housing, then the dark face inside it - the same dead-screen dark every
	# monitor in the catalogue uses, so a board that is ON reads as the one
	# lit thing in a dark frame.
	Brush.panel(img, spec, Rect2i(0, 0, art.x, art.y), 0.30)
	var face := Rect2i(3, 3, art.x - 6, art.y - 6)
	for y in face.size.y:
		for x in face.size.x:
			Brush.pixel(img, face.position + Vector2i(x, y), Brush.SCREEN)
	Brush.ring(img, face, Brush.shade(spec, 0.10))
	# Scanline texture, one row in three, which is what stops 50 px of dark
	# from reading as a hole in the wall.
	for y in range(4, art.y - 4, 3):
		for x in range(4, art.x - 4):
			Brush.pixel(img, Vector2i(x, y), Brush.SCREEN.lightened(0.10))
	var label: Color = Color(spec["accent"]).lightened(0.20)
	for i in TEXT.size():
		Brush.text(img, TEXT[i], Vector2i(0, 7 + i * 8), label, art.x)
	Brush.text(img, FIGURE, Vector2i(0, 25), Brush.LED_BAD, art.x)
	# The figure sits in its own glow, so the eye lands on it and not on the
	# words above it.
	for x in range(14, art.x - 14):
		Brush.pixel(img, Vector2i(x, 23), Brush.LED_BAD.darkened(0.65))
		Brush.pixel(img, Vector2i(x, 32), Brush.LED_BAD.darkened(0.65))
	return img
