extends RefCounted
## A camera on a tripod, still standing where the last shoot left it. Taller
## than a character on purpose - it is set to eye height, and the height is
## most of what makes the media half read as a place things get filmed rather
## than a place with nicer monitors.
##
## Legs rather than a box: everything else standing on this floor is a
## rectangle, and a splayed tripod is the one silhouette in the catalogue that
## is mostly air.

const Brush := preload("../_brush.gd")

const SIZE := Vector2i(22, 34)
## Only the feet block - the same base-only rule every solid prop follows, so
## the player passes behind the legs and Y-sorting draws the two in order.
const BLOCKS := Vector2(14, 6)


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var dark: Color = Brush.shade(spec, 0.12)
	# Three legs from the head down, the middle one shortest so the rig reads
	# as standing towards the viewer.
	for leg in [[2, 33], [11, 31], [19, 33]]:
		var foot_x: int = leg[0]
		var foot_y: int = leg[1]
		for step in range(0, foot_y - 13):
			var t := float(step) / float(foot_y - 14)
			var x: int = int(round(lerp(11.0, float(foot_x), t)))
			Brush.pixel(img, Vector2i(x, 14 + step), dark)
			Brush.pixel(img, Vector2i(x + 1, 14 + step), Brush.shade(spec, 0.44))
	# The centre column and the tilt head it swivels on.
	for y in range(11, 16):
		Brush.row(img, spec, y, 9, 13, 0.30)
	Brush.pixel(img, Vector2i(8, 13), dark)
	Brush.pixel(img, Vector2i(13, 13), dark)
	# The body, with the lens pointing into the room.
	var body := Rect2i(3, 1, 16, 10)
	Brush.panel(img, spec, body, 0.26)
	Brush.slab(img, spec, Rect2i(5, 0, 12, 3), 0.62)
	var lens := Rect2i(1, 4, 5, 5)
	Brush.fill(img, spec, lens, 0.10)
	Brush.outline(img, spec, lens)
	Brush.pixel(img, Vector2i(2, 5), Brush.shade(spec, 0.96))
	Brush.pixel(img, Vector2i(3, 6), Brush.shade(spec, 0.72))
	# The flipped-out screen on the far side, and the light that says it is
	# still rolling because nobody came back to stop it.
	var screen := Rect2i(14, 3, 5, 6)
	for y in screen.size.y:
		for x in screen.size.x:
			Brush.pixel(img, screen.position + Vector2i(x, y), Brush.SCREEN)
	Brush.pixel(img, Vector2i(16, 5), Color(spec["accent"]))
	Brush.pixel(img, Vector2i(17, 6), Color(spec["accent"]).darkened(0.4))
	Brush.outline(img, spec, screen)
	Brush.pixel(img, Vector2i(4, 2), Brush.LED_BAD)
	return img
