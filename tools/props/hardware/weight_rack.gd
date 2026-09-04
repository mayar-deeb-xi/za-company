extends RefCounted
## A rack of dumbbells: two shelves, six pairs, none of them put back in order.
## The prop that fills a gym wall without taking floor off the arena.

const Brush := preload("../_brush.gd")

const SIZE := Vector2i(44, 26)
const BLOCKS := Vector2(40, 7)


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var w: int = SIZE.x
	# The frame: two uprights and the two shelves between them.
	Brush.panel(img, spec, Rect2i(1, 4, 3, 22), 0.34)
	Brush.panel(img, spec, Rect2i(w - 4, 4, 3, 22), 0.26)
	for shelf in [10, 22]:
		Brush.slab(img, spec, Rect2i(2, shelf, w - 4, 3), 0.64)
	# The dumbbells, biggest at the left of the bottom shelf, and one on the
	# top row missing because it is on the floor somewhere.
	for row in 2:
		var y := 5 + row * 12
		for i in 5:
			if row == 0 and i == 3:
				continue
			var x := 5 + i * 7
			var half := 3 - row              # the top shelf holds the light ones
			for dy in range(0, 5):
				for dx in range(0, 6):
					var head := dx < 2 or dx > 3
					if head and dy > half + 1:
						continue
					if not head and (dy == 0 or dy > half):
						continue
					Brush.pixel(img, Vector2i(x + dx, y + dy),
						Brush.shade(spec, 0.16 if head else 0.72))
	return img
