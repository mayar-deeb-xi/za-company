extends RefCounted
## Two dead monitors stacked, the top one not squared up with the bottom. Their
## screens are the darkest thing in the room, which is what says they are off.

const Brush := preload("_brush.gd")

const SIZE := Vector2i(26, 26)
const BLOCKS := Vector2(22, 7)


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	# Beige plastic, not dark: the housings have to be the LIGHT part so the two
	# dead screens are the dark part. Drawn dark, a stack of monitors on a dim
	# brown floor is one brown blob.
	for box in [Rect2i(2, 13, 22, 13), Rect2i(5, 1, 18, 13)]:
		Brush.fill(img, spec, box, 0.62)
		Brush.outline(img, spec, box)
		var screen := Rect2i(box.position.x + 2, box.position.y + 2,
			box.size.x - 4, box.size.y - 5)
		for y in screen.size.y:
			for x in screen.size.x:
				Brush.pixel(img, screen.position + Vector2i(x, y), Brush.SCREEN)
		# The dull sheen of a screen with nothing behind it.
		for i in mini(screen.size.x, screen.size.y):
			Brush.pixel(img, screen.position + Vector2i(i + 1, i), Brush.SCREEN.lightened(0.22))
	Brush.pixel(img, Vector2i(20, 24), Brush.LED_BAD.darkened(0.55))
	return img
