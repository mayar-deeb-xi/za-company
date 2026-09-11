extends RefCounted
## Paints Silverman's sheet from game/bosses/silverman/poses.gd.
##
## The simplest painter of the three, and it is simple for the reason the
## character is: his body never changes shape, so a frame is the same block of
## ASCII stamped at a different height and, where the pose asks for it, taken a
## step or two down the ramp. There is no arm to swing, no leg variant to
## anchor and no outline pass - the body carries its own "#" edge, which is
## what keeps him off the penthouse's city window.
##
## Run through tools/build_bosses.gd, and only when the PNG is missing: from
## then on the sheet is hand-owned art (see build_bosses.gd).
##
## Cells are 64 px. The body is centred in its cell horizontally so a flipped
## frame stays put, and row 34 sits on cell row 56 - which is what the scene's
## sprite offset of -24 puts on the boss's origin. His toes end on row 32, so
## the two rows under them are the hover and he never looks like he has landed.

const Poses := preload("res://game/bosses/silverman/poses.gd")

const CELL := 64
## Every row is six frames and none is padded: the hover, the glide, the two
## attacks, the concede and the cooling all spend exactly six, and the dash and
## the ghost spend one. That is not a coincidence to preserve - if a row ever
## wants a seventh, this is the number that grows.
const COLS := 6
## Body column 0, row 0 in cell pixels: (64 - 18) / 2 across, 56 - 34 down.
const BODY_AT := Vector2i(23, 22)


static func paint() -> Image:
	var rows := Poses.ORDER.size()
	var img := Image.create(COLS * CELL, rows * CELL, false, Image.FORMAT_RGBA8)
	for row in rows:
		var anim: String = Poses.ORDER[row]
		var frames: Array = Poses.ANIMS[anim]
		for col in frames.size():
			_blit(img, frames[col], Vector2i(col * CELL, row * CELL))
	return img


## One frame: the body, floated by `dy` and dulled by `dull`. Both default to
## nothing, which is the idle pose at rest.
static func _blit(img: Image, f: Dictionary, cell: Vector2i) -> void:
	var dy: int = f.get("dy", 0)
	var dull: int = f.get("dull", 0)
	for r in Poses.BODY.size():
		var line: String = Poses.BODY[r]
		for c in line.length():
			var key: String = line[c]
			if key == ".":
				continue
			var at := cell + BODY_AT + Vector2i(c, r + dy)
			if at.x < 0 or at.y < 0 or at.x >= img.get_width() or at.y >= img.get_height():
				continue
			img.set_pixelv(at, Color.html(Poses.PAL[Poses.dulled(key, dull)]))
