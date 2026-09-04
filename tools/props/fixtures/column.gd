extends RefCounted
## FIXTURE, not a catalogue prop - no SIZE or BLOCKS, because a level
## places its columns itself and build_levels.gd owns their scene shape.
## ---- the level's own fixtures ------------------------------------------
## Column, hazard and heal pickup. These are NOT catalogue props - a level
## places them itself, at its own fixed positions, and their scenes differ (a
## hazard is an Area2D on hazard_base.gd, a pickup one on pickup_base.gd, a
## column a plain StaticBody2D). Only their PAINTERS live here, and they live
## here for one reason: props.gd is now the single home for every picture of a
## thing a level puts on its floor, so build_biomes.gd is left owning exactly
## the room itself - its tiles and its doorways.
##
## Two of the three are per-biome STYLE choices rather than one look for the
## whole game, keyed off the biome dictionary. Every style keeps the same canvas
## size and the same foot, so the scene and collision box that wrap them never
## change - only the picture does.
## Architecture is per-biome style, chosen by the `column` key. There is exactly
## one reason for the split: the fluted classical column is most of what makes
## the marble hall read as a hall, and it is also most of what made the office
## lobby read as a temple. The office floors get a glazed pillar instead.

const Brush := preload("../_brush.gd")


static func paint(spec: Dictionary) -> Image:
	match spec.get("column", "classical"):
		"pillar":
			return _pillar(spec)
		"divider":
			return _divider(spec)
		_:
			return _classical_column(spec)




## A 16x48 glass-and-steel pillar: steel stiles either side of a glazed face,
## faintly tinted with the biome's accent the way a curtain wall is, capped top
## and bottom. Straight-sided, because a corporate lobby has no entasis.
static func _pillar(spec: Dictionary) -> Image:
	var height := 48
	var img := Image.create(Brush.TILE, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ramp: Array = spec["ramp"]
	var gamma: float = spec["gamma"]
	var accent := Color(spec["accent"])
	for y in range(3, 45):
		for x in range(1, 15):
			var t := 0.34                          # glazing
			if x == 1 or x == 14:
				t = 0.06                           # silhouette outline
			elif x == 2:
				t = 1.00                           # lit steel stile, light left
			elif x == 3:
				t = 0.78
			elif x == 13:
				t = 0.18                           # shaded stile
			elif x == 12:
				t = 0.30
			elif x == 5:
				t = 0.62                           # sheen down the glass
			var mullion := (y - 3) % 14 == 0 or y == 44
			if mullion:
				t = minf(t, 0.16)
			var c := Brush.ramp(ramp, t, gamma)
			if x >= 4 and x <= 11 and not mullion:
				c = c.lerp(accent, 0.20)
			img.set_pixel(x, y, c)
	# Cap and base plate, both a tile wide so the pillar reads as fixed to the
	# floor and the ceiling rather than floating in the room.
	for x in Brush.TILE:
		img.set_pixel(x, 0, Brush.ramp(ramp, 0.30, gamma))
		img.set_pixel(x, 1, Brush.ramp(ramp, 0.98, gamma))
		img.set_pixel(x, 2, Brush.ramp(ramp, 0.72, gamma))
		img.set_pixel(x, 45, Brush.ramp(ramp, 0.90, gamma))
		img.set_pixel(x, 46, Brush.ramp(ramp, 0.52, gamma))
		img.set_pixel(x, 47, Brush.ramp(ramp, 0.08, gamma))
	return img




## A 16x48 cubicle divider: fabric panel in a metal frame, on feet. DESIGN.md's
## "dividers as columns" for the open-plan floors - the same slot in the level
## that holds a pillar downstairs, because what a room uses to break up its
## floor is exactly what changes between a lobby and a bullpen.
##
## Shorter in the frame than the pillar and the column deliberately: a divider
## is something you see over, and drawing it floor-to-ceiling would wall the
## room off visually in a room that has to stay readable during a four-on-one
## fight.
static func _divider(spec: Dictionary) -> Image:
	var height := 48
	var img := Image.create(Brush.TILE, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ramp: Array = spec["ramp"]
	var gamma: float = spec["gamma"]
	var accent := Color(spec["accent"])
	# The panel starts a third of the way down, so the divider reads as waist
	# height with the room carrying on above it.
	for y in range(14, 44):
		for x in range(1, 15):
			var t := 0.40
			if x == 1 or x == 14:
				t = 0.08                           # frame upright
			elif x == 2:
				t = 0.66                           # lit edge
			elif x >= 12:
				t = 0.24
			# The weave: a two-pixel check, which is what makes it read as
			# fabric next to all the flat painted metal on this floor.
			elif (x + y) % 2 == 0:
				t = 0.46
			if y == 14 or y == 15:
				t = 0.72                           # capping rail
			elif y == 43:
				t = 0.10
			var c := Brush.ramp(ramp, t, gamma)
			if y > 16 and y < 43 and x > 2 and x < 12:
				c = c.lerp(accent, 0.10)           # the fabric takes a dye
			img.set_pixel(x, y, c)
	# Feet, splayed either side so it looks free-standing rather than sunk in.
	for x in range(0, 5):
		img.set_pixel(x, 44, Brush.ramp(ramp, 0.50, gamma))
		img.set_pixel(x, 45, Brush.ramp(ramp, 0.12, gamma))
	for x in range(11, 16):
		img.set_pixel(x, 44, Brush.ramp(ramp, 0.34, gamma))
		img.set_pixel(x, 45, Brush.ramp(ramp, 0.10, gamma))
	return img




## A 16x48 column: abacus, flared echinus, fluted shaft, flared plinth.
## Drawn rather than sampled - the source sheet has no pillar of any kind.
static func _classical_column(spec: Dictionary) -> Image:
	var height := 48
	var img := Image.create(Brush.TILE, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ramp: Array = spec["ramp"]
	var gamma: float = spec["gamma"]
	for y in height:
		var hw := _column_half_width(y)
		var left := 8 - hw
		var w := hw * 2
		for dx in w:
			var t := 0.70
			if dx == 0 or dx == w - 1:
				t = 0.06                       # silhouette outline
			elif dx == 1:
				t = 1.00                       # lit edge, light comes from the left
			elif dx == 2:
				t = 0.88
			elif dx >= w - 3:
				t = 0.34                       # shaded edge
			elif dx % 3 == 0:
				t = 0.55                       # flute groove
			# Horizontal breaks that read as the joints of stacked stone.
			if y == 2 or y == 9 or y == 39 or y == height - 1:
				t = minf(t, 0.22)
			elif y == 0 or y == 10 or y == 40:
				t = maxf(t, 0.92)
			img.set_pixel(left + dx, y, Brush.ramp(ramp, t, gamma))
	return img




static func _column_half_width(y: int) -> int:
	if y <= 2:
		return 7
	elif y <= 4:
		return 6
	elif y <= 39:
		return 5
	elif y <= 43:
		return 6
	return 7
