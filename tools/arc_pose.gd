extends RefCounted
## ARC - the combo's third hit, seeded into the cast sheet ONCE.
##
## The sheet is hand-owned art (game/player/src/character_cc0.png) and this
## file is how its three newest rows came to exist, on the enemies' exact
## terms: build_characters.gd calls `seed()` only while the sheet is too short
## to hold them, writes the result back, and from then on slices whatever is
## on disk. Redrawing a frame is done in the PNG, never here - this painter is
## the record of the first draft, not the truth about the current one.
##
## The pose is a THRUST AND HOLD in every facing: wind the blade back, drive
## it out level (side), down (down) or overhead (up), hold it while the tip
## forks, then let the line break into dashes. It is built from the idle body
## of each facing with the weapon arm extended where the facing shows one, so
## the head, torso and legs are the cast's own pixels and only the arm and the
## blade are new. Everything is drawn in the SRC_VOLT palette, which is what
## `character_art.restyle()` recolours to each character's spark - Mayar's
## arc is violet, Anas's is gold, for free, the way the swing's already is.
##
## The BOLT that jumps between enemies is not here: it is drawn live by
## game/player/arc.gd, because a chain between two bodies has no fixed shape
## a sheet could hold.

const Art := preload("res://tools/character_art.gd")

const FRAME := Art.FRAME
## Where the three facings land, and the height the sheet must reach.
const ROWS := {"down": 21, "up": 22, "side": 23}
const ROWS_NEEDED := 24
## The idle row each facing's body is lifted from.
const IDLE := {"down": 0, "up": 2, "side": 4}

const W := Art.SRC_VOLT_CORE
const V := Art.SRC_VOLT
const E := Art.SRC_VOLT_EDGE
const D := Art.SRC_VOLT_DARK
const S := Art.SRC_SKIN


## Grows a 21-row cast sheet to 24 rows and paints the arc into rows 21-23.
## A sheet already tall enough is returned untouched, so this can never
## overwrite a frame somebody has drawn into.
static func seed(img: Image) -> Image:
	if img.get_height() >= ROWS_NEEDED * FRAME:
		return img
	var out := Image.create(img.get_width(), ROWS_NEEDED * FRAME, false, Image.FORMAT_RGBA8)
	out.blit_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i.ZERO)
	for facing in ROWS:
		var frames: Array = _frames(facing)
		for col in Art.COLS:
			var ox := col * FRAME
			var oy: int = ROWS[facing] * FRAME
			var idle := out.get_region(Rect2i(0, IDLE[facing] * FRAME, FRAME, FRAME))
			out.blit_rect(idle, Rect2i(0, 0, FRAME, FRAME), Vector2i(ox, oy))
			var frame: Dictionary = frames[col]
			if frame.has("arm"):
				_extend_arm(out, ox, oy, frame["arm"])
			for px in frame.get("paint", []):
				out.set_pixel(ox + px[0], oy + px[1], Color(px[2]))
	return out


## The weapon arm reaching out of the torso: skin pixels, then an outline grown
## around them wherever they meet clear cell - the same rule the hair shaping
## in character_art.gd uses, applied to three pixels of arm.
static func _extend_arm(img: Image, ox: int, oy: int, arm: Array) -> void:
	for px in arm:
		img.set_pixel(ox + px[0], oy + px[1], Color(S))
	for px in arm:
		for n in Art.N4:
			var x: int = ox + px[0] + n.x
			var y: int = oy + px[1] + n.y
			if Art._clear(img, x, y):
				img.set_pixel(x, y, Color(Art.SRC_OUTLINE))


## Four frames per facing: wind, thrust, arc, recover. Each is an optional
## `arm` (skin pixels to add to the idle body) and `paint` (x, y, hex).
static func _frames(facing: String) -> Array:
	match facing:
		"side":
			var arm := [[18, 18], [19, 18], [20, 18]]
			return [
				{"paint": [[6, 17, V], [7, 17, W], [8, 17, W], [9, 17, W], [10, 17, W]]},
				{"arm": arm, "paint": _line(21, 18, 28, 18, W) + [[29, 18, V], [27, 17, E], [28, 19, E]]},
				{"arm": arm, "paint": _line(21, 18, 28, 18, W) + [
					[29, 18, W], [30, 18, W],
					[30, 17, V], [31, 16, V], [30, 19, V], [31, 20, V],
					[29, 16, E], [29, 20, E]]},
				{"paint": [[21, 18, E], [23, 18, E], [25, 18, E], [27, 18, E], [28, 18, D], [29, 18, D]]},
			]
		"down":
			return [
				{"paint": [[22, 18, W], [23, 17, W], [24, 16, W], [25, 15, W], [26, 14, V]]},
				{"paint": _line(22, 21, 22, 27, W) + [[22, 28, V], [21, 26, E], [23, 27, E]]},
				{"paint": _line(22, 21, 22, 27, W) + [
					[22, 28, W], [22, 29, W],
					[21, 29, V], [20, 30, V], [23, 29, V], [24, 30, V],
					[19, 31, E], [25, 31, E]]},
				{"paint": [[22, 22, E], [22, 24, E], [22, 26, E], [22, 27, D], [22, 28, D]]},
			]
		_:  # up
			return [
				{"paint": [[22, 21, W], [23, 22, W], [24, 23, W], [25, 24, V]]},
				{"paint": _line(22, 10, 22, 18, W) + [[22, 9, V], [21, 11, E], [23, 10, E]]},
				{"paint": _line(22, 10, 22, 18, W) + [
					[22, 9, W], [22, 8, W],
					[21, 8, V], [20, 7, V], [23, 8, V], [24, 7, V],
					[19, 6, E], [25, 6, E]]},
				{"paint": [[22, 17, E], [22, 15, E], [22, 13, E], [22, 11, D], [22, 10, D]]},
			]


## A straight run of one colour, horizontal or vertical, both ends inclusive.
static func _line(x0: int, y0: int, x1: int, y1: int, hex: String) -> Array:
	var out := []
	for x in range(mini(x0, x1), maxi(x0, x1) + 1):
		for y in range(mini(y0, y1), maxi(y0, y1) + 1):
			out.append([x, y, hex])
	return out
