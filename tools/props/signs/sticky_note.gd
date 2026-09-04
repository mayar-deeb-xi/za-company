extends RefCounted
## DESIGN.md's face-down sticky note, on the desk in Khaled's office. It is
## shelved with the signs because it IS one - the only one in the game turned
## over, and the only thing written on a wall or a desk anywhere in this
## building that the player cannot read yet. What shows through the back of it
## is four grey smudges where the ink soaked through.
##
## Two things about it are load-bearing and neither is the drawing.
##
## It is a prop of its own rather than a detail painted into the desk, because
## the ending turns it over: it needs a node in the level scene for a script to
## find, and `StickyNote1` is that node.
##
## And its canvas is 30 px tall with the note in the top ten, which is how a
## thing lying ON a desk is placed at all. Y-sorting reads a node's y and every
## prop is drawn UPWARDS from its foot, so a note pinned where it lies would
## sort before the desk and be hidden behind it. Given a foot two pixels south
## of the desk's, it sorts after - and its art, twenty pixels up, lands on the
## desktop. The desk is drawn behind it and the note sits on the surface.

const Brush := preload("../_brush.gd")

const SIZE := Vector2i(14, 30)
const BLOCKS := Vector2.ZERO

## Sticky notes are yellow the way trophies are gold - it is what the object
## is, not what the room is. This one is face down, so it is the pale back of
## the pad rather than the front.
const BACK := Color("e8dfa8")
const BACK_LIT := Color("f6f0c8")
const CURL := Color("bdb078")
## The writing, coming through from the other side, and unreadable on purpose.
const BLEED := Color("a9a07a")


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	# The note: nine by nine, lit from the left like everything else.
	for y in range(1, 10):
		for x in range(2, 11):
			Brush.pixel(img, Vector2i(x, y), BACK_LIT if x < 4 else BACK)
	# The corner that has lifted off the surface, which is the one thing that
	# says face DOWN rather than blank.
	for step in 4:
		for x in range(10 - step, 11):
			Brush.pixel(img, Vector2i(x, 1 + step), CURL)
	# The ink through the back. Four marks, none of them a letter.
	for mark: Vector2i in [Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4),
			Vector2i(4, 6), Vector2i(5, 6), Vector2i(7, 6), Vector2i(4, 8),
			Vector2i(5, 8)]:
		Brush.pixel(img, mark, BLEED)
	# The shadow it casts on the desktop.
	for x in range(3, 12):
		Brush.pixel(img, Vector2i(x, 10), Brush.shade(spec, 0.10))
	for y in range(2, 11):
		Brush.pixel(img, Vector2i(11, y), Brush.shade(spec, 0.16))
	return img
