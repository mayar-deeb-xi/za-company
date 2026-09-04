extends RefCounted
## The city, forty floors down, at night - and the first thing on the openings
## shelf, which exists because a window is not any of the other four things a
## prop can be. It is not furniture, hardware, a sign or paint on the floor: it
## is a hole cut through the building's shell, and shelving it as a sign
## because signs also hang on walls would make the catalogue lie about what it
## holds. The boxing ring opened `markings/` on exactly that argument.
##
## It runs 480 px unbroken, and it can only do that because the penthouse is
## the END of the chain: a level with a floor above it has a doorway cut
## through its north wall, and a panoramic window drawn across that doorway
## would glaze the way out. The first draft carried a 96 px hole for exactly
## that reason, and lost it the moment Khaled's office became the last room.
## Anything fitting this to a floor with a north door has to put the hole back.
##
## The sky and the city are fixed colours, like fire and hearts and coffee. A
## city at night does not take the palette of the room looking at it; only the
## frame and the sill do, which is what keeps the prop belonging to the floor
## it is fitted in.

const Brush := preload("../_brush.gd")

const SIZE := Vector2i(480, 64)
const BLOCKS := Vector2.ZERO
## Top-left, like the signs: it hangs at the wall line, so it sorts before
## everything standing in the room and everybody walks in front of it.
const PIN := Vector2i(0, 0)

## Where the glass starts and stops.
const HEAD := 4
const SILL := 57

## Night, from the top of the frame down to the haze over the streets.
const NIGHT_HIGH := Color("05070f")
const NIGHT_LOW := Color("2b2340")
## Two rows of towers: the far ones sit paler because there is more air in
## front of them, which is the only depth cue a 53 px sky has room for.
const TOWER_FAR := Color("171b2e")
const TOWER_NEAR := Color("0b0e1a")
## Lit offices. Most are warm, a few are the cold white of a floor somebody
## left the lights on in.
const LIT_WARM := Color("ffd98a")
const LIT_COLD := Color("bfe4ff")
## Aircraft warning lights, on the tall ones.
const BEACON := Color("ff5a4a")

## Eight posts, seven bays.
const MULLIONS := [0, 68, 136, 204, 272, 340, 408, 478]

## Fixed, so a regenerated window is the SAME window. The skyline is texture
## rather than composition - what matters is that it reads as a city, not which
## tower stands where - so it is rolled rather than listed, and the seed is
## what stops the roll from being a different city every time the level is
## rebuilt.
const SEED := 20260905


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var w: int = SIZE.x
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	# The sky, darkest at the top of the frame and hazing towards the streets.
	for y in range(HEAD, SILL):
		var t: float = float(y - HEAD) / float(SILL - HEAD - 1)
		var sky := NIGHT_HIGH.lerp(NIGHT_LOW, pow(t, 1.7))
		for x in w:
			Brush.pixel(img, Vector2i(x, y), sky)
	# Stars, in the top third where the haze has not eaten them.
	for i in 34:
		var at := Vector2i(rng.randi_range(0, w - 1),
			rng.randi_range(HEAD + 1, HEAD + 18))
		Brush.pixel(img, at, NIGHT_LOW.lightened(rng.randf() * 0.5 + 0.2))
	# Two rows of towers. The far row is drawn first and sits higher, so the
	# near row overlaps it and the skyline has a back to it.
	for row in 2:
		var body: Color = TOWER_FAR if row == 0 else TOWER_NEAR
		var base: int = SILL - 1 - (5 if row == 0 else 0)
		var at_x: int = -rng.randi_range(0, 9)
		var nth := 0
		while at_x < w:
			var bw: int = rng.randi_range(9, 27)
			var bh: int = rng.randi_range(13, 32 if row == 0 else 42)
			var top: int = maxi(base - bh, HEAD + 6)
			for y in range(top, base + 1):
				for x in range(at_x, at_x + bw):
					if x < 0 or x >= w:
						continue
					Brush.pixel(img, Vector2i(x, y),
						body.lightened(0.16) if x == at_x else body)
			# The lit floors, on a grid, because an office block's windows are
			# on a grid and a scatter of dots reads as noise instead.
			for y in range(top + 3, base - 1, 4):
				for x in range(at_x + 2, at_x + bw - 2, 3):
					if x < 0 or x >= w:
						continue
					if rng.randf() > (0.30 if row == 0 else 0.42):
						continue
					Brush.pixel(img, Vector2i(x, y),
						LIT_COLD if rng.randf() < 0.16 else LIT_WARM)
			if row == 1 and nth % 3 == 1 and top > HEAD + 8:
				var beacon: int = at_x + bw / 2
				if beacon >= 0 and beacon < w:
					Brush.pixel(img, Vector2i(beacon, top - 2), BEACON)
			at_x += bw + rng.randi_range(1, 5)
			nth += 1
	# The glow off the streets, under everything, which is what stops the
	# bottom of the city from ending in a hard line on the sill.
	for y in range(SILL - 4, SILL):
		for x in w:
			var haze := NIGHT_LOW
			haze.a = 0.16 * float(y - SILL + 5)
			Brush.pixel(img, Vector2i(x, y),
				img.get_pixel(x, y).lerp(haze, haze.a))
	# Diagonals lifted off the glass: the room, reflected. Without them the
	# city is a picture hung on the wall rather than something on the other
	# side of a pane.
	for from_x: int in [14, 190, 366]:
		for step in 110:
			for band in 2:
				var at := Vector2i(from_x + step + band, HEAD + step / 3)
				if at.x >= w or at.y >= SILL:
					continue
				Brush.pixel(img, at, img.get_pixel(at.x, at.y).lerp(
					Color(1, 1, 1, 1), 0.06))
	# The frame, and it is the only part of this prop in the room's own colours.
	for x in w:
		for y in HEAD:
			Brush.pixel(img, Vector2i(x, y), Brush.shade(spec, 0.86 - y * 0.22))
	Brush.slab(img, spec, Rect2i(0, SILL, w, 5), 0.74)
	Brush.panel(img, spec, Rect2i(0, SILL + 4, w, 3), 0.22)
	for at_x: int in MULLIONS:
		for y in range(0, SILL):
			Brush.pixel(img, Vector2i(at_x, y), Brush.shade(spec, 0.52))
			Brush.pixel(img, Vector2i(at_x + 1, y), Brush.shade(spec, 0.16))
	return img
