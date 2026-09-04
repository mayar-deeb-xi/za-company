extends RefCounted
## The media team's edit bay: two big screens on one desk, both lit, one
## cutting and one previewing. The wide silhouette is the point - it is what
## tells you at a glance that the far half of this floor is not more cubicles.
##
## The screens are the brightest thing in the room after the hazard, because a
## dark room full of dark monitors is a dark room. Their content comes off the
## biome accent so the glow belongs to the floor, while the dead-screen dark
## and the record light stay fixed, like every other screen in the catalogue.

const Brush := preload("../_brush.gd")

const SIZE := Vector2i(56, 32)
const BLOCKS := Vector2(52, 7)


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var w: int = SIZE.x
	var glow: Color = Color(spec["accent"])
	_timeline(img, spec, glow)
	_preview(img, spec, glow)
	# Two necks rather than one: a pair of arms is what a two-screen rig looks
	# like from the front, and it keeps the desktop reading as one surface.
	for stem in [13, 41]:
		for y in range(15, 18):
			Brush.row(img, spec, y, stem, stem + 3, 0.28)
	Brush.slab(img, spec, Rect2i(0, 17, w, 7), 0.80)
	Brush.panel(img, spec, Rect2i(2, 24, w - 4, 8), 0.38)
	# The cable bundle, which on this floor is furniture: everything on the
	# desk feeds something under it.
	for strand in [Vector2i(46, 28), Vector2i(49, 28)]:
		for step in 4:
			Brush.pixel(img, strand + Vector2i(step / 2, step),
				Brush.shade(spec, 0.08))
	_keyboard(img, spec, glow)
	return img


## Left screen: the cut in progress. Three stacked tracks and a playhead, which
## is the one screen shape everybody reads as video without being told.
static func _timeline(img: Image, spec: Dictionary, glow: Color) -> void:
	var bezel := Rect2i(1, 0, 26, 16)
	Brush.fill(img, spec, bezel, 0.14)
	Brush.outline(img, spec, bezel)
	var screen := Rect2i(3, 2, 22, 12)
	for y in screen.size.y:
		for x in screen.size.x:
			Brush.pixel(img, screen.position + Vector2i(x, y), Brush.SCREEN)
	# Three tracks of clips, cut at different points.
	for track in 3:
		var y := 4 + track * 3
		var cuts: Array = [[4, 11], [13, 20], [21, 24]][track]
		for x in range(cuts[0], cuts[1]):
			Brush.pixel(img, Vector2i(x, y), glow.darkened(0.2 + 0.15 * track))
			Brush.pixel(img, Vector2i(x, y + 1), glow.darkened(0.45 + 0.15 * track))
	# The playhead, parked mid-clip.
	for y in range(3, 14):
		Brush.pixel(img, Vector2i(16, y), Brush.PAPER)


## Right screen: what the cut looks like. A bright frame with a horizon in it,
## the record dot, and a progress bar - a picture rather than a spreadsheet, so
## the two screens do not read as the same screen twice.
static func _preview(img: Image, spec: Dictionary, glow: Color) -> void:
	var bezel := Rect2i(29, 0, 26, 16)
	Brush.fill(img, spec, bezel, 0.14)
	Brush.outline(img, spec, bezel)
	var screen := Rect2i(31, 2, 22, 12)
	for y in screen.size.y:
		for x in screen.size.x:
			# Lit from the top: a frame under a light, not a flat swatch.
			var t := 0.92 - 0.05 * float(y)
			Brush.pixel(img, screen.position + Vector2i(x, y), Brush.shade(spec, t))
	for x in range(31, 53):
		Brush.pixel(img, Vector2i(x, 9), Brush.shade(spec, 0.34))
		Brush.pixel(img, Vector2i(x, 10), Brush.shade(spec, 0.22))
	# Whoever is on camera, at this size: a head and shoulders in silhouette.
	for y in range(6, 10):
		for x in range(39, 45):
			Brush.pixel(img, Vector2i(x, y), Brush.shade(spec, 0.16))
	Brush.pixel(img, Vector2i(51, 3), Brush.LED_BAD)
	for x in range(32, 44):
		Brush.pixel(img, Vector2i(x, 12), glow)


## A keyboard on the desktop, drawn after the slab so it sits on the surface.
static func _keyboard(img: Image, spec: Dictionary, glow: Color) -> void:
	var pad := Rect2i(18, 19, 21, 5)
	Brush.fill(img, spec, pad, 0.18)
	Brush.outline(img, spec, pad)
	for x in range(20, 37, 2):
		Brush.pixel(img, Vector2i(x, 21), Brush.shade(spec, 0.70))
	Brush.pixel(img, Vector2i(37, 20), glow)
