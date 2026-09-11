extends RefCounted
## The dolly track: two rails and the sleepers between them, laid on the studio
## floor. The third thing on the markings shelf, and it keeps that shelf's two
## rules for the same two reasons - it blocks nothing, and it pins its TOP-LEFT
## corner so Y-sorting draws it before everybody walking over it. Pinned at its
## foot the crew would be standing under their own track.
##
## Unlike the rug and the boxing ring, this marking is not decoration: it is a
## promise. game/levels/dolly.gd runs a rig from one end of it to the other
## while a take is rolling, and the whole reason the track is drawn at all is
## that a moving hazard has to be legible before it arrives. A player who can
## see the lane times it; a player who cannot is being hit by something
## off-screen. So the rail's job is to be visible from anywhere in the room, and
## it is the one marking drawn BRIGHTER than the floor rather than darker.
##
## Its length and position are authored to match the dolly's `from` and `to` in
## the same biome file. Nothing checks that they agree - the rail is art and the
## travel is behaviour - so they are written next to each other and commented as
## a pair.

const Brush := preload("../_brush.gd")

## The studio's west half: long enough to carry the rig across the set and its
## two overlapping drain fields, and stopping well short of the door lane.
const SIZE := Vector2i(188, 8)
const BLOCKS := Vector2.ZERO
const PIN := Vector2i(0, 0)

## Where the two rails sit in the 8px band. Four pixels apart is the widest
## gauge that still reads as one track rather than as two lines painted on the
## floor.
const NEAR := 5
const FAR := 1

## A sleeper every twelve pixels. Close enough that the track reads as track at
## a glance, far enough apart that the gaps still show the floor between them -
## a solid bar would be a stripe, not a rail.
const SLEEPER_STEP := 12


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	# Sleepers first, so the rails lie ON them: they are the dark thing and the
	# rails are the polished thing, which is the only cue at this size that says
	# which of the two the wheels run on.
	for x in range(2, SIZE.x - 2, SLEEPER_STEP):
		for step in 2:
			for y in range(FAR, NEAR + 2):
				Brush.pixel(img, Vector2i(x + step, y), Brush.shade(spec, 0.16))
	# The two rails. The near one is brighter than the far one for the same
	# reason every body in this game is lit from the left and above: the room
	# has a light direction and a flat pair of lines would be the one thing in
	# it that does not.
	for pair in [[FAR, 0.62], [NEAR, 0.86]]:
		var y: int = pair[0]
		var tone: float = pair[1]
		Brush.row(img, spec, y, 0, SIZE.x, tone)
		Brush.row(img, spec, y + 1, 0, SIZE.x, tone - 0.44)
	# End stops, which is the detail that makes it a track with two ends rather
	# than a track running out of the picture. Both ends, because both are
	# inside the room.
	for at: int in [0, SIZE.x - 3]:
		for x in range(at, at + 3):
			for y in range(FAR, NEAR + 2):
				Brush.pixel(img, Vector2i(x, y), Brush.shade(spec, 0.30))
		for y in range(FAR, NEAR + 2):
			Brush.pixel(img, Vector2i(at if at == 0 else at + 2, y),
				Brush.shade(spec, Brush.OUTLINE))
	# A strip of gaffer tape at the parked end, in the room's own accent: the
	# mark the rig gets pushed back to between takes, and the only spot on the
	# track that means something to somebody standing on it.
	var tape := Color(spec["accent"])
	for x in range(6, 14):
		Brush.pixel(img, Vector2i(x, FAR - 1), tape)
		Brush.pixel(img, Vector2i(x, NEAR + 2), tape)
	return img
