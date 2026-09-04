extends RefCounted
## A call-centre station: the desk phone is the whole point of it. Same
## footprint as the plain desk, but where that one has a mug and a monitor
## nobody is looking at, this has a handset on its cradle, a coiled cord, a
## queue on the screen and a headset left hooked over the bezel.
##
## Drawn as ONE picture rather than a desk with a phone placed on top of it:
## a prop's position is its foot, so a phone standing on a desk would be two
## instances with hand-tuned y offsets, and every row of them would be one
## nudge away from a phone hovering off the front edge.

const Brush := preload("../_brush.gd")

const SIZE := Vector2i(40, 25)
const BLOCKS := Vector2(38, 7)


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var w: int = SIZE.x
	var glow: Color = Color(spec["accent"])
	# The headset, hooked over the top of the monitor at the end of a shift.
	# Two ear cups and a band, in the outline shade so it reads as the dark
	# thing on a pale bezel.
	var strap: Color = Brush.shade(spec, Brush.OUTLINE)
	for x in range(6, 15):
		Brush.pixel(img, Vector2i(x, 0), strap)
	for cup in [4, 15]:
		for y in range(1, 4):
			Brush.pixel(img, Vector2i(cup, y), strap)
			Brush.pixel(img, Vector2i(cup + 1, y), Brush.shade(spec, 0.30))
	# Monitor: the queue is on it, which is the joke - the screen on this floor
	# always has more calls on it than anybody is going to take.
	var bezel := Rect2i(3, 2, 16, 10)
	Brush.fill(img, spec, bezel, 0.16)
	Brush.outline(img, spec, bezel)
	for y in range(4, 10):
		for x in range(5, 17):
			Brush.pixel(img, Vector2i(x, y), Brush.SCREEN)
	# Four rows in the queue, each a different length, and the top one is red:
	# somebody has been holding long enough for the wallboard to notice.
	for i in 4:
		var length: int = [9, 6, 8, 4][i]
		for x in range(6, 6 + length):
			Brush.pixel(img, Vector2i(x, 5 + i), glow.darkened(0.15 + 0.12 * i))
	Brush.pixel(img, Vector2i(16, 5), Brush.LED_BAD)
	for y in range(11, 13):
		Brush.row(img, spec, y, 9, 13, 0.30)
	Brush.slab(img, spec, Rect2i(0, 12, w, 6), 0.82)
	Brush.panel(img, spec, Rect2i(2, 17, w - 4, 8), 0.40)
	var drawer := Rect2i(5, 18, 15, 5)
	Brush.outline(img, spec, drawer)
	for x in range(9, 16):
		Brush.pixel(img, Vector2i(x, 20), glow)
	_phone(img, spec)
	return img


## The desk phone, drawn last so its base sits ON the desktop's back edge - the
## same trick the plain desk's mug uses. A cradle, a handset lying across it, a
## keypad, the line-in-use light and a cord curled off the right-hand end.
static func _phone(img: Image, spec: Dictionary) -> void:
	var body := Rect2i(23, 8, 14, 6)
	Brush.panel(img, spec, body, 0.24)
	# Keypad: three rows of pale keys, which is what makes it a phone and not a
	# box at this size.
	for row in 2:
		for key in 3:
			Brush.pixel(img, Vector2i(25 + key * 3, 10 + row * 2),
				Brush.shade(spec, 0.86))
	Brush.pixel(img, Vector2i(34, 10), Brush.LED_BAD)
	Brush.pixel(img, Vector2i(34, 12), Brush.LED_OK)
	# The handset, resting across the cradle: bright ends, shaded middle.
	var handset := Rect2i(22, 4, 15, 4)
	Brush.fill(img, spec, handset, 0.36)
	for end in [23, 35]:
		for y in range(5, 7):
			Brush.pixel(img, Vector2i(end, y), Brush.shade(spec, 0.72))
	Brush.outline(img, spec, handset)
	# The cord, coiled and going nowhere near where it should.
	var cord: Color = Brush.shade(spec, 0.10)
	for step in [Vector2i(37, 7), Vector2i(38, 8), Vector2i(37, 9),
			Vector2i(38, 10), Vector2i(37, 11)]:
		Brush.pixel(img, step, cord)
