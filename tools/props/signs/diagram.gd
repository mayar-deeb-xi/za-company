extends RefCounted
## The whiteboard on the innovation lab, and the joke is not written on it - it is
## DRAWN on it. Four boxes, some arrows between them, one arrow that goes back
## where it came from, and DO NOT ERASE along the bottom in red, which is the
## note every whiteboard in every engineering office in the world carries.
##
## Same board construction as `whiteboard`, different content: that one is
## lettering and this one is a diagram, so the boxes and arrows are code here
## rather than a `TEXT` constant.

const Brush := preload("../_brush.gd")

## The one line of text on it, and it is an instruction rather than a message.
const TEXT := "DO NOT ERASE"
const SIZE := Vector2i(80, 46)
const BLOCKS := Vector2.ZERO
const PIN := Vector2i(0, 0)

## A whiteboard is white in every room, the same argument that fixes paper.
const BOARD := Color("f7f8fa")
const SHADOW := Color("cdd0d6")

## Boxes: x, y, w, h inside the board. Three services and a database, laid out
## the way anybody lays them out on a wall - left to right, and then one below
## because the wall ran out.
const BOXES := [
	Rect2i(6, 6, 16, 9),
	Rect2i(30, 6, 16, 9),
	Rect2i(54, 6, 16, 9),
	Rect2i(30, 21, 16, 9),
]


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var art := SIZE
	var marker: Color = Color(spec["accent"]).darkened(0.10)
	Brush.panel(img, spec, Rect2i(0, 0, art.x, art.y), 0.52)
	var board := Rect2i(3, 3, art.x - 6, art.y - 9)
	for y in board.size.y:
		for x in board.size.x:
			var c := BOARD if y < board.size.y - 3 else BOARD.lerp(SHADOW, 0.5)
			Brush.pixel(img, board.position + Vector2i(x, y), c)
	Brush.ring(img, board, SHADOW.darkened(0.35))
	for box: Rect2i in BOXES:
		Brush.ring(img, box, marker)
		# A word inside each, at this size, is a line of scribble.
		for x in range(box.position.x + 3, box.position.x + box.size.x - 3):
			Brush.pixel(img, Vector2i(x, box.position.y + 4), marker.lightened(0.35))
	# Arrows along the top row, left to right.
	for gap in [Vector2i(22, 30), Vector2i(46, 54)]:
		var y := 10
		for x in range(gap.x, gap.y):
			Brush.pixel(img, Vector2i(x, y), marker)
		Brush.pixel(img, Vector2i(gap.y - 2, y - 1), marker)
		Brush.pixel(img, Vector2i(gap.y - 2, y + 1), marker)
	# And the one that goes back up into the box it came out of, which is the
	# part of every diagram nobody can explain.
	for y in range(15, 21):
		Brush.pixel(img, Vector2i(38, y), marker)
	for x in range(46, 62):
		Brush.pixel(img, Vector2i(x, 25), marker)
	for y in range(15, 26):
		Brush.pixel(img, Vector2i(62, y), marker)
	Brush.pixel(img, Vector2i(61, 16), marker)
	Brush.pixel(img, Vector2i(63, 16), marker)
	# The instruction, in the red pen, under the lot of it.
	Brush.text(img, TEXT, Vector2i(0, 33), Brush.LED_BAD.darkened(0.25), art.x)
	# The pens in the tray.
	for pen in [[52, marker], [60, Brush.LED_BAD.darkened(0.25)]]:
		var x0: int = pen[0]
		var c: Color = pen[1]
		for x in range(x0, x0 + 7):
			Brush.pixel(img, Vector2i(x, art.y - 4), c)
			Brush.pixel(img, Vector2i(x, art.y - 3), c.darkened(0.4))
	return img
