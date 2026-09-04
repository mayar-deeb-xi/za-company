extends RefCounted
## The rug in the executive gallery, and the second thing on the markings
## shelf. Same two rules as the boxing ring, for the same two reasons: it
## blocks nothing, and it pins its TOP-LEFT corner so Y-sorting draws it before
## everybody standing on it. Pinned at its foot it would be painted over the
## people walking on it.
##
## Where the ring is paint on concrete, this is a woven thing lying ON the
## floor - so it is drawn as a field DARKER than the boards, with a border and
## a medallion in the room's own accent. A rug the colour of the floor is a
## stain; a rug two shades under it with a gold border is a rug.

const Brush := preload("../_brush.gd")

## The long axis runs across the room, which is how a gallery is carpeted -
## 216 px centres on the room's own middle and still leaves the walls their
## furniture.
const SIZE := Vector2i(216, 96)
const BLOCKS := Vector2.ZERO
const PIN := Vector2i(0, 0)

## How much of the floor under it still comes through, and it is nearly
## nothing. The first draft let 28% of the boards through and the tile grid
## read straight across the rug, which turned a woven thing into a rectangle
## painted on the floor - the one read a rug must not have. What the pile
## borrows from the room is the room's light, not its joints.
const PILE_ALPHA := 0.94


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var art := SIZE
	var accent: Color = Color(spec["accent"])
	# The field, with the fringe's width left bare at each short end.
	var field := Brush.shade(spec, 0.27)
	field.a = PILE_ALPHA
	for y in art.y:
		for x in range(3, art.x - 3):
			Brush.pixel(img, Vector2i(x, y), field)
	# The border: two courses of the accent with a darker line inside them,
	# which is how any woven border is built and what stops the field from
	# reading as a shadow on the floor.
	for inset in [1, 2, 6]:
		var c := accent.darkened(0.15) if inset < 3 else accent.darkened(0.55)
		for x in range(3 + inset, art.x - 3 - inset):
			Brush.pixel(img, Vector2i(x, inset), c)
			Brush.pixel(img, Vector2i(x, art.y - 1 - inset), c)
		for y in range(inset, art.y - inset):
			Brush.pixel(img, Vector2i(3 + inset, y), c)
			Brush.pixel(img, Vector2i(art.x - 4 - inset, y), c)
	# The medallion: a diamond in the middle, filled a shade up from the field
	# and edged in the accent, because the middle of a rug is where the pattern
	# is and a plain middle reads as felt. Its rows narrow twice as fast
	# vertically as horizontally, which is the same squash the room's own
	# perspective puts on everything lying flat.
	var mid := Vector2i(art.x / 2, art.y / 2)
	var inner := Brush.shade(spec, 0.36)
	inner.a = PILE_ALPHA
	for step in 33:
		var half: int = 34 - step
		var dy: int = int(round(float(step) * 0.55))
		for side in [-1, 1]:
			var y: int = mid.y + dy * side
			for x in range(mid.x - half, mid.x + half):
				Brush.pixel(img, Vector2i(x, y), inner)
			for edge: int in [mid.x - half, mid.x + half - 1]:
				Brush.pixel(img, Vector2i(edge, y), accent.darkened(0.25))
	# The rosette at its centre: a small solid diamond, the knot every medallion
	# is built out from.
	for step in range(-4, 5):
		var half: int = 4 - absi(step)
		for x in range(mid.x - half, mid.x + half + 1):
			Brush.pixel(img, Vector2i(x, mid.y + step), accent.darkened(0.10))
	# The field motifs: the medallion's diamond again, small and OUTLINED
	# rather than filled, repeated round it. Filled they read as things dropped
	# on the rug; outlined they read as what is woven into it.
	for at: Vector2i in [Vector2i(30, 22), Vector2i(art.x - 30, 22),
			Vector2i(30, art.y - 22), Vector2i(art.x - 30, art.y - 22),
			Vector2i(art.x / 2, 14), Vector2i(art.x / 2, art.y - 14)]:
		for step in range(-8, 9):
			var half: int = 8 - absi(step)
			for x: int in [at.x - half, at.x + half]:
				Brush.pixel(img, Vector2i(x, at.y + step / 2),
					accent.darkened(0.35))
	# Fringe, at the two short ends only - which is where a rug's warp comes
	# out, and the detail that says woven rather than painted.
	for y in range(6, art.y - 6, 3):
		for x in 3:
			var thread := Brush.shade(spec, 0.80)
			thread.a = 0.7
			Brush.pixel(img, Vector2i(x, y), thread)
			Brush.pixel(img, Vector2i(art.x - 1 - x, y), thread)
	return img
