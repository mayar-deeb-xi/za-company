extends RefCounted
## FIXTURE, not a catalogue prop - see column.gd.
## The HEART mask coloured: lighter lobes, darker point, one pink glint.

const Brush := preload("../_brush.gd")

## Row-major mask, X = filled - the same convention as _brush.gd's font.
const HEART := [
	".XX...XX.",
	"XXXX.XXXX",
	"XXXXXXXXX",
	"XXXXXXXXX",
	".XXXXXXX.",
	"..XXXXX..",
	"...XXX...",
	"....X....",
]


static func paint() -> Image:
	var w: int = HEART[0].length()
	var img := Image.create(w, HEART.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in HEART.size():
		for x in w:
			if HEART[y][x] != "X":
				continue
			var c := Color("c8283c")
			if y <= 1:
				c = Color("e0465a")
			elif y >= 5:
				c = Color("8c1626")
			img.set_pixel(x, y, c)
	img.set_pixel(2, 1, Color("f2a0aa"))
	return img


