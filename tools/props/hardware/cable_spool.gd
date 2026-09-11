extends RefCounted
## A drum of cable stood on its rim, with the end trailing off. Round, which is
## most of why it is here: everything else on this floor is a box.

const Brush := preload("../_brush.gd")

const SIZE := Vector2i(20, 18)
const BLOCKS := Vector2(16, 6)


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var centre := Vector2(9.5, 8.5)
	for y in 18:
		for x in 20:
			var d := Vector2(x, y).distance_to(centre)
			if d > 8.6:
				continue
			var t := 0.44
			if d > 7.4:
				t = Brush.OUTLINE                       # rim
			elif d > 6.2:
				t = 0.66                          # flange
			elif d > 2.4:
				# Coiled cable, banded so it reads as wound rather than solid.
				t = 0.16 if int(d) % 2 == 0 else 0.30
			else:
				t = 0.52                          # hub
			Brush.pixel(img, Vector2i(x, y), Brush.shade(spec, t))
	# The loose end nobody coiled back up.
	for step in 6:
		Brush.pixel(img, Vector2i(16 + step / 2, 12 + step), Brush.shade(spec, 0.10))
	return img
