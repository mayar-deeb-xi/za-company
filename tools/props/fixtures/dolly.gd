extends RefCounted
## FIXTURE, not a catalogue prop - see column.gd. The level places this itself
## from its biome's `dolly` key, the same way it places the hazard, because what
## it is is a hazard: game/levels/dolly.gd runs it up and down the rail while a
## take is rolling.
##
## ## It is deliberately not the camera rig
##
## hardware/camera_rig.gd is the same instrument on a tripod, and that prop's
## whole silhouette is AIR - three splayed legs, the one thing in the catalogue
## that is mostly nothing. This is the opposite on purpose: a low, solid,
## wheeled box. The player has to be able to tell at a glance which of the two
## cameras in this room is going to run them over, and at 24 px the reliable
## difference between two objects is their outline, not their detail.
##
## ## The wheels are the tell
##
## Four of them, in the room's darkest metal, sitting right on the pin so they
## land on the rail the biome paints under them. Everything above them can be
## read as scenery; wheels on a track cannot.

const Brush := preload("../_brush.gd")

const SIZE := Vector2i(24, 30)
## The pin sits one row above the bottom so the wheels meet the rail's near
## line rather than hovering over it: the rail is 8 px of floor and the rig has
## to be ON it, which is the only part of this drawing anybody will check.
const PIN := Vector2i(12, 29)

## The red light that says it is still rolling, matching camera_rig.gd's - the
## same joke twice, because nobody came back to stop either of them.
const TALLY := Vector2i(6, 2)


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var dark: Color = Brush.shade(spec, 0.10)

	# The head: body, hood and the lens pointing into the room. Same three
	# pieces the tripod rig has, so the two read as the same instrument.
	Brush.panel(img, spec, Rect2i(4, 1, 15, 10), 0.26)
	Brush.slab(img, spec, Rect2i(6, 0, 11, 3), 0.62)
	var lens := Rect2i(1, 4, 5, 5)
	Brush.fill(img, spec, lens, 0.10)
	Brush.outline(img, spec, lens)
	Brush.pixel(img, Vector2i(2, 5), Brush.shade(spec, 0.96))
	Brush.pixel(img, Vector2i(3, 6), Brush.shade(spec, 0.72))
	# The flipped-out monitor, with the accent glowing on it.
	var screen := Rect2i(14, 3, 4, 6)
	for y in screen.size.y:
		for x in screen.size.x:
			Brush.pixel(img, screen.position + Vector2i(x, y), Brush.SCREEN)
	Brush.pixel(img, Vector2i(15, 5), Color(spec["accent"]))
	Brush.pixel(img, Vector2i(16, 6), Color(spec["accent"]).darkened(0.4))
	Brush.outline(img, spec, screen)
	Brush.pixel(img, TALLY, Brush.LED_BAD)

	# The column down to the platform, and the collar that says it telescopes.
	for y in range(11, 17):
		Brush.row(img, spec, y, 9, 14, 0.34)
		Brush.pixel(img, Vector2i(9, y), Brush.shade(spec, 0.70))
		Brush.pixel(img, Vector2i(13, y), dark)
	Brush.row(img, spec, 14, 8, 15, 0.66)

	# The push bar the crew steers it by, off the back corner. It is the one
	# thing on this prop that is not on the tripod rig, and it is what says
	# somebody moves this rather than it standing where it was set down.
	for y in range(9, 18):
		Brush.pixel(img, Vector2i(21, y), Brush.shade(spec, 0.54))
		Brush.pixel(img, Vector2i(22, y), dark)
	Brush.row(img, spec, 9, 18, 23, 0.72)
	Brush.row(img, spec, 10, 18, 23, 0.24)

	# The platform: wide, flat and low, and the widest thing in the drawing, so
	# the whole silhouette reads as a base on wheels.
	Brush.slab(img, spec, Rect2i(0, 17, 24, 6), 0.44)

	# Four wheels on the track. Dark, because they are the part that is in
	# contact with the floor and everything in this game gets darker as it
	# reaches the ground.
	for at: int in [2, 7, 14, 19]:
		var wheel := Rect2i(at, 23, 3, 5)
		Brush.fill(img, spec, wheel, 0.18)
		Brush.outline(img, spec, wheel)
		Brush.pixel(img, Vector2i(at, 24), Brush.shade(spec, 0.52))
	# The shadow it casts on the rail, which is what stops a dark box on a dark
	# floor from reading as a hole in it.
	for x in range(1, 23):
		var shadow: Color = Brush.shade(spec, 0.04)
		shadow.a = 0.55
		Brush.pixel(img, Vector2i(x, 28), shadow)
	return img
