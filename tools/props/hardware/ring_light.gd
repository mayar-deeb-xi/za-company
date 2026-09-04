extends RefCounted
## A ring light on its stand, switched on. The studio floor's furniture is its
## lighting, and this is the piece that says so: in a room this dark the ring is
## the brightest thing standing in it.
##
## The ring is drawn in fixed white rather than off the biome ramp, the same
## argument that fixes fire, water and foliage - a lamp that took the room's
## palette would be a lamp that is off. Everything holding it up is the room's
## own metal. Its fallen twin is the hazard on this floor, painted in
## fixtures/hazard.gd under "fallen_light".

const Brush := preload("../_brush.gd")

const SIZE := Vector2i(22, 42)
const BLOCKS := Vector2(12, 6)

## A light at full output, and the faint bloom around it. The bloom is real
## alpha rather than a lighter shade, so the ring reads as bright against a
## dark floor and a pale one alike.
const GLOW := Color("fffdf4")
const GLOW_WARM := Color("ffeec9")
const HALO := Color("fff3d6")

## The face of the ring, as fractions of its radius: outside 1.0 is bloom,
## between these two is the diffuser, inside is the hole you shoot through.
const RIM := 1.0
const BORE := 0.66


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var centre := Vector2(10.5, 11.0)
	var radius := 10.0
	for y in 23:
		for x in SIZE.x:
			var d := Vector2(float(x), float(y)).distance_to(centre) / radius
			if d > 1.30:
				continue
			if d > RIM:
				# Bloom: fades out over the last third of a radius.
				var bloom := HALO
				bloom.a = 0.30 * (1.0 - (d - RIM) / 0.30)
				Brush.pixel(img, Vector2i(x, y), bloom)
			elif d > BORE:
				# The diffuser, hottest at its inner edge and cooling towards
				# the housing, with the housing itself a dark ring outside it.
				var c := GLOW if d < 0.86 else GLOW_WARM
				if d > 0.96:
					c = Brush.shade(spec, 0.24)
				Brush.pixel(img, Vector2i(x, y), c)
	# The yoke it hangs in, the post, and the tripod under it. All of this is
	# the room's metal - only the light is not.
	for y in range(20, 24):
		Brush.row(img, spec, y, 9, 12, 0.30)
	for y in range(23, 37):
		Brush.pixel(img, Vector2i(9, y), Brush.shade(spec, 0.72))
		Brush.pixel(img, Vector2i(10, y), Brush.shade(spec, 0.44))
		Brush.pixel(img, Vector2i(11, y), Brush.shade(spec, 0.16))
	# A collar halfway down, which is what makes the post read as extendable
	# rather than as a drawn line.
	for y in range(29, 31):
		Brush.row(img, spec, y, 8, 13, 0.62 if y == 29 else 0.20)
	for leg in [[2, 41], [10, 39], [18, 41]]:
		var foot_x: int = leg[0]
		var foot_y: int = leg[1]
		for step in range(0, foot_y - 36):
			var t := float(step) / float(foot_y - 37)
			var x: int = int(round(lerp(10.0, float(foot_x), t)))
			Brush.pixel(img, Vector2i(x, 37 + step), Brush.shade(spec, 0.14))
			Brush.pixel(img, Vector2i(x + 1, 37 + step), Brush.shade(spec, 0.50))
	return img
