extends RefCounted
## Every picture of a thing a level PUTS ON ITS FLOOR, plus how big it is and
## what shape it blocks. Editor-side only, like the rest of tools/.
##
## The division of labour with build_biomes.gd is by subject, not by file type:
## that script paints the ROOM - its tiles and its doorways, the two things the
## level scene points at as files - and this one paints everything standing in
## the room. build_levels.gd then writes the scenes, embedding each picture in
## the scene that is its only user.
##
## Two groups live here, and they differ in how a level gets hold of them:
##
## - The CATALOGUE: furniture, hardware and signs, placed from a biome's `props`
##   list by type and position. Adding one is an entry plus a painter.
## - The FIXTURES: column, hazard and heal pickup, which a level places itself
##   at its own positions and which wrap differently (a hazard is an Area2D on
##   hazard_base.gd, a pickup one on pickup_base.gd, a column a StaticBody2D).
##   Only their painters are here - see the section at the bottom.
##
## Sizes and collision boxes are stated once, here, because the art and the
## collision box have to agree about where the foot of a prop is or the player
## walks through the front of a desk.
##
## Everything is drawn rather than sampled: the shared dungeon sheet has no
## furniture in it. Bodies are painted from the biome's own ramp, so a desk in
## hellfire is a hellfire desk for free - which is what floors 3-8 need. Only
## what has to read the same everywhere carries fixed colours: fire is fire,
## health is red, water is water, and a plant is alive or dead in any palette.

const Biomes := preload("res://tools/biomes.gd")

## One tile, which is what the column and hazard canvases are sized against.
const TILE := 16

## Silhouette outline, dark enough to hold against a pale marble floor and a hot
## hellfire one alike.
const OUTLINE := 0.05

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
## The power strip's own short: the arc jumps BETWEEN two sockets and throws up,
## a different picture from a pad grinding the floor, so it gets its own places.
const STRIP_ARCS := [
	[Vector2i(5, 17), Vector2i(6, 15), Vector2i(7, 13), Vector2i(6, 11)],
	[Vector2i(8, 17), Vector2i(9, 15), Vector2i(10, 14)],
]
const STRIP_SPARKS := [
	Vector2i(4, 13), Vector2i(9, 11), Vector2i(12, 15), Vector2i(2, 16),
	Vector2i(7, 9), Vector2i(13, 19), Vector2i(3, 20),
]

## The heal pickup, identical in every biome on purpose: red means health
## everywhere. Row-major mask, X = filled.
const HEART := [
	".XX...XX.",
	"XXXX.XXXX",
	"XXXXXXXXX",
	"XXXXXXXXX",
	".XXXXXXX.",
	"..XXXXX..",
	"...XXX...",
	"....X....",
]

## Fixed colours: these mean something regardless of the room's palette.
const WATER := Color("6cc0e8")
const WATER_LIT := Color("a8dcf5")
const WATER_DARK := Color("2f7fa8")
const SCREEN := Color("18222e")
const LEAF := Color("3f9151")
const LEAF_LIT := Color("62b96a")
const LEAF_DEAD := Color("8a6a3a")
const LEAF_DEAD_LIT := Color("a88a52")
const SOIL := Color("42301f")
## Status lights read as status in any palette, which is the point of having one
## of them be red: a rack with a red light is a rack with something wrong in it,
## and that is the whole fiction of the maintenance floor in two pixels.
const LED_OK := Color("4fe08a")
const LED_BAD := Color("e8443c")
const PCB := Color("2f6b3a")
const PAPER := Color("f4f1e6")
const INK := Color("1e1c1a")

## type -> size of the art, plus the box it blocks and where its foot sits.
##
## `blocks` is the collision box in pixels, resting on the origin the way the
## column's does: only the base of a prop is solid, so the player walks behind
## its upper half and Y-sorting draws them in the right order. Vector2.ZERO is
## decor - a banner on a wall has nothing to bump into.
##
## `pin` is which pixel of the art lands on the placement position, and defaults
## to bottom-centre because that is what Y-sorting reads. The banner overrides
## it to its top-left corner: it hangs by one corner, so that corner is the nail
## and rotating the instance has to swing the cloth rather than orbit it.
## Heights are measured against the standing torch, which is 24 px and stands
## about as tall as a character: that is the scale reference this game already
## had, and the first draft of these props ignored it. A desk drawn 30 px tall
## is a desk taller than the person sitting at it, which looks like nothing in
## isolation and makes the whole cast read as children the moment one of them
## stands next to it. So a counter is chest high, a desk with its monitor comes
## to a shoulder, and a coffee table is knee high.
const CATALOGUE := {
	"reception": {"size": Vector2i(96, 22), "blocks": Vector2(90, 9)},
	"desk": {"size": Vector2i(40, 21), "blocks": Vector2(38, 7)},
	"chair": {"size": Vector2i(14, 15), "blocks": Vector2(11, 5)},
	"cooler": {"size": Vector2i(16, 22), "blocks": Vector2(12, 6)},
	"sofa": {"size": Vector2i(52, 17), "blocks": Vector2(50, 8)},
	"table": {"size": Vector2i(26, 11), "blocks": Vector2(24, 6)},
	"plant": {"size": Vector2i(20, 24), "blocks": Vector2(12, 5)},
	"dead_plant": {"size": Vector2i(20, 24), "blocks": Vector2(12, 5)},
	# The maintenance floor's hardware: what the office boys look after, and
	# what they have not got round to. All solid, all low-blocking, so a room
	# can be filled with junk without becoming a maze - enemies here walk
	# straight at the player and slide off what they hit, with no pathfinding
	# to get them out of a pocket.
	"server_rack": {"size": Vector2i(22, 32), "blocks": Vector2(18, 7)},
	"printer": {"size": Vector2i(30, 20), "blocks": Vector2(28, 7)},
	"crt_stack": {"size": Vector2i(26, 26), "blocks": Vector2(22, 7)},
	"pc_tower": {"size": Vector2i(18, 20), "blocks": Vector2(14, 6)},
	"toolbox": {"size": Vector2i(20, 14), "blocks": Vector2(16, 6)},
	"cable_spool": {"size": Vector2i(20, 18), "blocks": Vector2(16, 6)},
	"scrap_pile": {"size": Vector2i(28, 15), "blocks": Vector2(24, 6)},
	# Loose junk lying on the floor, and the ONLY hardware prop that blocks
	# nothing. That is what it is for: a room whose brief is "full of junk" and
	# whose fight needs open floor cannot solve both with solid props, so the
	# middle of the bullpen gets litter instead of obstacles.
	"debris": {"size": Vector2i(24, 9), "blocks": Vector2.ZERO},
	# Signs have no ground to be in scale with, so they stay as big as they need
	# to be to be read across a room. `text` is data so a floor can put up its
	# own words without a new painter - DESIGN.md has wall text waiting on four
	# more floors.
	"banner": {"size": Vector2i(66, 32), "blocks": Vector2.ZERO,
		"pin": Vector2i(0, 0), "text": ["WELCOME", "NEW HIRES"]},
	"notice": {"size": Vector2i(46, 24), "blocks": Vector2.ZERO,
		"pin": Vector2i(0, 0), "text": ["OUT OF", "ORDER"]},
}

## A 5x5 uppercase font, one glyph per key, advanced 6 px. Small enough to letter
## a banner inside the 640x360 viewport and still be read, which the props need:
## the joke on floor 1 is what the banner says, and DESIGN.md hangs wall text on
## half the floors after it. Row-major, X = filled, like build_biomes.gd's HEART.
const FONT := {
	"A": [".XXX.", "X...X", "XXXXX", "X...X", "X...X"],
	"B": ["XXXX.", "X...X", "XXXX.", "X...X", "XXXX."],
	"C": [".XXXX", "X....", "X....", "X....", ".XXXX"],
	"D": ["XXXX.", "X...X", "X...X", "X...X", "XXXX."],
	"E": ["XXXXX", "X....", "XXXX.", "X....", "XXXXX"],
	"F": ["XXXXX", "X....", "XXXX.", "X....", "X...."],
	"G": [".XXXX", "X....", "X..XX", "X...X", ".XXX."],
	"H": ["X...X", "X...X", "XXXXX", "X...X", "X...X"],
	"I": ["XXXXX", "..X..", "..X..", "..X..", "XXXXX"],
	"J": ["...XX", "....X", "....X", "X...X", ".XXX."],
	"K": ["X...X", "X..X.", "XXX..", "X..X.", "X...X"],
	"L": ["X....", "X....", "X....", "X....", "XXXXX"],
	"M": ["X...X", "XX.XX", "X.X.X", "X...X", "X...X"],
	"N": ["X...X", "XX..X", "X.X.X", "X..XX", "X...X"],
	"O": [".XXX.", "X...X", "X...X", "X...X", ".XXX."],
	"P": ["XXXX.", "X...X", "XXXX.", "X....", "X...."],
	"Q": [".XXX.", "X...X", "X.X.X", "X..X.", ".XX.X"],
	"R": ["XXXX.", "X...X", "XXXX.", "X..X.", "X...X"],
	"S": [".XXXX", "X....", ".XXX.", "....X", "XXXX."],
	"T": ["XXXXX", "..X..", "..X..", "..X..", "..X.."],
	"U": ["X...X", "X...X", "X...X", "X...X", ".XXX."],
	"V": ["X...X", "X...X", "X...X", ".X.X.", "..X.."],
	"W": ["X...X", "X...X", "X.X.X", "XX.XX", "X...X"],
	"X": ["X...X", ".X.X.", "..X..", ".X.X.", "X...X"],
	"Y": ["X...X", ".X.X.", "..X..", "..X..", "..X.."],
	"Z": ["XXXXX", "...X.", "..X..", ".X...", "XXXXX"],
	"!": ["..X..", "..X..", "..X..", ".....", "..X.."],
	"-": [".....", ".....", "XXXXX", ".....", "....."],
}
const GLYPH_W := 5
const GLYPH_H := 5
const GLYPH_ADVANCE := 6


## Wraps a painted image as an embeddable texture. Every picture in this project
## goes through here, and it is a PortableCompressedTexture2D rather than a PNG
## for one reason: a PNG is useless until Godot imports it, which needs the
## editor or a --import pass, while this is usable the instant it exists. That
## matters because the editor is usually open while these run.
##
## Left unsaved by the caller, it has no resource_path, which is exactly what
## makes PackedScene embed it as a sub-resource instead of writing a separate
## file to point at - see build_levels.gd.
static func texture(img: Image) -> PortableCompressedTexture2D:
	var tex := PortableCompressedTexture2D.new()
	tex.keep_compressed_buffer = true
	tex.create_from_image(img, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
	return tex


static func known(type: String) -> bool:
	return CATALOGUE.has(type)


static func size_of(type: String) -> Vector2i:
	return CATALOGUE[type]["size"]


static func blocks(type: String) -> Vector2:
	return CATALOGUE[type].get("blocks", Vector2.ZERO)


## Offset from the placement position to the art's top-left corner - what the
## Sprite2D's position has to be for the prop to stand where the level put it.
static func offset(type: String) -> Vector2:
	var spec: Dictionary = CATALOGUE[type]
	var art: Vector2i = spec["size"]
	var pin: Vector2i = spec.get("pin", Vector2i(art.x / 2, art.y))
	return Vector2(-pin.x, -pin.y)


## Paints one prop in a biome's palette. `spec` is the biome dictionary from
## biomes.gd - the ramp and gamma for the body, the accent for the upholstery.
static func paint(type: String, spec: Dictionary) -> Image:
	var art: Vector2i = size_of(type)
	var img := Image.create(art.x, art.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match type:
		"reception": _reception(img, spec)
		"desk": _desk(img, spec)
		"chair": _chair(img, spec)
		"cooler": _cooler(img, spec)
		"sofa": _sofa(img, spec)
		"table": _table(img, spec)
		"plant": _plant(img, spec, false)
		"dead_plant": _plant(img, spec, true)
		"server_rack": _server_rack(img, spec)
		"printer": _printer(img, spec)
		"crt_stack": _crt_stack(img, spec)
		"pc_tower": _pc_tower(img, spec)
		"toolbox": _toolbox(img, spec)
		"cable_spool": _cable_spool(img, spec)
		"scrap_pile": _scrap_pile(img, spec)
		"debris": _debris(img, spec)
		"banner": _banner(img, spec, CATALOGUE[type]["text"])
		"notice": _notice(img, spec, CATALOGUE[type]["text"])
		_: printerr("props: nothing draws '%s'" % type)
	return img


## The front desk: a bright slab overhanging a panel with the sign on it. Reads
## as a counter from the front, which is the only side the player ever sees.
static func _reception(img: Image, spec: Dictionary) -> void:
	var w: int = size_of("reception").x
	_panel(img, spec, Rect2i(2, 6, w - 4, 16), 0.44)
	_slab(img, spec, Rect2i(0, 0, w, 7), 0.90)
	# Panel joints, so 90 px of counter front is not one flat field of grey.
	for seam in [10, w - 11]:
		for y in range(8, 21):
			_pixel(img, Vector2i(seam, y), Biomes.shade(spec, 0.26))
			_pixel(img, Vector2i(seam + 1, y), Biomes.shade(spec, 0.56))
	# The sign, inset into the panel so it reads as mounted rather than painted.
	var plaque := Rect2i(16, 8, w - 32, 11)
	_fill(img, spec, plaque, 0.14)
	_outline(img, spec, plaque)
	_text(img, "RECEPTION", Vector2i(0, 11), Biomes.shade(spec, 1.0), w)


## A workstation: monitor, desktop, drawer front, and a cup nobody has washed.
static func _desk(img: Image, spec: Dictionary) -> void:
	var w: int = size_of("desk").x
	# Monitor: bezel, screen, and two accent rows so it reads as switched on.
	var bezel := Rect2i(12, 0, 16, 8)
	_fill(img, spec, bezel, 0.16)
	_outline(img, spec, bezel)
	for y in range(2, 7):
		for x in range(14, 26):
			img.set_pixel(x, y, SCREEN)
	var glow: Color = Color(spec["accent"])
	for x in range(15, 24):
		img.set_pixel(x, 3, glow.darkened(0.25))
	for x in range(15, 21):
		img.set_pixel(x, 5, glow.darkened(0.55))
	for y in range(8, 10):
		_row(img, spec, y, 19, 22, 0.30)
	_slab(img, spec, Rect2i(0, 9, w, 6), 0.82)
	_panel(img, spec, Rect2i(2, 14, w - 4, 7), 0.40)
	# Drawer front with an accent handle.
	var drawer := Rect2i(5, 15, 15, 5)
	_outline(img, spec, drawer)
	for x in range(9, 16):
		img.set_pixel(x, 17, glow)
	# The cup, sitting on the desktop.
	for y in range(6, 10):
		for x in range(32, 36):
			img.set_pixel(x, y, Biomes.shade(spec, 0.96 if x < 34 else 0.70))
	_pixel(img, Vector2i(32, 6), Biomes.shade(spec, OUTLINE))
	_pixel(img, Vector2i(35, 6), Biomes.shade(spec, OUTLINE))


## A swivel chair seen from behind the desk it belongs to.
static func _chair(img: Image, spec: Dictionary) -> void:
	var back := Rect2i(2, 0, 10, 8)
	_fill(img, spec, back, 0.38)
	_outline(img, spec, back)
	_slab(img, spec, Rect2i(0, 7, 14, 4), 0.66)
	for y in range(11, 13):
		_row(img, spec, y, 6, 8, 0.26)
	var base := Rect2i(2, 12, 10, 3)
	_fill(img, spec, base, 0.32)
	_outline(img, spec, base)


## The water cooler, and the one prop whose colour is not the room's: water has
## to read as water on every floor, the same rule as fire and hearts.
static func _cooler(img: Image, spec: Dictionary) -> void:
	# Bottle: lit from the left like everything else, with the level showing.
	for y in range(1, 10):
		for x in range(4, 12):
			var c := WATER
			if x <= 5:
				c = WATER_LIT
			elif x >= 10:
				c = WATER_DARK
			if y <= 2:
				c = c.lerp(WATER_LIT, 0.5)   # the air gap at the top
			img.set_pixel(x, y, c)
	_ring(img, Rect2i(4, 1, 8, 9), WATER_DARK.darkened(0.45))
	for y in range(10, 12):
		for x in range(6, 10):
			img.set_pixel(x, y, WATER_DARK)
	_slab(img, spec, Rect2i(1, 11, 14, 4), 0.86)
	_panel(img, spec, Rect2i(2, 14, 12, 8), 0.42)
	# Spigot and a drip tray under it.
	for y in range(16, 19):
		_row(img, spec, y, 7, 9, OUTLINE)
	_pixel(img, Vector2i(6, 16), Color(spec["accent"]))
	_pixel(img, Vector2i(10, 16), WATER)
	for x in range(4, 12):
		_pixel(img, Vector2i(x, 20), Biomes.shade(spec, 0.20))


## Waiting-area couch, upholstered in the biome's accent so the furniture reads
## as belonging to the room rather than dropped into it.
static func _sofa(img: Image, spec: Dictionary) -> void:
	var w: int = size_of("sofa").x
	var fabric: Color = Color(spec["accent"])
	var dark := fabric.darkened(0.45)
	var lit := fabric.lightened(0.18)
	# Backrest, then the arms, then the seat cushions in front of both.
	_block(img, Rect2i(1, 0, w - 2, 8), fabric.darkened(0.15), dark)
	_block(img, Rect2i(0, 4, 6, 9), fabric.darkened(0.30), dark)
	_block(img, Rect2i(w - 6, 4, 6, 9), fabric.darkened(0.38), dark)
	_block(img, Rect2i(5, 7, w - 10, 6), lit, dark)
	# The split between the two cushions.
	for y in range(7, 13):
		img.set_pixel(w / 2, y, dark)
	for x in range(2, w - 2):
		img.set_pixel(x, 8, fabric.lightened(0.35))
	# Legs.
	for y in range(13, 17):
		_row(img, spec, y, 7, 11, 0.28)
		_row(img, spec, y, w - 11, w - 7, 0.22)


## The low table in front of the sofa, with something to read on it.
static func _table(img: Image, spec: Dictionary) -> void:
	var w: int = size_of("table").x
	_slab(img, spec, Rect2i(0, 2, w, 5), 0.88)
	for y in range(6, 11):
		_row(img, spec, y, 3, 7, 0.26)
		_row(img, spec, y, w - 7, w - 3, 0.20)
	for x in range(5, w - 5):
		_pixel(img, Vector2i(x, 8), Biomes.shade(spec, 0.34))
	# A magazine, squared up with the table because someone tidies this lobby.
	var mag := Rect2i(8, 0, 11, 4)
	_block(img, mag, Color(spec["accent"]), Color(spec["accent"]).darkened(0.5))
	for x in range(10, 17):
		img.set_pixel(x, 2, Color(spec["accent"]).lightened(0.45))


## The pot plant, alive or not. DESIGN.md gives floor 1 a dead one; the droop is
## the whole difference, so both come out of one painter rather than two.
static func _plant(img: Image, spec: Dictionary, dead: bool) -> void:
	var crown := Vector2(10.0, 14.0)
	# Leaves radiate from the crown. A dead plant's fall instead of reaching:
	# every direction is pulled downwards, which is what reads as dying at this
	# size - a browner green alone just looks like a different plant.
	var reach := [
		Vector2(-1.0, -0.45), Vector2(-0.8, -0.75), Vector2(-0.5, -1.0),
		Vector2(-0.15, -1.1), Vector2(0.2, -1.05), Vector2(0.55, -0.9),
		Vector2(0.85, -0.6), Vector2(-1.0, 0.2), Vector2(1.0, 0.15),
	]
	var body := LEAF_DEAD if dead else LEAF
	var tip := LEAF_DEAD_LIT if dead else LEAF_LIT
	for dir in reach:
		var d: Vector2 = dir
		if dead:
			d = Vector2(d.x * 0.85, absf(d.y) * 0.55 + 0.25)
		_leaf(img, crown, d.normalized(), 8.0 if dead else 10.0, body, tip)
	# Stem, then the pot: rim lit, soil showing at the top.
	for y in range(10, 18):
		_pixel(img, Vector2i(9, y), body.darkened(0.35))
		_pixel(img, Vector2i(10, y), body.darkened(0.1))
	_slab(img, spec, Rect2i(3, 16, 14, 4), 0.80)
	for x in range(5, 15):
		_pixel(img, Vector2i(x, 18), SOIL)
	_panel(img, spec, Rect2i(4, 19, 12, 5), 0.46)
	for x in range(5, 15):
		_pixel(img, Vector2i(x, 23), Biomes.shade(spec, OUTLINE))


## ---- the maintenance floor's hardware -----------------------------------
## What the office boys are responsible for, in the state they have left it. The
## running theme is that every machine here has something visibly wrong with it -
## a red light, a paper jam, a panel off, a cable hanging out - because the room
## has to say "these people fix things, and they are behind" without a line of
## dialogue.

## A rack of servers: perforated units, status lights, and cabling spilling out
## of the bottom because nobody dressed it.
static func _server_rack(img: Image, spec: Dictionary) -> void:
	var art: Vector2i = size_of("server_rack")
	_panel(img, spec, Rect2i(1, 2, art.x - 2, art.y - 2), 0.20)
	_slab(img, spec, Rect2i(0, 0, art.x, 4), 0.56)
	# Six units, each a slot with a pair of lights. One of them is red - the
	# reason there is a maintenance floor at all.
	for unit in 6:
		var y := 6 + unit * 4
		_row(img, spec, y, 3, art.x - 3, 0.09)
		_row(img, spec, y + 1, 3, art.x - 3, 0.30)
		_pixel(img, Vector2i(4, y + 1), LED_BAD if unit == 2 else LED_OK)
		_pixel(img, Vector2i(6, y + 1), LED_OK if unit != 4 else LED_BAD)
	# The cable bundle, hanging out of the bottom and pooling on the floor.
	for strand in [Vector2i(5, 27), Vector2i(8, 27), Vector2i(12, 27)]:
		for step in 4:
			_pixel(img, strand + Vector2i(-step / 2, step), Biomes.shade(spec, 0.07))


## A photocopier with the lid propped open and paper jammed in the front. The
## one machine every office recognises as broken on sight.
static func _printer(img: Image, spec: Dictionary) -> void:
	var art: Vector2i = size_of("printer")
	# The lid, standing up at the back rather than lying shut.
	_slab(img, spec, Rect2i(4, 0, art.x - 8, 5), 0.62)
	_panel(img, spec, Rect2i(1, 6, art.x - 2, art.y - 6), 0.46)
	_slab(img, spec, Rect2i(0, 4, art.x, 5), 0.82)
	# Control panel and the light that says why nobody is using it.
	var pad := Rect2i(3, 10, 9, 5)
	_fill(img, spec, pad, 0.14)
	_outline(img, spec, pad)
	_pixel(img, Vector2i(5, 12), LED_BAD)
	_pixel(img, Vector2i(9, 12), Color(spec["accent"]))
	# Output slot, with the jam still in it.
	var slot := Rect2i(14, 11, art.x - 17, 4)
	_fill(img, spec, slot, 0.08)
	for x in range(16, art.x - 5):
		_pixel(img, Vector2i(x, 12), PAPER)
	_pixel(img, Vector2i(art.x - 6, 11), PAPER)
	_pixel(img, Vector2i(art.x - 5, 13), PAPER)


## Two dead monitors stacked, the top one not squared up with the bottom. Their
## screens are the darkest thing in the room, which is what says they are off.
static func _crt_stack(img: Image, spec: Dictionary) -> void:
	# Beige plastic, not dark: the housings have to be the LIGHT part so the two
	# dead screens are the dark part. Drawn dark, a stack of monitors on a dim
	# brown floor is one brown blob.
	for box in [Rect2i(2, 13, 22, 13), Rect2i(5, 1, 18, 13)]:
		_fill(img, spec, box, 0.62)
		_outline(img, spec, box)
		var screen := Rect2i(box.position.x + 2, box.position.y + 2,
			box.size.x - 4, box.size.y - 5)
		for y in screen.size.y:
			for x in screen.size.x:
				_pixel(img, screen.position + Vector2i(x, y), SCREEN)
		# The dull sheen of a screen with nothing behind it.
		for i in mini(screen.size.x, screen.size.y):
			_pixel(img, screen.position + Vector2i(i + 1, i), SCREEN.lightened(0.22))
	_pixel(img, Vector2i(20, 24), LED_BAD.darkened(0.55))


## A tower with its side panel off and its insides showing - mid-repair, or
## mid-abandonment, which on this floor is the same thing.
static func _pc_tower(img: Image, spec: Dictionary) -> void:
	var art: Vector2i = size_of("pc_tower")
	_panel(img, spec, Rect2i(1, 4, art.x - 2, art.y - 4), 0.34)
	_slab(img, spec, Rect2i(1, 2, art.x - 2, 4), 0.60)
	# The open bay: a board, a drive, and a fan opening.
	var bay := Rect2i(4, 7, 10, 11)
	_fill(img, spec, bay, 0.06)
	for y in range(9, 15):
		for x in range(5, 11):
			_pixel(img, Vector2i(x, y), PCB if (x + y) % 3 != 0 else PCB.darkened(0.4))
	for x in range(5, 13):
		_pixel(img, Vector2i(x, 8), Biomes.shade(spec, 0.90))
	_pixel(img, Vector2i(12, 10), LED_OK)
	_pixel(img, Vector2i(12, 16), Color(spec["accent"]))
	# The panel that came off, leaning against the case.
	for y in range(6, art.y):
		_pixel(img, Vector2i(0, y), Biomes.shade(spec, 0.52))
		_pixel(img, Vector2i(1, y), Biomes.shade(spec, OUTLINE))


## An open toolbox: the prop that says the junk around it is being worked on
## rather than simply dumped.
static func _toolbox(img: Image, spec: Dictionary) -> void:
	var art: Vector2i = size_of("toolbox")
	_panel(img, spec, Rect2i(1, 4, art.x - 2, art.y - 4), 0.36)
	_slab(img, spec, Rect2i(0, 3, art.x, 5), 0.74)
	# The carry handle. This is the pixel that makes a box a TOOLbox at this
	# size - without it the silhouette is a bench, which is what it read as.
	for x in range(6, 14):
		_pixel(img, Vector2i(x, 0), Biomes.shade(spec, OUTLINE))
	for at in [Vector2i(5, 1), Vector2i(14, 1), Vector2i(5, 2), Vector2i(14, 2)]:
		_pixel(img, at, Biomes.shade(spec, OUTLINE))
	# A band of the biome's accent, because a toolbox is the one thing on this
	# floor somebody bought new.
	for x in range(3, art.x - 3):
		_pixel(img, Vector2i(x, 9), Color(spec["accent"]))
	# A screwdriver left lying on the lid.
	for x in range(13, 18):
		_pixel(img, Vector2i(x, 4), Biomes.shade(spec, 0.95))
	_pixel(img, Vector2i(11, 4), Color(spec["accent"]).darkened(0.35))
	_pixel(img, Vector2i(12, 4), Color(spec["accent"]).darkened(0.35))


## A drum of cable stood on its rim, with the end trailing off. Round, which is
## most of why it is here: everything else on this floor is a box.
static func _cable_spool(img: Image, spec: Dictionary) -> void:
	var centre := Vector2(9.5, 8.5)
	for y in 18:
		for x in 20:
			var d := Vector2(x, y).distance_to(centre)
			if d > 8.6:
				continue
			var t := 0.44
			if d > 7.4:
				t = OUTLINE                       # rim
			elif d > 6.2:
				t = 0.66                          # flange
			elif d > 2.4:
				# Coiled cable, banded so it reads as wound rather than solid.
				t = 0.16 if int(d) % 2 == 0 else 0.30
			else:
				t = 0.52                          # hub
			_pixel(img, Vector2i(x, y), Biomes.shade(spec, t))
	# The loose end nobody coiled back up.
	for step in 6:
		_pixel(img, Vector2i(16 + step / 2, 12 + step), Biomes.shade(spec, 0.10))


## A heap of e-waste: a keyboard on top, a fan, a board, a coil of wire. The
## filler prop, and the one a room gets several of - which is why it is a low
## irregular mound rather than another box.
static func _scrap_pile(img: Image, spec: Dictionary) -> void:
	var art: Vector2i = size_of("scrap_pile")
	# The mound, highest a third of the way along so it does not read as a arch.
	for x in art.x:
		var t := float(x) / float(art.x - 1)
		var top: int = art.y - 4 - int(round(sin(pow(t, 0.7) * PI) * 7.0))
		for y in range(top, art.y):
			var shade := 0.30 if y > top + 1 else 0.46
			if x <= 1 or x >= art.x - 2 or y == art.y - 1:
				shade = OUTLINE
			_pixel(img, Vector2i(x, y), Biomes.shade(spec, shade))
	# A keyboard, tipped on the heap: a pale slab with key rows punched in it.
	for y in range(4, 8):
		for x in range(4, 17):
			_pixel(img, Vector2i(x, y), Biomes.shade(spec, 0.88 if y < 6 else 0.62))
	for x in range(5, 16, 2):
		_pixel(img, Vector2i(x, 5), Biomes.shade(spec, 0.16))
		_pixel(img, Vector2i(x, 7), Biomes.shade(spec, 0.16))
	# A case fan, and a bare board behind it.
	var fan := Rect2i(18, 5, 7, 7)
	_fill(img, spec, fan, 0.24)
	_outline(img, spec, fan)
	for y in range(7, 10):
		for x in range(20, 23):
			_pixel(img, Vector2i(x, y), Biomes.shade(spec, 0.66))
	for x in range(15, 19):
		_pixel(img, Vector2i(x, 9), PCB)
		_pixel(img, Vector2i(x, 10), PCB.darkened(0.35))
	# A coil of wire spilling off the side.
	for step in 7:
		_pixel(img, Vector2i(2 + step, art.y - 3 - (step % 3)),
			Biomes.shade(spec, 0.08))


## Litter: offcut wire, dropped screws, a snapped cable tie, a chip of board.
## Deliberately drawn WITHOUT an outline, unlike every other prop here - an
## outline is what gives a prop volume, and this has none. It is meant to read
## as marks on the floor you walk over, not as something in the way.
##
## Nothing in it is red or gold: the heart pickup is red and the hazard's sparks
## are gold, and litter that borrows either colour is litter the player walks
## across the room to try to pick up.
static func _debris(img: Image, spec: Dictionary) -> void:
	# A loop of offcut wire.
	for at in [Vector2i(2, 5), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 5),
			Vector2i(5, 6), Vector2i(4, 7), Vector2i(3, 7), Vector2i(2, 6)]:
		_pixel(img, at, Biomes.shade(spec, 0.08))
	for at in [Vector2i(6, 6), Vector2i(7, 7), Vector2i(8, 7)]:
		_pixel(img, at, Biomes.shade(spec, 0.12))
	# Screws, bright enough to catch the eye and small enough not to hold it.
	for at in [Vector2i(11, 3), Vector2i(14, 7), Vector2i(19, 4)]:
		_pixel(img, at, Biomes.shade(spec, 0.96))
		_pixel(img, at + Vector2i(0, 1), Biomes.shade(spec, 0.24))
	# A chip of board, and the cable tie somebody cut and dropped.
	_pixel(img, Vector2i(16, 5), PCB)
	_pixel(img, Vector2i(17, 5), PCB.darkened(0.3))
	_pixel(img, Vector2i(17, 6), PCB.darkened(0.5))
	for at in [Vector2i(20, 7), Vector2i(21, 6), Vector2i(22, 6)]:
		_pixel(img, at, Color(spec["accent"]).darkened(0.35))
	# Plastic fragments.
	for at in [Vector2i(9, 2), Vector2i(10, 2), Vector2i(13, 4), Vector2i(22, 3)]:
		_pixel(img, at, Biomes.shade(spec, 0.72))


## A sheet of paper taped up, which is how a company actually communicates that
## something is broken. Deliberately not cloth: it is the cheap, temporary,
## nobody-is-coming version of the lobby's banner.
static func _notice(img: Image, spec: Dictionary, lines: Array) -> void:
	var art: Vector2i = size_of("notice")
	for y in range(2, art.y):
		for x in art.x:
			img.set_pixel(x, y, PAPER if y < art.y - 1 else PAPER.darkened(0.25))
	_ring(img, Rect2i(0, 2, art.x, art.y - 2), INK.lightened(0.35))
	# Two strips of tape, and only two, at the top corners.
	var tape: Color = Color(spec["accent"]).lightened(0.15)
	for strip in [0, art.x - 9]:
		for y in 4:
			for x in 9:
				img.set_pixel(strip + x, y, tape if y > 0 else tape.darkened(0.3))
	for i in lines.size():
		_text(img, lines[i], Vector2i(0, 8 + i * 8), INK, art.x)


## The welcome banner, hung by the top-left corner: DESIGN.md wants it sagging
## off one nail, so the cloth is drawn square and the LEVEL rotates the instance
## about that corner. The bottom edge sags on its own so a tilted banner still
## looks like cloth rather than a rotated rectangle.
static func _banner(img: Image, spec: Dictionary, lines: Array) -> void:
	var art: Vector2i = size_of("banner")
	var cloth: Color = Color(spec["accent"]).darkened(0.25)
	var hem: Color = Color(spec["accent"]).lightened(0.25)
	var edge: Color = Color(spec["accent"]).darkened(0.7)
	for x in art.x:
		# Sags towards the unsupported end, deepest about three quarters along.
		var t := float(x) / float(art.x - 1)
		var bottom := 22 + int(round(sin(t * PI * 0.85) * 6.0))
		for y in range(0, bottom):
			var c := cloth
			if y <= 1:
				c = hem
			elif y >= bottom - 2:
				c = edge
			img.set_pixel(x, y, c)
		img.set_pixel(x, 0, edge)
	# The nail it hangs from, and the only one.
	for y in 3:
		for x in 3:
			img.set_pixel(x + 1, y + 1, Biomes.shade(spec, OUTLINE))
	for i in lines.size():
		_text(img, lines[i], Vector2i(0, 5 + i * 8), hem.lightened(0.6), art.x)


## ---- painting primitives -------------------------------------------------
## A prop body is lit from the left and outlined all round, the same two rules
## the columns and torches follow, so drawn furniture sits in the same light as
## the drawn architecture.

## A flat top surface: brightest at the back edge, so it reads as a plane the
## room is looking down onto rather than a wall.
static func _slab(img: Image, spec: Dictionary, at: Rect2i, tone: float) -> void:
	for y in at.size.y:
		var t := clampf(tone - 0.05 * float(y), 0.0, 1.0)
		for x in at.size.x:
			var shade := t
			if x >= at.size.x - 2:
				shade = maxf(t - 0.20, 0.0)
			_pixel(img, at.position + Vector2i(x, y), Biomes.shade(spec, shade))
	_outline(img, spec, at)


## A vertical face: the front of a desk or the body of a cooler.
static func _panel(img: Image, spec: Dictionary, at: Rect2i, tone: float) -> void:
	for y in at.size.y:
		for x in at.size.x:
			var t := tone
			if x <= 1:
				t = tone + 0.16
			elif x >= at.size.x - 2:
				t = tone - 0.14
			_pixel(img, at.position + Vector2i(x, y), Biomes.shade(spec, t))
	_outline(img, spec, at)


static func _fill(img: Image, spec: Dictionary, at: Rect2i, tone: float) -> void:
	for y in at.size.y:
		for x in at.size.x:
			_pixel(img, at.position + Vector2i(x, y), Biomes.shade(spec, tone))


static func _row(img: Image, spec: Dictionary, y: int, from_x: int, to_x: int,
		tone: float) -> void:
	for x in range(from_x, to_x):
		_pixel(img, Vector2i(x, y), Biomes.shade(spec, tone))


static func _outline(img: Image, spec: Dictionary, at: Rect2i) -> void:
	_ring(img, at, Biomes.shade(spec, OUTLINE))


static func _ring(img: Image, at: Rect2i, c: Color) -> void:
	for x in at.size.x:
		_pixel(img, at.position + Vector2i(x, 0), c)
		_pixel(img, at.position + Vector2i(x, at.size.y - 1), c)
	for y in at.size.y:
		_pixel(img, at.position + Vector2i(0, y), c)
		_pixel(img, at.position + Vector2i(at.size.x - 1, y), c)


## A block in a fixed colour rather than the biome ramp - upholstery and paper.
static func _block(img: Image, at: Rect2i, body: Color, edge: Color) -> void:
	for y in at.size.y:
		for x in at.size.x:
			_pixel(img, at.position + Vector2i(x, y), body)
	_ring(img, at, edge)


## One tapering leaf, drawn as a walk out from the crown.
static func _leaf(img: Image, from: Vector2, dir: Vector2, length: float,
		body: Color, tip: Color) -> void:
	var steps := int(length)
	for i in steps:
		var along := from + dir * float(i)
		# Thick at the crown, one pixel at the tip: a frond, not a wire.
		var thick := 3 if i < steps / 2 else (2 if i < steps - 3 else 1)
		var c := body if i < steps - 2 else tip
		for w in thick:
			_pixel(img, Vector2i(int(round(along.x)) + w - thick / 2,
				int(round(along.y))), c)


## Centres a string horizontally in `width` and stamps it at `at.y`. Unknown
## characters advance without drawing, so a space is just a gap.
static func _text(img: Image, text: String, at: Vector2i, c: Color,
		width: int) -> void:
	var span := text.length() * GLYPH_ADVANCE - 1
	var x0: int = at.x + (width - span) / 2
	for i in text.length():
		var glyph: String = text[i].to_upper()
		if FONT.has(glyph):
			var rows: Array = FONT[glyph]
			for row in GLYPH_H:
				var line: String = rows[row]
				for col in GLYPH_W:
					if line[col] == "X":
						_pixel(img, Vector2i(x0 + col, at.y + row), c)
		x0 += GLYPH_ADVANCE


## The fixture painters were written against an explicit ramp and gamma rather
## than against a biome dictionary, so this keeps them reading as they did when
## they lived in build_biomes.gd. `Biomes.shade(spec, t)` is the same thing with
## the two pulled off the spec for you.
static func _ramp(ramp: Array, t: float, gamma: float) -> Color:
	return Biomes.ramp(ramp, t, gamma)


## Guarded so a painter can reach past the edge of its own art without the whole
## generator dying on an out-of-bounds pixel.
static func _pixel(img: Image, at: Vector2i, c: Color) -> void:
	if at.x >= 0 and at.y >= 0 and at.x < img.get_width() and at.y < img.get_height():
		img.set_pixel(at.x, at.y, c)


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
static func column(spec: Dictionary) -> Image:
	match spec.get("column", "classical"):
		"pillar":
			return _pillar(spec)
		"divider":
			return _divider(spec)
		_:
			return _classical_column(spec)


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
	var img := Image.create(TILE, height, false, Image.FORMAT_RGBA8)
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
			var c := _ramp(ramp, t, gamma)
			if y > 16 and y < 43 and x > 2 and x < 12:
				c = c.lerp(accent, 0.10)           # the fabric takes a dye
			img.set_pixel(x, y, c)
	# Feet, splayed either side so it looks free-standing rather than sunk in.
	for x in range(0, 5):
		img.set_pixel(x, 44, _ramp(ramp, 0.50, gamma))
		img.set_pixel(x, 45, _ramp(ramp, 0.12, gamma))
	for x in range(11, 16):
		img.set_pixel(x, 44, _ramp(ramp, 0.34, gamma))
		img.set_pixel(x, 45, _ramp(ramp, 0.10, gamma))
	return img


## A 16x48 glass-and-steel pillar: steel stiles either side of a glazed face,
## faintly tinted with the biome's accent the way a curtain wall is, capped top
## and bottom. Straight-sided, because a corporate lobby has no entasis.
static func _pillar(spec: Dictionary) -> Image:
	var height := 48
	var img := Image.create(TILE, height, false, Image.FORMAT_RGBA8)
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
			var c := _ramp(ramp, t, gamma)
			if x >= 4 and x <= 11 and not mullion:
				c = c.lerp(accent, 0.20)
			img.set_pixel(x, y, c)
	# Cap and base plate, both a tile wide so the pillar reads as fixed to the
	# floor and the ceiling rather than floating in the room.
	for x in TILE:
		img.set_pixel(x, 0, _ramp(ramp, 0.30, gamma))
		img.set_pixel(x, 1, _ramp(ramp, 0.98, gamma))
		img.set_pixel(x, 2, _ramp(ramp, 0.72, gamma))
		img.set_pixel(x, 45, _ramp(ramp, 0.90, gamma))
		img.set_pixel(x, 46, _ramp(ramp, 0.52, gamma))
		img.set_pixel(x, 47, _ramp(ramp, 0.08, gamma))
	return img


## A 16x48 column: abacus, flared echinus, fluted shaft, flared plinth.
## Drawn rather than sampled - the source sheet has no pillar of any kind.
static func _classical_column(spec: Dictionary) -> Image:
	var height := 48
	var img := Image.create(TILE, height, false, Image.FORMAT_RGBA8)
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
			img.set_pixel(left + dx, y, _ramp(ramp, t, gamma))
	return img


## The hazard slot, per-biome style like the column. Both styles are 16x24 with
## the same foot, so the hazard scene and the collision box the level places are
## untouched by the choice - only what the danger looks like changes. What must
## not change is that it reads as harmful at a glance, which is why the sparks
## are as generous as the flame is.
static func hazard(spec: Dictionary) -> Image:
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
				t = OUTLINE
			elif x <= 2:
				t = 0.62
			elif x >= 12:
				t = 0.26
			img.set_pixel(x, y, _ramp(ramp, t, gamma))
	# Sockets: four of them, all occupied.
	for i in 4:
		var x := 2 + i * 3
		img.set_pixel(x, 18, _ramp(ramp, OUTLINE, gamma))
		img.set_pixel(x + 1, 18, _ramp(ramp, OUTLINE, gamma))
		img.set_pixel(x, 19, _ramp(ramp, 0.86, gamma))
	# A daisy-chained second strip, because one was not enough for anybody.
	for x in range(4, 14):
		img.set_pixel(x, 14, _ramp(ramp, 0.34, gamma))
		img.set_pixel(x, 15, _ramp(ramp, 0.14, gamma))
	# The cables, going off in three directions and none of them tidy.
	for step in 8:
		img.set_pixel(mini(15, 14 + step / 4), 22 - step / 2,
			_ramp(ramp, 0.08, gamma))
		img.set_pixel(maxi(0, 1 - step / 6), mini(23, 17 + step / 3),
			_ramp(ramp, 0.08, gamma))
		img.set_pixel(3 + step / 3, mini(23, 22 + step / 7),
			_ramp(ramp, 0.10, gamma))

	# The short. Arcs between the sockets rather than off a spinning pad, and
	# the fixed spark colours are the same ones the polisher uses: whatever the
	# floor's palette, a hazard has to read as one.
	for arc in STRIP_ARCS:
		for at in arc:
			_pixel(img, at, SPARK_BODY)
	for at in STRIP_SPARKS:
		for step in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			_pixel(img, at + step, SPARK_BODY if at.y < 18 else SPARK_EDGE)
		_pixel(img, at, SPARK_CORE)
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
		img.set_pixel(x, 2, _ramp(ramp, 0.16, gamma))
		img.set_pixel(x, 3, _ramp(ramp, 0.88 if x <= 7 else 0.55, gamma))
	for y in range(4, 14):
		img.set_pixel(7, y, _ramp(ramp, 0.70, gamma))
		img.set_pixel(8, y, _ramp(ramp, 0.30, gamma))
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
			img.set_pixel(x, y, _ramp(ramp, t, gamma))
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
			img.set_pixel(x, y, _ramp(ramp, t, gamma))

	# The sparks, and they are as generous as the flame is on purpose: this is a
	# hazard, and a hazard the player reads as scenery is a hazard that feels
	# like the game cheating. Crosses rather than dots so a 16 px prop still
	# says "live" at 1x, in fixed colours for the same reason the flame is - a
	# hazard that took the room's palette would camouflage itself in it.
	for arc in ARCS:
		for at in arc:
			_pixel(img, at, SPARK_BODY)
	for at in SPARKS:
		for step in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			_pixel(img, at + step, SPARK_BODY if at.y < 20 else SPARK_EDGE)
		_pixel(img, at, SPARK_CORE)
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
		img.set_pixel(7, y, _ramp(ramp, 0.62, gamma))
		img.set_pixel(8, y, _ramp(ramp, 0.28, gamma))
	# Bowl the flame sits in.
	for x in range(5, 11):
		img.set_pixel(x, 9, _ramp(ramp, 0.20, gamma))
		img.set_pixel(x, 10, _ramp(ramp, 0.75 if x <= 7 else 0.40, gamma))
	# Plinth.
	for x in range(6, 10):
		img.set_pixel(x, 21, _ramp(ramp, 0.85, gamma))
	for x in range(5, 11):
		img.set_pixel(x, 22, _ramp(ramp, 0.50 if x <= 7 else 0.30, gamma))
		img.set_pixel(x, 23, _ramp(ramp, 0.10, gamma))

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


## The HEART mask coloured: lighter lobes, darker point, one pink glint.
static func heart() -> Image:
	var w: int = HEART[0].length()
	var img := Image.create(w, HEART.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in HEART.size():
		for x in w:
			if HEART[y][x] != "X":
				continue
			var c := Color("c8283c")
			if y <= 1:
				c = Color("e0465a")
			elif y >= 5:
				c = Color("8c1626")
			img.set_pixel(x, y, c)
	img.set_pixel(2, 1, Color("f2a0aa"))
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
