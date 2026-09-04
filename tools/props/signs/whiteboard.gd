extends RefCounted
## The call floor's wallboard, in marker, in somebody's handwriting-adjacent
## capitals. The words are the point: this is the sign a real call centre
## actually has up, and it is warm rather than mean - whoever wrote it meant it.
##
## A board rather than paper or cloth, so the three signs in the catalogue are
## three different objects: the banner is cloth off one nail, the notice is A4
## and tape, and this is screwed to the wall and stays there.

const Brush := preload("../_brush.gd")

## Eight characters is the widest line the board can hold at 5x5 - which is
## exactly why the line breaks fall where they do.
const TEXT := ["SMILE", "THEY CAN", "HEAR IT"]
const SIZE := Vector2i(58, 42)
const BLOCKS := Vector2.ZERO
## Pinned by its top-left corner like the other signs: a sign's position is
## where it is fixed to the wall, not where its foot would be.
const PIN := Vector2i(0, 0)

## A whiteboard is white in every room, the same argument that fixes paper.
const BOARD := Color("f7f8fa")
const SHADOW := Color("cdd0d6")


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var art := SIZE
	# Aluminium tray frame, in the room's own metal.
	Brush.panel(img, spec, Rect2i(0, 0, art.x, art.y), 0.52)
	var board := Rect2i(3, 3, art.x - 6, art.y - 9)
	for y in board.size.y:
		for x in board.size.x:
			# Faintly shaded towards the bottom, so 50 px of white is a surface
			# rather than a hole cut in the wall.
			var c := BOARD if y < board.size.y - 3 else BOARD.lerp(SHADOW, 0.5)
			Brush.pixel(img, board.position + Vector2i(x, y), c)
	Brush.ring(img, board, SHADOW.darkened(0.35))
	for i in TEXT.size():
		Brush.text(img, TEXT[i], Vector2i(0, 6 + i * 9), Brush.INK, art.x)
	# Underlined once, in the accent, because whoever wrote it wanted the first
	# word to land.
	var marker: Color = Color(spec["accent"]).darkened(0.15)
	for x in range(20, 38):
		Brush.pixel(img, Vector2i(x, 12), marker)
	# The pen itself, lying in the tray at the bottom.
	for x in range(38, 48):
		Brush.pixel(img, Vector2i(x, art.y - 4), marker)
		Brush.pixel(img, Vector2i(x, art.y - 3), marker.darkened(0.4))
	Brush.pixel(img, Vector2i(48, art.y - 4), Brush.shade(spec, 0.90))
	return img
