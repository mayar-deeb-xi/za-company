extends RefCounted
## The media half's wall poster. Printed, mounted, four tacks - the opposite of
## the notice taped up downstairs, because this team owns a printer that works
## and cares what the wall looks like.

const Brush := preload("../_brush.gd")

const TEXT := ["FIX IT", "IN POST"]
const SIZE := Vector2i(50, 32)
const BLOCKS := Vector2.ZERO
const PIN := Vector2i(0, 0)


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var art := SIZE
	var ink: Color = Color(spec["accent"]).darkened(0.35)
	var bright: Color = Color(spec["accent"]).lightened(0.45)
	# Full-bleed accent with a white margin inside it: a printed poster reads
	# as printed because of the margin, not because of the words.
	for y in art.y:
		for x in art.x:
			var edge := x < 2 or y < 2 or x >= art.x - 2 or y >= art.y - 2
			Brush.pixel(img, Vector2i(x, y), Brush.PAPER if edge else ink)
	Brush.ring(img, Rect2i(0, 0, art.x, art.y), ink.darkened(0.4))
	Brush.ring(img, Rect2i(2, 2, art.x - 4, art.y - 4), bright.darkened(0.2))
	for i in TEXT.size():
		Brush.text(img, TEXT[i], Vector2i(0, 8 + i * 9), bright, art.x)
	# Four tacks, one per corner, which is the difference between mounted and
	# stuck up in a hurry.
	for tack in [Vector2i(4, 4), Vector2i(art.x - 5, 4),
			Vector2i(4, art.y - 5), Vector2i(art.x - 5, art.y - 5)]:
		Brush.pixel(img, tack, Brush.shade(spec, 0.95))
		Brush.pixel(img, tack + Vector2i(0, 1), Brush.shade(spec, Brush.OUTLINE))
	return img
