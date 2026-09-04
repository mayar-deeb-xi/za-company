extends RefCounted
## DESIGN.md's boxing ring, painted on the floor of the company gym - so the
## first prop in the catalogue that is not a THING but a marking, which is why
## it opens a shelf of its own. `markings/` is for paint: it is neither
## furniture, hardware nor a sign, and shelving it as any of those would make
## the catalogue lie about what it holds.
##
## Two things make a floor decal work here, and both are borrowed from the
## signs. It blocks nothing - you fight ON it. And it PINS its top-left corner
## rather than its foot, which is what puts it under everybody: Y-sorting reads
## a node's y, so pinning the top edge gives it the smallest y in the room and
## everything standing on it draws after it. Pinned at its foot it would paint
## over the fighters instead.

const Brush := preload("../_brush.gd")

## Big enough to fight in and no bigger: the room is 512 px of floor and this
## takes the middle of it, leaving the walls for the kit.
const SIZE := Vector2i(232, 148)
const BLOCKS := Vector2.ZERO
## The top-left corner, so the decal sorts before everything standing on it.
const PIN := Vector2i(0, 0)


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var art := SIZE
	var paint_c: Color = Color(spec["accent"])
	var faded := paint_c.darkened(0.35)
	var scuff := paint_c.darkened(0.62)
	# The canvas: a wash of the paint across the whole inside, faint enough
	# that the floor under it still reads as this room's floor. Without it the
	# ring is a rectangle drawn on the ground; with it the inside is a surface
	# you are standing ON, which is what the fight needs it to be.
	var canvas := paint_c
	canvas.a = 0.10
	for y in range(2, art.y - 2):
		for x in range(2, art.x - 2):
			Brush.pixel(img, Vector2i(x, y), canvas)
	# The outer square, two courses thick, and a second line inside it: ring
	# paint is a border rather than a line, and the gap between the two is what
	# reads as the ropes' footprint.
	for inset in [0, 1, 10, 11]:
		var c := paint_c if inset < 2 else faded
		for x in range(inset, art.x - inset):
			Brush.pixel(img, Vector2i(x, inset), c)
			Brush.pixel(img, Vector2i(x, art.y - 1 - inset), c)
		for y in range(inset, art.y - inset):
			Brush.pixel(img, Vector2i(inset, y), c)
			Brush.pixel(img, Vector2i(art.x - 1 - inset, y), c)
	# Corner posts, marked as filled squares - the four places the ropes would
	# be tied, and the four places DESIGN.md's corner rush ends up.
	for corner in [Vector2i(0, 0), Vector2i(art.x - 18, 0),
			Vector2i(0, art.y - 18), Vector2i(art.x - 18, art.y - 18)]:
		for y in 18:
			for x in 18:
				if x < 2 or y < 2 or x > 15 or y > 15:
					continue
				Brush.pixel(img, corner + Vector2i(x, y), scuff)
	# The centre mark, where a fight starts.
	var mid := Vector2i(art.x / 2, art.y / 2)
	for r in 9:
		var a := float(r) / 9.0 * TAU
		Brush.pixel(img, mid + Vector2i(int(round(cos(a) * 8.0)),
			int(round(sin(a) * 5.0))), faded)
	for x in range(mid.x - 3, mid.x + 4):
		Brush.pixel(img, Vector2i(x, mid.y), faded)
	# Worn patches: paint on a gym floor is scuffed where it gets used, and a
	# perfectly clean line reads as a decal rather than as paint.
	for at in [Vector2i(38, 1), Vector2i(96, 0), Vector2i(150, 1),
			Vector2i(1, 52), Vector2i(0, 96), Vector2i(art.x - 2, 40),
			Vector2i(art.x - 1, 104), Vector2i(64, art.y - 2),
			Vector2i(172, art.y - 1), Vector2i(120, art.y - 2)]:
		for step in 7:
			Brush.pixel(img, at + Vector2i(step if at.y < 4 or at.y > art.y - 4
				else 0, 0 if at.y < 4 or at.y > art.y - 4 else step), scuff)
	return img
