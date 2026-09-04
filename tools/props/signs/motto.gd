extends RefCounted
## The gym's poster, and the joke is the correction: DESIGN.md wants TALK IT OUT
## crossed out with GLOVE IT OUT written under it. So the strike-through is
## drawing code rather than a character in the font - a line through the first
## line of TEXT, at the height the glyphs sit at.
##
## Printed and framed like the studio's poster, because somebody in this company
## had it made.

const Brush := preload("../_brush.gd")

## The first line is the one that gets struck out; anything after it is the
## amendment.
const TEXT := ["TALK IT OUT", "GLOVE IT OUT"]
const SIZE := Vector2i(80, 40)
const BLOCKS := Vector2.ZERO
const PIN := Vector2i(0, 0)


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var art := SIZE
	var ink: Color = Color(spec["accent"])
	# Paper, with a printed border - the same construction as the poster, so
	# the two read as things the same office printed.
	for y in art.y:
		for x in art.x:
			var edge := x < 2 or y < 2 or x >= art.x - 2 or y >= art.y - 2
			Brush.pixel(img, Vector2i(x, y),
				ink.darkened(0.55) if edge else Brush.PAPER)
	Brush.ring(img, Rect2i(0, 0, art.x, art.y), ink.darkened(0.7))
	Brush.text(img, TEXT[0], Vector2i(0, 9), Brush.INK.lightened(0.35), art.x)
	Brush.text(img, TEXT[1], Vector2i(0, 24), Brush.INK, art.x)
	# The correction: one hand-drawn stroke through the first line, in the
	# accent so it reads as somebody's marker rather than as print.
	for x in range(7, art.x - 7):
		var y := 12 + int(round(sin(float(x) * 0.09) * 1.4))
		Brush.pixel(img, Vector2i(x, y), ink)
		Brush.pixel(img, Vector2i(x, y + 1), ink.darkened(0.3))
	return img
