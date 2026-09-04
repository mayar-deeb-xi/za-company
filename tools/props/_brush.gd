extends RefCounted
## The shared brush kit every prop painter draws with. The underscore in the
## filename is what keeps it out of the catalogue: props.gd treats every other
## file in this folder as a placeable prop type, named by its filename.
##
## Two rules of the house style live here rather than in any one painter, so a
## new prop gets them by using the kit at all: a body is lit from the left, and
## it is outlined all round in a shade dark enough to hold its silhouette
## against a pale marble floor and a hot hellfire one alike.
##
## Fixed colours that appear in SEVERAL props are here too; a colour one prop
## owns outright (the cooler's water, the plant's leaves) lives in that prop's
## own file. Everything else comes off the biome's ramp through shade(), so the
## same painter yields a lobby-blue desk and a bullpen-brown one.

const Biomes := preload("res://tools/biomes.gd")

## One tile - what the column and hazard canvases are sized against.
const TILE := 16

## Silhouette outline shade.
const OUTLINE := 0.05

## A dead display is the darkest thing in any room, which is what says "off".
const SCREEN := Color("18222e")
## Status lights read as status in any palette, which is the point of having one
## of them be red: a rack with a red light is a rack with something wrong in it,
## and that is the whole fiction of the maintenance floor in two pixels.
const LED_OK := Color("4fe08a")
const LED_BAD := Color("e8443c")
const PCB := Color("2f6b3a")
const PAPER := Color("f4f1e6")
const INK := Color("1e1c1a")

## A 5x5 font, uppercase and digits, one glyph per key, advanced 6 px. Small
## enough to
## letter a banner inside the 640x360 viewport and still be read: half of what
## makes a company office funny is what is written on the walls, and DESIGN.md
## hangs wall text on four more floors. Row-major, X = filled.
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
	# Digits, added for the call floor's wallboard: a board that counts calls
	# and cannot write a number is a board with nothing to say.
	"0": [".XXX.", "X..XX", "X.X.X", "XX..X", ".XXX."],
	"1": ["..X..", ".XX..", "..X..", "..X..", ".XXX."],
	"2": ["XXXX.", "....X", "..XX.", ".X...", "XXXXX"],
	"3": ["XXXX.", "....X", ".XXX.", "....X", "XXXX."],
	"4": ["X..X.", "X..X.", "XXXXX", "...X.", "...X."],
	"5": ["XXXXX", "X....", "XXXX.", "....X", "XXXX."],
	"6": [".XXX.", "X....", "XXXX.", "X...X", ".XXX."],
	"7": ["XXXXX", "....X", "...X.", "..X..", ".X..."],
	"8": [".XXX.", "X...X", ".XXX.", "X...X", ".XXX."],
	"9": [".XXX.", "X...X", ".XXXX", "....X", ".XXX."],
}
const GLYPH_W := 5
const GLYPH_H := 5
const GLYPH_ADVANCE := 6


## A transparent canvas at the prop's own size - how every paint() starts.
static func blank(size: Vector2i) -> Image:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


## The biome's ramp at t (0 darkest, 1 brightest), bent by its gamma.
static func shade(spec: Dictionary, t: float) -> Color:
	return Biomes.shade(spec, t)


## The same with ramp and gamma passed explicitly - the fixture painters were
## written against this form and read better keeping it.
static func ramp(stops: Array, t: float, gamma: float) -> Color:
	return Biomes.ramp(stops, t, gamma)


## A flat top surface: brightest at the back edge, so it reads as a plane the
## room is looking down onto rather than a wall.
static func slab(img: Image, spec: Dictionary, at: Rect2i, tone: float) -> void:
	for y in at.size.y:
		var t := clampf(tone - 0.05 * float(y), 0.0, 1.0)
		for x in at.size.x:
			var s := t
			if x >= at.size.x - 2:
				s = maxf(t - 0.20, 0.0)
			pixel(img, at.position + Vector2i(x, y), shade(spec, s))
	outline(img, spec, at)


## A vertical face: the front of a desk or the body of a cooler.
static func panel(img: Image, spec: Dictionary, at: Rect2i, tone: float) -> void:
	for y in at.size.y:
		for x in at.size.x:
			var t := tone
			if x <= 1:
				t = tone + 0.16
			elif x >= at.size.x - 2:
				t = tone - 0.14
			pixel(img, at.position + Vector2i(x, y), shade(spec, t))
	outline(img, spec, at)


static func fill(img: Image, spec: Dictionary, at: Rect2i, tone: float) -> void:
	for y in at.size.y:
		for x in at.size.x:
			pixel(img, at.position + Vector2i(x, y), shade(spec, tone))


static func row(img: Image, spec: Dictionary, y: int, from_x: int, to_x: int,
		tone: float) -> void:
	for x in range(from_x, to_x):
		pixel(img, Vector2i(x, y), shade(spec, tone))


static func outline(img: Image, spec: Dictionary, at: Rect2i) -> void:
	ring(img, at, shade(spec, OUTLINE))


static func ring(img: Image, at: Rect2i, c: Color) -> void:
	for x in at.size.x:
		pixel(img, at.position + Vector2i(x, 0), c)
		pixel(img, at.position + Vector2i(x, at.size.y - 1), c)
	for y in at.size.y:
		pixel(img, at.position + Vector2i(0, y), c)
		pixel(img, at.position + Vector2i(at.size.x - 1, y), c)


## A block in a fixed colour rather than the biome ramp - upholstery and paper.
static func block(img: Image, at: Rect2i, body: Color, edge: Color) -> void:
	for y in at.size.y:
		for x in at.size.x:
			pixel(img, at.position + Vector2i(x, y), body)
	ring(img, at, edge)


## Centres a string horizontally in `width` and stamps it at `at.y`. Unknown
## characters advance without drawing, so a space is just a gap.
static func text(img: Image, string: String, at: Vector2i, c: Color,
		width: int) -> void:
	var span := string.length() * GLYPH_ADVANCE - 1
	var x0: int = at.x + (width - span) / 2
	for i in string.length():
		var glyph: String = string[i].to_upper()
		if FONT.has(glyph):
			var rows: Array = FONT[glyph]
			for r in GLYPH_H:
				var line: String = rows[r]
				for col in GLYPH_W:
					if line[col] == "X":
						pixel(img, Vector2i(x0 + col, at.y + r), c)
		x0 += GLYPH_ADVANCE


## Guarded so a painter can reach past the edge of its own art without the whole
## generator dying on an out-of-bounds pixel.
static func pixel(img: Image, at: Vector2i, c: Color) -> void:
	if at.x >= 0 and at.y >= 0 and at.x < img.get_width() and at.y < img.get_height():
		img.set_pixel(at.x, at.y, c)
