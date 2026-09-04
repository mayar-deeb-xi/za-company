extends RefCounted
## An engineer's workstation, and the fourth desk in the catalogue: the plain
## `desk` has one screen nobody is looking at, the `call_desk` has a phone, the
## `edit_desk` has two screens side by side, and this has the arrangement only
## developers actually build - one wide screen with a second one turned on its
## side next to it.
##
## The portrait monitor is the whole silhouette. Nobody else in the building
## turns a screen sideways, so at a glance it is what says this floor writes
## software rather than uses it.

const Brush := preload("../_brush.gd")

const SIZE := Vector2i(48, 27)
const BLOCKS := Vector2(44, 7)

## A rubber duck is yellow everywhere, the same argument that fixes water and
## foliage: a duck in the biome's palette would be a duck made of desk.
const DUCK := Color("f5d020")
const DUCK_LIT := Color("ffe97a")
const BEAK := Color("ef8a1e")

## Debugging companion, 6x5, drawn rather than described - at this size which
## six pixels are yellow is the difference between a duck and a sticky note.
const DUCKLING := [
	"..dd..",
	".dddb.",
	"ddddd.",
	".dddd.",
	"..dd..",
]


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var w: int = SIZE.x
	var glow: Color = Color(spec["accent"])
	_ultrawide(img, spec, glow)
	_portrait(img, spec, glow)
	# One neck each. The wide screen's is central, the portrait one's is off to
	# the side, which is what an arm clamped to the desk edge looks like.
	for stem in [16, 39]:
		for y in range(13, 16):
			Brush.row(img, spec, y, stem, stem + 3, 0.30)
	Brush.slab(img, spec, Rect2i(0, 15, w, 6), 0.86)
	Brush.panel(img, spec, Rect2i(2, 20, w - 4, 7), 0.44)
	# The drawer nobody opens, with an accent handle like every other desk here.
	var drawer := Rect2i(5, 21, 14, 5)
	Brush.outline(img, spec, drawer)
	for x in range(9, 16):
		Brush.pixel(img, Vector2i(x, 23), glow)
	_keyboard(img, spec, glow)
	_mug(img, spec)
	_duck(img)
	return img


## The wide screen: code on it, which at this size is four indented rows of
## accent with a cursor at the end of one of them.
static func _ultrawide(img: Image, spec: Dictionary, glow: Color) -> void:
	var bezel := Rect2i(2, 0, 31, 14)
	Brush.fill(img, spec, bezel, 0.14)
	Brush.outline(img, spec, bezel)
	var screen := Rect2i(4, 2, 27, 10)
	for y in screen.size.y:
		for x in screen.size.x:
			Brush.pixel(img, screen.position + Vector2i(x, y), Brush.SCREEN)
	# Indented lines, because indentation is what code looks like from across a
	# room. Each row starts further in and stops somewhere different.
	var lines := [[5, 24], [7, 19], [9, 27], [7, 15], [5, 21]]
	for i in lines.size():
		var run: Array = lines[i]
		for x in range(run[0], run[1]):
			Brush.pixel(img, Vector2i(x, 3 + i * 2),
				glow.lightened(0.25 if i % 2 == 0 else 0.0))
	Brush.pixel(img, Vector2i(22, 11), Brush.PAPER)


## The second screen, turned on its side: a wall of text, which is what anybody
## rotates a monitor to look at.
static func _portrait(img: Image, spec: Dictionary, glow: Color) -> void:
	var bezel := Rect2i(34, 1, 13, 13)
	Brush.fill(img, spec, bezel, 0.14)
	Brush.outline(img, spec, bezel)
	var screen := Rect2i(36, 3, 9, 9)
	for y in screen.size.y:
		for x in screen.size.x:
			Brush.pixel(img, screen.position + Vector2i(x, y), Brush.SCREEN)
	for i in 4:
		for x in range(37, 44 - i % 2 * 2):
			Brush.pixel(img, Vector2i(x, 4 + i * 2), glow.darkened(0.15 * i))


## A mechanical keyboard: the one on this floor gets its own accent row, since
## the people who buy them buy them lit.
static func _keyboard(img: Image, spec: Dictionary, glow: Color) -> void:
	var pad := Rect2i(11, 17, 24, 4)
	Brush.fill(img, spec, pad, 0.16)
	Brush.outline(img, spec, pad)
	for x in range(13, 33, 2):
		Brush.pixel(img, Vector2i(x, 18), glow.lightened(0.35))
	for x in range(13, 33):
		Brush.pixel(img, Vector2i(x, 19), Brush.shade(spec, 0.62))


static func _mug(img: Image, spec: Dictionary) -> void:
	for y in range(11, 16):
		for x in range(41, 45):
			Brush.pixel(img, Vector2i(x, y), Brush.shade(spec, 0.98 if x < 43 else 0.72))
	Brush.pixel(img, Vector2i(41, 11), Brush.shade(spec, Brush.OUTLINE))
	Brush.pixel(img, Vector2i(44, 11), Brush.shade(spec, Brush.OUTLINE))
	Brush.pixel(img, Vector2i(45, 12), Brush.shade(spec, 0.40))
	Brush.pixel(img, Vector2i(45, 13), Brush.shade(spec, 0.40))


## Sitting on the desktop where it can be talked to.
static func _duck(img: Image) -> void:
	for y in DUCKLING.size():
		var row: String = DUCKLING[y]
		for x in row.length():
			match row[x]:
				"d":
					Brush.pixel(img, Vector2i(4 + x, 11 + y),
						DUCK_LIT if x < 2 else DUCK)
				"b":
					Brush.pixel(img, Vector2i(4 + x, 11 + y), BEAK)
	Brush.pixel(img, Vector2i(7, 12), Brush.INK)
