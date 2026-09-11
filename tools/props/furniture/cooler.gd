extends RefCounted
## The water cooler, and the one prop whose colour is not the room's: water has
## to read as water on every floor, the same rule as fire and hearts.

const Brush := preload("../_brush.gd")

## Water has no biome: it is the same blue on every floor.
const WATER := Color("6cc0e8")
const WATER_LIT := Color("a8dcf5")
const WATER_DARK := Color("2f7fa8")

const SIZE := Vector2i(16, 22)
const BLOCKS := Vector2(12, 6)


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	# Bottle: lit from the left like everything else, with the level showing.
	for y in range(1, 10):
		for x in range(4, 12):
			var c := WATER
			if x <= 5:
				c = WATER_LIT
			elif x >= 10:
				c = WATER_DARK
			if y <= 2:
				c = c.lerp(WATER_LIT, 0.5)   # the air gap at the top
			img.set_pixel(x, y, c)
	Brush.ring(img, Rect2i(4, 1, 8, 9), WATER_DARK.darkened(0.45))
	for y in range(10, 12):
		for x in range(6, 10):
			img.set_pixel(x, y, WATER_DARK)
	Brush.slab(img, spec, Rect2i(1, 11, 14, 4), 0.86)
	Brush.panel(img, spec, Rect2i(2, 14, 12, 8), 0.42)
	# Spigot and a drip tray under it.
	for y in range(16, 19):
		Brush.row(img, spec, y, 7, 9, Brush.OUTLINE)
	Brush.pixel(img, Vector2i(6, 16), Color(spec["accent"]))
	Brush.pixel(img, Vector2i(10, 16), WATER)
	for x in range(4, 12):
		Brush.pixel(img, Vector2i(x, 20), Brush.shade(spec, 0.20))
	return img
