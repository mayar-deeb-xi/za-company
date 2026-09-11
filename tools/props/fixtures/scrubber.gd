extends RefCounted
## FIXTURE, not a catalogue prop - see column.gd. The level places it from its
## biome's `scrubbers` key, because what it is is a hazard: game/levels/
## scrubber.gd drives it around the room on no path at all.
##
## ## It is a disc, and that is a mechanical decision before an aesthetic one
##
## This is the only thing in the game that moves in an arbitrary direction. A
## camera dolly runs one axis and every character in the cast has three drawn
## facings and a flip; a machine that can be heading anywhere at all would need
## either a sheet per angle or a silhouette that does not care. So: round, low,
## symmetrical, and identical from every side.
##
## The one part that does have a direction is the scanner, and that is drawn
## LIVE by the script rather than baked here - which is also what lets it lead
## the body while the machine is deciding where to go next.
##
## ## Squashed, because the floor is
##
## 22 wide by 14 tall for a thing that is circular in plan: the room is looked
## down on at an angle, and a true circle reads as a ball standing up in it. The
## same squash markings/rug.gd puts on anything lying flat.

const Brush := preload("../_brush.gd")

const SIZE := Vector2i(22, 16)
## Wider than it is deep, like the shell: this is a thing you walk into rather
## than a thing you walk behind, so the box is nearly the whole footprint.
const BLOCKS := Vector2(18, 10)
## The bottom of the shell, not the bottom of the canvas - the two lowest rows
## are the shadow it sits in.
const PIN := Vector2i(11, 14)

## The bumper, in a fixed dark rather than the room's ramp. It is the part that
## hits people and it is the part the eye tracks, so it holds its edge whether
## the machine is on the hub's grey carpet or somewhere paler later.
const BUMPER := Color("1c1a22")
## The strip of brush under the front skirt. Not the biome's, because a brush
## the colour of the floor is a brush you cannot see is turning.
const BRISTLE := Color("6a6152")


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var mid := Vector2(10.5, 7.0)

	# The shell: an ellipse, lit from the left and above like everything else.
	for y in 14:
		for x in SIZE.x:
			var d := Vector2(float(x), float(y))
			var r := Vector2((d.x - mid.x) / 10.5, (d.y - mid.y) / 6.0).length()
			if r > 1.0:
				continue
			if r > 0.82:
				Brush.pixel(img, Vector2i(x, y), BUMPER)
				continue
			# Top face, brightest at the back-left shoulder where the light is.
			var lit := 0.62 - 0.30 * ((d.x - mid.x) / 21.0 + (d.y - mid.y) / 14.0)
			Brush.pixel(img, Vector2i(x, y), Brush.shade(spec, clampf(lit, 0.0, 1.0)))

	# The raised dome in the middle, which is what the scanner sits on and the
	# only thing that gives a flat disc any height at all.
	for y in range(4, 9):
		for x in range(7, 15):
			var r := Vector2((float(x) - mid.x) / 4.0,
				(float(y) - mid.y + 0.5) / 2.6).length()
			if r > 1.0:
				continue
			Brush.pixel(img, Vector2i(x, y),
				Brush.shade(spec, 0.86 if r < 0.55 else 0.34))
	# Its rim, so the dome reads as raised rather than as a pale patch.
	for at: Vector2i in [Vector2i(6, 6), Vector2i(15, 6), Vector2i(10, 3),
			Vector2i(11, 3), Vector2i(10, 9), Vector2i(11, 9)]:
		Brush.pixel(img, at, BUMPER)

	# The brush, showing under the skirt all the way round the front half. It is
	# the detail that says this machine is doing something to the floor rather
	# than merely crossing it.
	for x in range(4, 18):
		if (x + 1) % 3 == 0:
			continue
		Brush.pixel(img, Vector2i(x, 12), BRISTLE)
		Brush.pixel(img, Vector2i(x, 13), BRISTLE.darkened(0.45))

	# The shadow, keeping a dark disc off a dark carpet from reading as a hole
	# in it - the same job the dolly's shadow does.
	for x in range(3, 19):
		var shadow: Color = Brush.shade(spec, 0.04)
		shadow.a = 0.5 if x > 4 and x < 17 else 0.3
		Brush.pixel(img, Vector2i(x, 14), shadow)
	return img
