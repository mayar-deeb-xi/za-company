extends RefCounted
## A workstation: monitor, desktop, drawer front, and a cup nobody has washed.

const Brush := preload("_brush.gd")

const SIZE := Vector2i(40, 21)
const BLOCKS := Vector2(38, 7)


static func paint(spec: Dictionary) -> Image:
	var img := Brush.blank(SIZE)
	var w: int = SIZE.x
	# Monitor: bezel, screen, and two accent rows so it reads as switched on.
	var bezel := Rect2i(12, 0, 16, 8)
	Brush.fill(img, spec, bezel, 0.16)
	Brush.outline(img, spec, bezel)
	for y in range(2, 7):
		for x in range(14, 26):
			img.set_pixel(x, y, Brush.SCREEN)
	var glow: Color = Color(spec["accent"])
	for x in range(15, 24):
		img.set_pixel(x, 3, glow.darkened(0.25))
	for x in range(15, 21):
		img.set_pixel(x, 5, glow.darkened(0.55))
	for y in range(8, 10):
		Brush.row(img, spec, y, 19, 22, 0.30)
	Brush.slab(img, spec, Rect2i(0, 9, w, 6), 0.82)
	Brush.panel(img, spec, Rect2i(2, 14, w - 4, 7), 0.40)
	# Drawer front with an accent handle.
	var drawer := Rect2i(5, 15, 15, 5)
	Brush.outline(img, spec, drawer)
	for x in range(9, 16):
		img.set_pixel(x, 17, glow)
	# The cup, sitting on the desktop.
	for y in range(6, 10):
		for x in range(32, 36):
			img.set_pixel(x, y, Brush.shade(spec, 0.96 if x < 34 else 0.70))
	Brush.pixel(img, Vector2i(32, 6), Brush.shade(spec, Brush.OUTLINE))
	Brush.pixel(img, Vector2i(35, 6), Brush.shade(spec, Brush.OUTLINE))
	return img
