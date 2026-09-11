extends RefCounted
## Turns a restyled 32px cast frame into a 64px enemy: twice the player's
## height, and nothing else changed. Editor-side only, used by
## tools/build_enemies.gd to SEED a big enemy's sheet - never by the game.
##
## ## Why this is not tools/npc_art.gd
##
## The two do the same arithmetic and answer different briefs, which is exactly
## the split the placement rule is about. An NPC is twice the player's height
## *in a robe no wider than the player*, so npc_art.gd rebuilds the figure -
## robe first, head blended over it, hem swaying across the walk. A big enemy
## has no brief past "bigger": it still swings the sword the body came with, so
## every row of it - the attack rows included - has to survive the change, and
## the only honest operation is a straight doubling. Bubbling one file up to
## serve both would mean a robe parameter that the enemy always passes empty and
## a `keep_attack_rows` flag the NPC always passes false, which is two files
## wearing a trenchcoat.
##
## ## The ground line is the whole trick
##
## A 32px enemy is drawn at sprite offset -8, a 64px one at -24: cell centre at
## -8 puts the cell's bottom edge 8px below the body origin, and cell centre at
## -24 in a 64px cell puts it in exactly the same place. So a doubled body keeps
## the feet's ORIGINAL clearance from the bottom of the cell - not a doubled one
## - and lands on the same floor a guard stands on. That is npc_art.gd's rule
## and the reason both cells agree; get it wrong and the enemy hovers.
##
## Horizontally the doubling is centred on the cell centre, which makes the
## arithmetic self-consistent at the edges: a source body spanning the full 32px
## frame maps to exactly the full 64px cell, so a wide swing frame can never be
## pushed out of its own cell.
##
## ## What the seed costs, and why that is fine
##
## Nearest-neighbour 2x turns every source pixel into a 2x2 block, so the body's
## 1px outline arrives 2px thick. That is the same known debt npc_art.gd takes
## at `head_scale` 2, and on a body this size it reads as weight rather than as
## a mistake. It is also a SEED: the PNG is hand-owned from the moment it
## exists, so the fix is to redraw into it, never to change this file.

const Art := preload("res://tools/character_art.gd")

const FRAME := 32
const CELL := 64


## The tight bounding box of one source cell's drawn pixels, in sheet
## coordinates. Empty cells come back zero-sized and are left blank.
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
				box = box.expand(p + Vector2i.ONE)
	return box


## One 64px cell holding one doubled 32px frame.
static func _big(src: Image, ox: int, oy: int) -> Image:
	var dst := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
	var bb := _body_box(src, ox, oy)
	if bb.size == Vector2i.ZERO:
		return dst

	var body := src.get_region(bb)
	body.resize(bb.size.x * 2, bb.size.y * 2, Image.INTERPOLATE_NEAREST)

	# The feet keep the clearance they had in the 32px cell rather than twice
	# it, so this body drops onto the same ground line every other enemy stands
	# on - see the header. The sprite offset in the scene (-24 against -8) is
	# the only thing that ever has to know the cell grew.
	var bottom_gap := FRAME - (bb.position.y - oy + bb.size.y)
	var top := CELL - bottom_gap - bb.size.y * 2
	# Centred on the cell centre, so a full-width source frame lands as a
	# full-width destination cell and nothing can spill out of its own cell.
	var left := CELL / 2 + ((bb.position.x - ox) - FRAME / 2) * 2

	dst.blit_rect(body, Rect2i(Vector2i.ZERO, body.get_size()),
		Vector2i(left, top))
	return dst


## A sheet of 64px cells from a 32px one, row for row and column for column.
## Whatever rows the source has, the result has - this runs after
## build_enemies.gd has already cut the seed down to the rows its layout names,
## so a six-row enemy stays six rows and a nine-row one keeps its swing.
static func enlarge(styled: Image) -> Image:
	var rows := styled.get_height() / FRAME
	var cols := styled.get_width() / FRAME
	var out := Image.create(cols * CELL, rows * CELL, false, Image.FORMAT_RGBA8)
	for row in rows:
		for col in cols:
			var cell := _big(styled, col * FRAME, row * FRAME)
			out.blit_rect(cell, Rect2i(0, 0, CELL, CELL),
				Vector2i(col * CELL, row * CELL))
	return out
