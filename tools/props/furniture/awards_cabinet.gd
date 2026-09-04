extends RefCounted
## DESIGN.md's awards cabinet: a lit, glass-fronted case of the prizes the
## company has given itself. The tallest piece of furniture in the catalogue -
## nearly twice a character - because a trophy cabinet is a wall unit, and
## because the point of it is to be the thing you look at when you walk in.
##
## The trophies are the third fixed colour in the catalogue, after the cooler's
## water and the coffee, and for the same reason: a trophy is gold in every
## room. Take it off the biome's ramp and hellfire hands out iron cups.

const Brush := preload("../_brush.gd")

## Plate, and the tarnish in its shadows.
const GOLD := Color("e6b73f")
const GOLD_DARK := Color("9c7220")

const SIZE := Vector2i(44, 44)
const BLOCKS := Vector2(40, 6)

## The prizes, as pixel maps: G is plate, d is the tarnished side. Two shapes
## rather than one, so a shelf of them reads as a collection instead of as a
## repeat - a cup for the years they won something and a star for the years
## they had to invent a category.
const CUP := [
	".GGGGG.",
	"G.GGG.G",
	"G.GGd.G",
	"G.GGd.G",
	".GGGd..",
	"..GGd..",
	"...d...",
	"..GGG..",
	".GGddd.",
]
const STAR := [
	"....G....",
	"...GGG...",
	"GGGGGGGGG",
	".GGGGGdd.",
	"..GGGdd..",
	"..GG.dd..",
	".GG...dd.",
	"....d....",
	"..ddddd..",
]

## Which prize stands where, per shelf: the base row, then the x of each piece
## and which map it is.
const SHELVES := [
	[14, [[6, CUP], [16, STAR], [30, CUP]]],
	[24, [[5, STAR], [18, CUP], [27, STAR]]],
	[34, [[7, CUP], [17, CUP], [28, STAR]]],
]


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var w: int = SIZE.x
	var accent: Color = Color(spec["accent"])
	# Cornice, case, plinth: the three pieces of any wall unit, and the cornice
	# is what stops it reading as a bookshelf.
	Brush.slab(img, spec, Rect2i(0, 0, w, 4), 0.66)
	Brush.panel(img, spec, Rect2i(1, 3, w - 2, 35), 0.24)
	# The lining of the case, a shade up from its outside so the opening reads
	# as a space rather than as a panel.
	Brush.fill(img, spec, Rect2i(4, 5, w - 8, 32), 0.32)
	# Shelves, each with its strip light under the board. The lights are what
	# make a cabinet read as a DISPLAY cabinet; unlit it is a cupboard.
	for shelf: Array in SHELVES:
		var base: int = shelf[0]
		Brush.row(img, spec, base + 1, 4, w - 4, 0.58)
		for x in range(5, w - 5):
			Brush.pixel(img, Vector2i(x, base + 2), accent.lightened(0.45))
		for piece: Array in shelf[1]:
			_stamp(img, piece[1], Vector2i(piece[0], base - 8))
	# The glazing, and it is a GLINT rather than a wash: the trophies are the
	# whole point of the prop, and a flat translucent pane over them turns
	# three shelves of gold into three shelves of grey. Two short diagonals
	# lifted off what is already painted read as a pane catching the light -
	# and they are short on purpose, because a streak run corner to corner
	# reads as a crack in the glass instead of a reflection in it.
	for glint: Array in [[7, 6, 15], [17, 6, 9]]:
		for step in glint[2]:
			for band in 2:
				var at := Vector2i(glint[0] + step + band, glint[1] + step)
				if at.x < 5 or at.x > w - 6 or at.y > 36:
					continue
				img.set_pixel(at.x, at.y,
					img.get_pixel(at.x, at.y).lerp(Color(1, 1, 1, 1), 0.30))
	# The doors: a post down the middle and a brass handle either side of it,
	# which is the detail that says the glass can be opened and the prizes
	# cannot be reached.
	for y in range(5, 37):
		Brush.pixel(img, Vector2i(w / 2, y), Brush.shade(spec, 0.50))
	for y in range(19, 24):
		Brush.pixel(img, Vector2i(w / 2 - 2, y), accent)
		Brush.pixel(img, Vector2i(w / 2 + 2, y), accent.darkened(0.25))
	Brush.panel(img, spec, Rect2i(0, 37, w, 5), 0.16)
	for x in range(1, w - 1):
		Brush.pixel(img, Vector2i(x, 43), Brush.shade(spec, 0.08))
	return img


static func _stamp(img: Image, map: Array, at: Vector2i) -> void:
	for y in map.size():
		var row: String = map[y]
		for x in row.length():
			match row[x]:
				"G":
					Brush.pixel(img, at + Vector2i(x, y), GOLD)
				"d":
					Brush.pixel(img, at + Vector2i(x, y), GOLD_DARK)
