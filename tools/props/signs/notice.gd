extends RefCounted
## A sheet of paper taped up, which is how a company actually communicates that
## something is broken. Deliberately not cloth: it is the cheap, temporary,
## nobody-is-coming version of the lobby's banner.

const Brush := preload("../_brush.gd")

const TEXT := ["OUT OF", "ORDER"]
const SIZE := Vector2i(46, 24)
const BLOCKS := Vector2.ZERO
const PIN := Vector2i(0, 0)


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var art := SIZE
	for y in range(2, art.y):
		for x in art.x:
			img.set_pixel(x, y, Brush.PAPER if y < art.y - 1 else Brush.PAPER.darkened(0.25))
	Brush.ring(img, Rect2i(0, 2, art.x, art.y - 2), Brush.INK.lightened(0.35))
	# Two strips of tape, and only two, at the top corners.
	var tape: Color = Color(spec["accent"]).lightened(0.15)
	for strip in [0, art.x - 9]:
		for y in 4:
			for x in 9:
				img.set_pixel(strip + x, y, tape if y > 0 else tape.darkened(0.3))
	for i in TEXT.size():
		Brush.text(img, TEXT[i], Vector2i(0, 8 + i * 8), Brush.INK, art.x)


	return img
