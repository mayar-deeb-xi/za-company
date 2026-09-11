extends RefCounted
## The filter machine, and the second thing in the catalogue whose colour is not
## the room's: coffee reads as coffee on every floor, the same argument that
## fixes the cooler's water. Where the cooler is what a lobby puts out for
## visitors, this is what a floor keeps for itself.

const Brush := preload("../_brush.gd")

## Brewed, and stewed - it has been on the plate since the morning.
const COFFEE := Color("40251a")
const COFFEE_LIT := Color("6b4128")

const SIZE := Vector2i(20, 26)
const BLOCKS := Vector2(16, 6)


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var accent := Color(spec["accent"])
	# The body: a tall back with the water tank in it, stepped forward at the
	# bottom to make the plate the carafe stands on.
	Brush.panel(img, spec, Rect2i(3, 0, 14, 14), 0.38)
	Brush.slab(img, spec, Rect2i(2, 13, 16, 3), 0.80)
	Brush.panel(img, spec, Rect2i(1, 15, 18, 9), 0.30)
	# Water level down the back, and the light that says it is still on.
	for y in range(3, 11):
		Brush.pixel(img, Vector2i(5, y), Brush.shade(spec, 0.92))
		Brush.pixel(img, Vector2i(6, y), Brush.shade(spec, 0.66))
	Brush.pixel(img, Vector2i(14, 4), Brush.LED_BAD)
	Brush.pixel(img, Vector2i(12, 4), accent)
	# The carafe: glass sides, coffee in the bottom two thirds, and a handle.
	var glass := Rect2i(4, 16, 11, 7)
	Brush.outline(img, spec, glass)
	for y in range(17, 22):
		for x in range(5, 14):
			var c := COFFEE if y > 17 else COFFEE_LIT
			if x == 5:
				c = c.lightened(0.25)
			elif x >= 13:
				c = c.darkened(0.25)
			Brush.pixel(img, Vector2i(x, y), c)
	for y in range(17, 21):
		Brush.pixel(img, Vector2i(15, y), Brush.shade(spec, 0.22))
	# The hot plate under it, and the two cups nobody has taken back.
	for x in range(3, 17):
		Brush.pixel(img, Vector2i(x, 23), Brush.shade(spec, 0.14))
	for cup in [Vector2i(1, 20), Vector2i(17, 21)]:
		for y in 3:
			for x in 3:
				Brush.pixel(img, cup + Vector2i(x, y),
					Brush.shade(spec, 0.96 if x == 0 else 0.74))
	for x in range(2, 18):
		Brush.pixel(img, Vector2i(x, 25), Brush.shade(spec, 0.10))
	return img
