extends RefCounted
## Turns a restyled 32px cast frame into a 64px NPC: twice the player's height,
## in a robe no wider than the player. Editor-side only, used by
## tools/build_npcs.gd to SEED an NPC's sheet - never by the game.
##
## ## Why an NPC is not just a recoloured character
##
## The cast is 14-15px tall in a 32px cell. Doubling that is ~29px, and with the
## clearance a sprite needs under its feet that will not fit a 32px cell at all,
## so an NPC sheet is cut at 64 - the size the bosses already slice at. Nothing
## else in the pipeline changes: character_art.slice() has taken a cell size
## since the first boss.
##
## ## The three parts of the figure, and the order they go down in
##
## The robe is drawn FIRST and the head is BLENDED over it, which is the one
## ordering that matters. Dominique's hair falls past the shoulders, and a head
## band pasted down first would be buried by the robe - losing the very thing
## that look was designed around. Drawn in the other order the hair lies on the
## robe, and reads from behind as a curtain over cloth.
##
## The robe itself is one column exactly the width of that direction's IDLE
## frame, collar to hem, held constant across all four columns of a walk. That
## is what "no wider than the player" means in practice: the width is measured
## off the cast body once per direction rather than per frame, so a swinging arm
## cannot make the robe bulge on frame two.
##
## A floor-length robe has no legs, so a walking NPC would otherwise glide. The
## hem drifts one pixel across the four columns instead - cloth, not footsteps -
## and the hands are kept where the source frame put them, so the arms still
## swing. An `ankle` hem keeps the cast's real feet and its real stepping.

const Art := preload("res://tools/character_art.gd")

const FRAME := 32
const CELL := 64
const COLS := 4
## Idle and walk in three directions - all a standing NPC can play. Same row
## numbers as the enemies' NO_ATTACK_LAYOUT, and for the same reason: rows
## nothing can ever play are dead weight in a hand-owned sheet.
const ROWS := 6

## Hem drift across the four walk columns.
const SWAY := [0, 1, 0, -1]
const SWAY_ROWS := 3

## The waist cord. Hemp, fixed for every NPC rather than taken from a recipe -
## the same argument that fixes fire and hearts: a rope is a rope everywhere.
const CORD := "c2a373"
const CORD_DARK := "8a7048"

const N4 := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

## What a `robe` block may say. Every key has a default, so `{}` is a legal robe.
const DEFAULTS := {
	## 1 keeps the cast's head on a doubled body - a tall, narrow figure.
	## 2 doubles the head with it, keeping the cast's chibi proportions.
	## Note that 2 doubles the head's OUTLINE too, to 2px against the robe's 1;
	## a head meant to stay at 2 wants redrawing by hand at that size.
	"head_scale": 1,
	## "floor" - hem on the ground, no feet, the hem sways.
	## "ankle" - hem above the shoe, the cast's own feet and steps kept.
	"hem": "floor",
	"leg_rows": 5,
	"cord": false,
	"sway": true,
}


static func _is(img: Image, x: int, y: int, hex: String) -> bool:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return false
	var p := img.get_pixel(x, y)
	return p.a > 0.0 and p.to_html(false) == hex


static func _put(dst: Image, x: int, y: int, hex: String) -> void:
	if x < 0 or y < 0 or x >= CELL or y >= CELL:
		return
	dst.set_pixel(x, y, Color(hex))


static func _body_box(img: Image, ox: int, oy: int) -> Rect2i:
	var box := Rect2i()
	var first := true
	for y in FRAME:
		for x in FRAME:
			if img.get_pixel(ox + x, oy + y).a == 0.0:
				continue
			var p := Vector2i(ox + x, oy + y)
			if first:
				box = Rect2i(p, Vector2i.ONE)
				first = false
			else:
				box = box.expand(p).expand(p + Vector2i.ONE)
	return box


## First row of the garment - where the head stops and the robe starts.
static func _shirt_top(img: Image, ox: int, oy: int, recipe: Dictionary) -> int:
	var best := -1
	for y in FRAME:
		for x in FRAME:
			if _is(img, ox + x, oy + y, recipe["shirt"]) \
					or _is(img, ox + x, oy + y, recipe["shirt_dark"]):
				if best < 0 or oy + y < best:
					best = oy + y
	return best


static func _touches_hair(src: Image, x: int, y: int, recipe: Dictionary) -> bool:
	for n in N4:
		if _is(src, x + n.x, y + n.y, recipe["hair"]) \
				or _is(src, x + n.x, y + n.y, recipe["hair_light"]):
			return true
	return false


## The head as its own little image: everything above the collar copied whole,
## and below the collar ONLY hair and the outline hugging it. That split is what
## carries long hair down onto the robe while leaving the cast's shoulders and
## arms behind, which the robe is replacing.
static func _head_band(src: Image, bb: Rect2i, shirt_top: int,
		recipe: Dictionary) -> Image:
	var hair_bottom := shirt_top
	for y in range(shirt_top, bb.position.y + bb.size.y):
		for x in bb.size.x:
			if _is(src, bb.position.x + x, y, recipe["hair"]) \
					or _is(src, bb.position.x + x, y, recipe["hair_light"]):
				hair_bottom = maxi(hair_bottom, y + 1)

	var band := Image.create(bb.size.x, hair_bottom - bb.position.y,
		false, Image.FORMAT_RGBA8)
	for y in band.get_height():
		var sy := bb.position.y + y
		for x in bb.size.x:
			var sx := bb.position.x + x
			var p := src.get_pixel(sx, sy)
			if p.a == 0.0:
				continue
			if sy < shirt_top:
				band.set_pixel(x, y, p)
				continue
			var hex := p.to_html(false)
			if hex == recipe["hair"] or hex == recipe["hair_light"]:
				band.set_pixel(x, y, p)
			elif hex == Art.SRC_OUTLINE and _touches_hair(src, sx, sy, recipe):
				band.set_pixel(x, y, p)
	return band


## One 64px cell. `ref` is the robe's x span in source coordinates, taken from
## this direction's idle frame so the column is identical in every frame of the
## walk.
static func _tall(src: Image, ox: int, oy: int, col: int, recipe: Dictionary,
		robe: Dictionary, ref: Vector2i) -> Image:
	var dst := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
	var bb := _body_box(src, ox, oy)
	if bb.size == Vector2i.ZERO:
		return dst

	var shirt_top := _shirt_top(src, ox, oy, recipe)
	if shirt_top < 0:
		shirt_top = bb.position.y + bb.size.y / 2

	# Feet keep the same clearance from the cell floor as the 32px original, so
	# a 64px NPC drops onto the same ground line a 32px enemy stands on - and
	# the scene's sprite offset is the only thing that has to know the cell got
	# bigger.
	var bottom_gap := FRAME - (bb.position.y - oy + bb.size.y)
	var new_bottom := CELL - bottom_gap
	var new_top := new_bottom - bb.size.y * 2

	var scale: int = robe["head_scale"]
	var off_x := (CELL - FRAME) / 2
	var robe_x0 := off_x + ref.x
	var robe_x1 := off_x + ref.y
	var robe_cx := (robe_x0 + robe_x1) / 2

	var band := _head_band(src, bb, shirt_top, recipe)
	var head_x := off_x + (bb.position.x - ox)
	if scale > 1:
		band.resize(band.get_width() * scale, band.get_height() * scale,
			Image.INTERPOLATE_NEAREST)
		head_x = robe_cx - band.get_width() / 2

	# 1. The legs, if this robe stops short of the floor.
	var leg_rows := 0
	if robe["hem"] == "ankle":
		leg_rows = int(robe["leg_rows"])
		var src_legs_top := bb.position.y + bb.size.y - leg_rows
		for y in leg_rows:
			for x in bb.size.x:
				var p := src.get_pixel(bb.position.x + x, src_legs_top + y)
				if p.a > 0.0:
					dst.set_pixel(off_x + (bb.position.x - ox) + x,
						new_bottom - leg_rows + y, p)

	# 2. The robe: one column, the player's width, collar to hem.
	var robe_top := new_top + (shirt_top - bb.position.y) * scale
	var robe_bottom := new_bottom - leg_rows
	var shade_from := robe_x1 - 2
	for y in range(robe_top, robe_bottom):
		var dx := 0
		if y >= robe_bottom - SWAY_ROWS:
			dx = SWAY[col] if robe["sway"] else 0
		for x in range(robe_x0, robe_x1 + 1):
			var hex: String = recipe["shirt"]
			if x == robe_x0 or x == robe_x1:
				hex = Art.SRC_OUTLINE
			elif x >= shade_from:
				hex = recipe["shirt_dark"]
			if y == robe_bottom - 1 and robe["hem"] == "floor":
				hex = Art.SRC_OUTLINE
			_put(dst, x + dx, y, hex)

	# 3. The waist cord, if this robe is belted.
	if robe["cord"]:
		var cord_y := robe_top + int((robe_bottom - robe_top) * 0.42)
		for x in range(robe_x0 + 1, robe_x1):
			_put(dst, x, cord_y, CORD)
			_put(dst, x, cord_y + 1, CORD_DARK)
		# A short tail hanging off the knot, left of centre.
		var knot_x := robe_cx - 1
		_put(dst, knot_x, cord_y + 2, CORD)
		_put(dst, knot_x, cord_y + 3, CORD_DARK)

	# 4. The head, hair and all, laid OVER the robe - see the note up top.
	dst.blend_rect(band, Rect2i(Vector2i.ZERO, band.get_size()),
		Vector2i(head_x, new_top))

	# 5. The hands, kept from the source so the walk still swings them.
	var arm_y := robe_top + int((robe_bottom - robe_top) * 0.22)
	for y in range(shirt_top, bb.position.y + bb.size.y):
		for x in bb.size.x:
			var sx := bb.position.x + x
			if not _is(src, sx, y, recipe["skin"]):
				continue
			var ty := arm_y + (y - shirt_top)
			var tx := off_x + (sx - ox)
			if tx <= robe_x0 or tx >= robe_x1:
				continue  # a sleeve that wide is not a hand
			_put(dst, tx, ty, recipe["skin"])
			var outward := -1 if sx - ox < (ref.x + ref.y) / 2 else 1
			if _is(dst, tx + outward, ty, recipe["shirt"]) \
					or _is(dst, tx + outward, ty, recipe["shirt_dark"]):
				_put(dst, tx + outward, ty, Art.SRC_OUTLINE)
	return dst


static func _reference(src: Image, row: int) -> Vector2i:
	var bb := _body_box(src, 0, row * FRAME)
	return Vector2i(bb.position.x, bb.position.x + bb.size.x - 1)


## A 4x6 sheet of 64px cells from a restyled 32px cast sheet. `robe` may leave
## out any key in DEFAULTS.
static func build(styled: Image, recipe: Dictionary, robe: Dictionary) -> Image:
	var opts := DEFAULTS.duplicate()
	opts.merge(robe, true)

	var out := Image.create(COLS * CELL, ROWS * CELL, false, Image.FORMAT_RGBA8)
	for row in ROWS:
		# Rows pair up idle/walk per direction; both take the idle frame's width.
		var ref := _reference(styled, row - (row % 2))
		for col in COLS:
			var cell := _tall(styled, col * FRAME, row * FRAME, col, recipe, opts, ref)
			out.blit_rect(cell, Rect2i(0, 0, CELL, CELL),
				Vector2i(col * CELL, row * CELL))
	return out
