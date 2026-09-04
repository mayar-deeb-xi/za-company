extends RefCounted
## FIXTURE, not a catalogue prop - see column.gd.
## The hazard slot, per-biome style like the column. Both styles are 16x24 with
## the same foot, so the hazard scene and the collision box the level places are
## untouched by the choice - only what the danger looks like changes. What must
## not change is that it reads as harmful at a glance, which is why the sparks
## are as generous as the flame is.

const Brush := preload("../_brush.gd")

## Flame colours shared by every biome's torch: fire has to read as fire
## everywhere, while the stand under it is the biome's own stone.
const FLAME_EDGE := Color("b8300d")
const FLAME_BODY := Color("f0761a")
const FLAME_CORE := Color("ffd45e")

## The office floors' hazards throw sparks instead of burning, and they are
## fixed for the same reason the flame is: a hazard that took the room's palette
## would camouflage itself in it. Placed by hand rather than by formula, because
## at 16 px wide a scatter that reads as a shorting motor is a matter of which
## six pixels you pick.
const SPARK_CORE := Color("fff8e0")
const SPARK_BODY := Color("ffd45e")
const SPARK_EDGE := Color("ff8a3c")
const SPARKS := [
	Vector2i(1, 17), Vector2i(3, 14), Vector2i(14, 17), Vector2i(12, 13),
	Vector2i(4, 21), Vector2i(12, 21), Vector2i(0, 20), Vector2i(15, 20),
]
## A shorting motor arcs as well as sprays. Two jagged bolts off the housing.
const ARCS := [
	[Vector2i(3, 15), Vector2i(2, 14), Vector2i(3, 13), Vector2i(1, 11)],
	[Vector2i(12, 15), Vector2i(13, 14), Vector2i(12, 12), Vector2i(14, 11)],
]
## The power strip's short jumps BETWEEN two sockets and throws up - a different
## picture from a pad grinding the floor, so it gets its own placements.
const STRIP_ARCS := [
	[Vector2i(5, 17), Vector2i(6, 15), Vector2i(7, 13), Vector2i(6, 11)],
	[Vector2i(8, 17), Vector2i(9, 15), Vector2i(10, 14)],
]
const STRIP_SPARKS := [
	Vector2i(4, 13), Vector2i(9, 11), Vector2i(12, 15), Vector2i(2, 16),
	Vector2i(7, 9), Vector2i(13, 19), Vector2i(3, 20),
]


static func paint(spec: Dictionary) -> Image:
	match spec.get("hazard", "torch"):
		"polisher":
			return _polisher(spec)
		"power_strip":
			return _power_strip(spec)
		_:
			return _standing_torch(spec)




## DESIGN.md's hazard for the bullpen: an overloaded power strip on the floor,
## arcing, with far too much plugged into it. Lower and flatter than the other
## two hazards - it is something you tread ON rather than walk INTO - so the
## sparks do most of the work of being visible, and there are more of them than
## the polisher has for exactly that reason.
static func _power_strip(spec: Dictionary) -> Image:
	var img := Image.create(16, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ramp: Array = spec["ramp"]
	var gamma: float = spec["gamma"]

	# The strip itself, lying on the floor at the bottom of the canvas.
	for y in range(16, 22):
		for x in range(1, 15):
			var t := 0.46
			if y == 16:
				t = 0.70                           # top face, catching light
			elif y == 21:
				t = Brush.OUTLINE
			elif x <= 2:
				t = 0.62
			elif x >= 12:
				t = 0.26
			img.set_pixel(x, y, Brush.ramp(ramp, t, gamma))
	# Sockets: four of them, all occupied.
	for i in 4:
		var x := 2 + i * 3
		img.set_pixel(x, 18, Brush.ramp(ramp, Brush.OUTLINE, gamma))
		img.set_pixel(x + 1, 18, Brush.ramp(ramp, Brush.OUTLINE, gamma))
		img.set_pixel(x, 19, Brush.ramp(ramp, 0.86, gamma))
	# A daisy-chained second strip, because one was not enough for anybody.
	for x in range(4, 14):
		img.set_pixel(x, 14, Brush.ramp(ramp, 0.34, gamma))
		img.set_pixel(x, 15, Brush.ramp(ramp, 0.14, gamma))
	# The cables, going off in three directions and none of them tidy.
	for step in 8:
		img.set_pixel(mini(15, 14 + step / 4), 22 - step / 2,
			Brush.ramp(ramp, 0.08, gamma))
		img.set_pixel(maxi(0, 1 - step / 6), mini(23, 17 + step / 3),
			Brush.ramp(ramp, 0.08, gamma))
		img.set_pixel(3 + step / 3, mini(23, 22 + step / 7),
			Brush.ramp(ramp, 0.10, gamma))

	# The short. Arcs between the sockets rather than off a spinning pad, and
	# the fixed spark colours are the same ones the polisher uses: whatever the
	# floor's palette, a hazard has to read as one.
	for arc in STRIP_ARCS:
		for at in arc:
			Brush.pixel(img, at, SPARK_BODY)
	for at in STRIP_SPARKS:
		for step in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			Brush.pixel(img, at + step, SPARK_BODY if at.y < 18 else SPARK_EDGE)
		Brush.pixel(img, at, SPARK_CORE)
	return img




## A floor polisher someone left running with a shorted motor: DESIGN.md's
## reskin of the torch for the office floors. Handle bar, post, motor housing
## and a buffing pad, throwing sparks off the rim it is grinding into.
static func _polisher(spec: Dictionary) -> Image:
	var img := Image.create(16, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ramp: Array = spec["ramp"]
	var gamma: float = spec["gamma"]

	# T-grip and the post down to the motor, lit from the left like everything.
	for x in range(4, 12):
		img.set_pixel(x, 2, Brush.ramp(ramp, 0.16, gamma))
		img.set_pixel(x, 3, Brush.ramp(ramp, 0.88 if x <= 7 else 0.55, gamma))
	for y in range(4, 14):
		img.set_pixel(7, y, Brush.ramp(ramp, 0.70, gamma))
		img.set_pixel(8, y, Brush.ramp(ramp, 0.30, gamma))
	# Motor housing.
	for y in range(13, 18):
		for x in range(3, 13):
			var t := 0.52
			if x <= 4:
				t = 0.80
			elif x >= 11:
				t = 0.24
			if y == 13 or y == 17:
				t = 0.14
			img.set_pixel(x, y, Brush.ramp(ramp, t, gamma))
	# Buffing pad, widest where it meets the floor.
	var pad := {18: [2, 14], 19: [1, 15], 20: [1, 15], 21: [2, 14], 22: [4, 12]}
	for y in pad:
		var span: Array = pad[y]
		for x in range(span[0], span[1]):
			var t := 0.66 if y <= 19 else 0.34
			if x <= span[0] + 1:
				t += 0.20
			elif x >= span[1] - 2:
				t -= 0.16
			if y == 22:
				t = 0.08                        # the shadow it sits in
			img.set_pixel(x, y, Brush.ramp(ramp, t, gamma))

	# The sparks, and they are as generous as the flame is on purpose: this is a
	# hazard, and a hazard the player reads as scenery is a hazard that feels
	# like the game cheating. Crosses rather than dots so a 16 px prop still
	# says "live" at 1x, in fixed colours for the same reason the flame is - a
	# hazard that took the room's palette would camouflage itself in it.
	for arc in ARCS:
		for at in arc:
			Brush.pixel(img, at, SPARK_BODY)
	for at in SPARKS:
		for step in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			Brush.pixel(img, at + step, SPARK_BODY if at.y < 20 else SPARK_EDGE)
		Brush.pixel(img, at, SPARK_CORE)
	return img





## A 16x24 standing torch: biome-stone stem and plinth with fire on top.
## Drawn, like the column - the source sheet has no torch to sample.
static func _standing_torch(spec: Dictionary) -> Image:
	var img := Image.create(16, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ramp: Array = spec["ramp"]
	var gamma: float = spec["gamma"]

	# Stem, lit from the left like everything else in the biome.
	for y in range(10, 22):
		img.set_pixel(7, y, Brush.ramp(ramp, 0.62, gamma))
		img.set_pixel(8, y, Brush.ramp(ramp, 0.28, gamma))
	# Bowl the flame sits in.
	for x in range(5, 11):
		img.set_pixel(x, 9, Brush.ramp(ramp, 0.20, gamma))
		img.set_pixel(x, 10, Brush.ramp(ramp, 0.75 if x <= 7 else 0.40, gamma))
	# Plinth.
	for x in range(6, 10):
		img.set_pixel(x, 21, Brush.ramp(ramp, 0.85, gamma))
	for x in range(5, 11):
		img.set_pixel(x, 22, Brush.ramp(ramp, 0.50 if x <= 7 else 0.30, gamma))
		img.set_pixel(x, 23, Brush.ramp(ramp, 0.10, gamma))

	# Teardrop flame, hottest low and centred, dark-edged all round so it holds
	# its shape against both a pale and a hot floor.
	var half_widths := [1, 2, 3, 3, 3, 3, 2]
	for i in half_widths.size():
		var y: int = 2 + i
		var hw: int = half_widths[i]
		for x in range(8 - hw, 8 + hw):
			var c := FLAME_BODY
			if i == 0 or x == 8 - hw or x == 8 + hw - 1:
				c = FLAME_EDGE
			elif i >= 3 and x >= 7 and x <= 8:
				c = FLAME_CORE
			img.set_pixel(x, y, c)
	return img


