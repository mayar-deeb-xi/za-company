extends RefCounted
## A punch bag on a chain. Shelved with the hardware rather than the furniture
## because it is equipment: the same argument that puts the camera rig and the
## ring lights there.
##
## Hangs from the ceiling, so unlike everything else in the catalogue its art
## reaches the TOP of its canvas and its foot is the bag's bottom, swinging
## clear of the floor. What it blocks is that bottom, which is the only part of
## it anybody walks into.

const Brush := preload("../_brush.gd")

const SIZE := Vector2i(18, 46)
const BLOCKS := Vector2(12, 6)


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var accent := Color(spec["accent"])
	# The chain, up to a ceiling this canvas does not show.
	for y in 10:
		Brush.pixel(img, Vector2i(8, y), Brush.shade(spec, 0.20 if y % 2 else 0.74))
		Brush.pixel(img, Vector2i(9, y), Brush.shade(spec, 0.62 if y % 2 else 0.16))
	# The swivel it hangs on.
	Brush.slab(img, spec, Rect2i(6, 9, 6, 3), 0.50)
	# The bag: vinyl, lit from the left, with the seam down one side and the
	# strapping at top and bottom.
	var body := Rect2i(2, 11, 14, 32)
	for y in range(body.position.y, body.position.y + body.size.y):
		for x in range(body.position.x, body.position.x + body.size.x):
			var t := 0.46
			if x <= 3:
				t = 0.70
			elif x >= 13:
				t = 0.22
			elif x == 6:
				t = 0.58
			var c := Brush.shade(spec, t).lerp(accent, 0.18)
			Brush.pixel(img, Vector2i(x, y), c)
	Brush.outline(img, spec, body)
	for y in [12, 13, 40, 41]:
		for x in range(3, 15):
			Brush.pixel(img, Vector2i(x, y), Brush.shade(spec, 0.14))
	# The worn patch at punching height, which is what says this one gets used.
	for y in range(22, 30):
		for x in range(5, 11):
			if (x + y) % 3 == 0:
				Brush.pixel(img, Vector2i(x, y), Brush.shade(spec, 0.30))
	# The shadow it swings over.
	for x in range(4, 14):
		Brush.pixel(img, Vector2i(x, 44), Brush.shade(spec, 0.12))
	for x in range(6, 12):
		Brush.pixel(img, Vector2i(x, 45), Brush.shade(spec, 0.06))
	return img
