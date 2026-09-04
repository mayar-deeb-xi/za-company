extends RefCounted
## The welcome banner, hung by the top-left corner: DESIGN.md wants it sagging
## off one nail, so the cloth is drawn square and the LEVEL rotates the instance
## about that corner. The bottom edge sags on its own so a tilted banner still
## looks like cloth rather than a rotated rectangle.

const Brush := preload("../_brush.gd")

## A sign has no ground to be in scale with, so it stays as big as it needs to
## be to be read across a room. TEXT is data so a floor can put up its own
## words without a new painter.
const TEXT := ["WELCOME", "NEW HIRES"]
const SIZE := Vector2i(66, 32)
const BLOCKS := Vector2.ZERO
## Hangs by this corner: rotating the instance swings the cloth off its nail.
const PIN := Vector2i(0, 0)


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var art := SIZE
	var cloth: Color = Color(spec["accent"]).darkened(0.25)
	var hem: Color = Color(spec["accent"]).lightened(0.25)
	var edge: Color = Color(spec["accent"]).darkened(0.7)
	for x in art.x:
		# Sags towards the unsupported end, deepest about three quarters along.
		var t := float(x) / float(art.x - 1)
		var bottom := 22 + int(round(sin(t * PI * 0.85) * 6.0))
		for y in range(0, bottom):
			var c := cloth
			if y <= 1:
				c = hem
			elif y >= bottom - 2:
				c = edge
			img.set_pixel(x, y, c)
		img.set_pixel(x, 0, edge)
	# The nail it hangs from, and the only one.
	for y in 3:
		for x in 3:
			img.set_pixel(x + 1, y + 1, Brush.shade(spec, Brush.OUTLINE))
	for i in TEXT.size():
		Brush.text(img, TEXT[i], Vector2i(0, 5 + i * 8), hem.lightened(0.6), art.x)



	return img
