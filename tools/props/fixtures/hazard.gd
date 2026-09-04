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
		"copier":
			return _copier(spec)
		"fallen_light":
			return _fallen_light(spec)
		"power_strip":
			return _power_strip(spec)
		_:
			return _standing_torch(spec)




## DESIGN.md's hazard for asset recovery: an overloaded power strip on the floor,
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



## DESIGN.md's hazard for the content studio: a ring light knocked over, still
## at full output, still hot enough that you do not put a hand near it. The
## third hazard that is not fire and the third that has to read as harmful
## anyway, and the one that does it with brightness rather than with sparks.
##
## Hand-placed pixel by pixel, like the spark scatters above and for the same
## reason: at 16 px wide, whether a shape reads as a ring lying on the floor
## with a stand collapsed beside it is entirely a question of which pixels you
## pick. The ring sits at the BOTTOM of the canvas because that is where the
## hazard's collision box is - a fixture blocks and burns at its foot.
##
##   .  nothing        o  the room's own metal, lit    x  its outline
##   s  its shadow     W  the lamp at full output      H  warm falloff
##   E  the rim, hot enough to be the point
const FALLEN := [
	"................",
	"...x............",
	"..xo.x..........",
	"..oxxo..........",
	"...oo...........",
	"...xo...........",
	"....o...........",
	"....xo..........",
	".....o..........",
	".....xo.........",
	"......s.........",
	".....EHHHHE.....",
	"...EHWWWWWWHE...",
	".EHWWWWWWWWWHE..",
	".EHWW......WWHE.",
	"EHWW........WWHE",
	"EHW..........WHE",
	"EHW..........WHE",
	"EHWW........WWHE",
	".EHWW......WWHE.",
	".EHWWWWWWWWWHE..",
	"...EHWWWWWWHE...",
	".....EHHHHE.....",
	"................",
]
## The bloom escaping past the rim, in the corners the ring leaves empty.
## Generous on purpose, the same argument as the sparks: a hazard the player
## reads as scenery is a hazard that feels like the game cheating.
const BLOOM := [
	Vector2i(0, 11), Vector2i(15, 12), Vector2i(0, 21), Vector2i(15, 20),
	Vector2i(4, 23), Vector2i(11, 23), Vector2i(8, 23), Vector2i(1, 10),
]

const LAMP_CORE := Color("fffdf4")
const LAMP_BODY := Color("ffedc4")
const LAMP_RIM := Color("ffab3d")


static func _fallen_light(spec: Dictionary) -> Image:
	var img := Image.create(16, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in FALLEN.size():
		var row: String = FALLEN[y]
		for x in row.length():
			match row[x]:
				"o":
					Brush.pixel(img, Vector2i(x, y), Brush.shade(spec, 0.66))
				"x":
					Brush.pixel(img, Vector2i(x, y), Brush.shade(spec, 0.10))
				"s":
					Brush.pixel(img, Vector2i(x, y), Brush.shade(spec, 0.24))
				"W":
					Brush.pixel(img, Vector2i(x, y), LAMP_CORE)
				"H":
					Brush.pixel(img, Vector2i(x, y), LAMP_BODY)
				"E":
					Brush.pixel(img, Vector2i(x, y), LAMP_RIM)
	for at in BLOOM:
		var bloom := LAMP_RIM
		bloom.a = 0.55
		Brush.pixel(img, at, bloom)
	return img

## DESIGN.md's hazard for the call floor: the photocopier, jammed, with the lid
## up and the fuser still going. The furniture catalogue already has a broken
## copier (`printer`) and this is deliberately not it - that one is a machine
## nobody can use, and this one is a machine nobody should touch.
##
## Same hand-placed map as the fallen light, and the danger cue is the same
## generous scatter of fixed-colour sparks every other hazard uses. What is
## specific to this one is the paper: a white crumple coming out of the slot is
## the detail that says JAMMED rather than simply broken.
##
##   .  nothing   x  outline   l  lit face   o  body   d  shaded face
##   p  paper     r  the light that has been on for weeks
##   g  the accent light beside it   s/S  spark body / core
const COPIER := [
	"................",
	"....s.S..s......",
	"...S.s.S...s....",
	"..s...S...s.....",
	".xllllllllllx...",
	".xddddddddddx...",
	".xllllllllllx...",
	".xoooooooooox...",
	".xrgoooooooox...",
	".xoooooooooox...",
	".xddddddddddx...",
	".xppppppxooox...",
	".xopppxooooox...",
	".xoooooooooox...",
	".xllllllllllx...",
	".xoooooooooox...",
	".xoooooooooox...",
	".xddddddddddx...",
	".xoooooooooox...",
	".xoooooooooox...",
	".xddddddddddx...",
	".xxxxxxxxxxxx...",
	"..dd......dd....",
	"................",
]


static func _copier(spec: Dictionary) -> Image:
	var img := Image.create(16, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var accent := Color(spec["accent"])
	for y in COPIER.size():
		var row: String = COPIER[y]
		for x in row.length():
			match row[x]:
				"l":
					Brush.pixel(img, Vector2i(x, y), Brush.shade(spec, 0.88))
				"o":
					Brush.pixel(img, Vector2i(x, y), Brush.shade(spec, 0.52))
				"d":
					Brush.pixel(img, Vector2i(x, y), Brush.shade(spec, 0.24))
				"x":
					Brush.pixel(img, Vector2i(x, y), Brush.shade(spec, Brush.OUTLINE))
				"p":
					Brush.pixel(img, Vector2i(x, y), Brush.PAPER)
				"r":
					Brush.pixel(img, Vector2i(x, y), Brush.LED_BAD)
				"g":
					Brush.pixel(img, Vector2i(x, y), accent)
				"s":
					Brush.pixel(img, Vector2i(x, y), SPARK_BODY)
				"S":
					Brush.pixel(img, Vector2i(x, y), SPARK_CORE)
	# Crosses on the spark cores, the same trick the polisher uses: at this size
	# a single pixel is dust and a cross is a spark.
	for y in COPIER.size():
		var row: String = COPIER[y]
		for x in row.length():
			if row[x] != "S":
				continue
			for step in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1),
					Vector2i(0, 1)]:
				var at: Vector2i = Vector2i(x, y) + step
				if at.x >= 0 and at.y >= 0 and at.x < 16 and at.y < 24 \
						and img.get_pixel(at.x, at.y).a == 0.0:
					Brush.pixel(img, at, SPARK_EDGE)
	return img
