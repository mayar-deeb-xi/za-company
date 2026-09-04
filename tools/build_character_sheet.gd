extends SceneTree
## Regenerates res://game/player/character.png from the pristine CC0 sheet in
## src/, restyling the character: black curly hair, fair skin, grey shirt,
## blue jeans. Idempotent - always reads src/, never its own output.
##
## Run: godot --headless --path . --script res://tools/build_character_sheet.gd

const SRC := "res://game/player/src/character_cc0.png"
const OUT := "res://game/player/character.png"
const FRAME := 32
const COLS := 4
const ROWS := 9

# Palette of the source sheet, verified pixel by pixel against character_cc0.png.
const SRC_OUTLINE := "0d0b0d"
const SRC_HAIR := "65432f"
const SRC_SKIN := "c8b89f"
const SRC_EYE := "281721"
const SRC_SHIRT := "6eb39d"
const SRC_SHIRT_DARK := "284e43"
const SRC_PANTS := "674949"
const SRC_PANTS_DARK := "50282f"
const SRC_SLASH := "fff8e1"

# The restyle. Hair keeps two tones so the curls have something to catch light
# with; a single near-black would collapse into the outline.
const NEW := {
	SRC_OUTLINE: "0d0b0d",      # unchanged - the outline holds the silhouette
	SRC_HAIR: "221d29",         # black hair, base
	SRC_SKIN: "f0d5c4",         # fair skin
	SRC_EYE: "2b2130",          # eyes, kept dark against the pale skin
	SRC_SHIRT: "a9a9b4",        # grey shirt
	SRC_SHIRT_DARK: "6a6a76",   # grey shirt, shadow
	SRC_PANTS: "4a6a9c",        # denim
	SRC_PANTS_DARK: "31486e",   # denim, shadow
	SRC_SLASH: "fff8e1",        # unchanged - the attack arc, not part of the body
}
const HAIR_LIGHT := "4d4560"

# Curl shaping happens in two passes. First the whole hair mass grows a pixel
# outward - curly hair is bulkier than the straight cap the source sheet draws -
# then the crown is serrated every other column. One pass alone fails: serrating
# a thin cap gives two horns, growing without serrating gives a helmet.
const SERRATE_PERIOD := 2
# Neither pass runs below this fraction of the hair mass, so the volume sits up
# on the crown instead of hanging down past the ears like long hair.
const SIDE_LIMIT := 0.6
# Rim highlights, staggered every third pixel.
const HIGHLIGHT_PERIOD := 3

const N4 := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


func _c(hex: String) -> Color:
	return Color(hex)


func _inside(img: Image, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height()


func _is(img: Image, x: int, y: int, hex: String) -> bool:
	if not _inside(img, x, y):
		return false
	var p := img.get_pixel(x, y)
	return p.a > 0.0 and p.to_html(false) == hex


func _clear(img: Image, x: int, y: int) -> bool:
	return _inside(img, x, y) and img.get_pixel(x, y).a == 0.0


## Pixels of `hex` inside one frame, in absolute image coordinates.
func _pixels_of(img: Image, ox: int, oy: int, hex: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in FRAME:
		for x in FRAME:
			if _is(img, ox + x, oy + y, hex):
				out.append(Vector2i(ox + x, oy + y))
	return out


func _bbox(pixels: Array[Vector2i]) -> Rect2i:
	if pixels.is_empty():
		return Rect2i()
	var box := Rect2i(pixels[0], Vector2i.ONE)
	for p in pixels:
		box = box.expand(p).expand(p + Vector2i.ONE)
	return box


## Pushes one hair pixel a step further out. Only fires where the neighbour is
## the outline and the pixel beyond is empty or outline, so the hair can never
## eat into the face, the shirt or the slash arc.
func _grow(img: Image, at: Vector2i, step: Vector2i) -> void:
	var edge := at + step
	if not _is(img, edge.x, edge.y, SRC_OUTLINE):
		return
	var beyond := edge + step
	if not (_clear(img, beyond.x, beyond.y) or _is(img, beyond.x, beyond.y, SRC_OUTLINE)):
		return
	img.set_pixelv(edge, _c(SRC_HAIR))


## Growing in two directions can strand a hair pixel with bare canvas beside it.
## Re-drawing the outline around the whole hair mass closes the silhouette again.
func _reoutline(img: Image, ox: int, oy: int) -> void:
	for p in _pixels_of(img, ox, oy, SRC_HAIR):
		for n in N4:
			var q: Vector2i = p + n
			if _clear(img, q.x, q.y):
				img.set_pixelv(q, _c(SRC_OUTLINE))


## One outward pass over the hair mass. `serrate` restricts the crown to every
## other column; without it every column grows, which just adds volume.
func _expand(img: Image, ox: int, oy: int, serrate: bool) -> void:
	var hair := _pixels_of(img, ox, oy, SRC_HAIR)
	if hair.is_empty():
		return
	var box := _bbox(hair)
	var side_cutoff := box.position.y + int(box.size.y * SIDE_LIMIT)

	# Topmost, leftmost and rightmost hair pixel per column / per row.
	var top := {}
	var left := {}
	var right := {}
	for p in hair:
		if not top.has(p.x) or p.y < top[p.x]:
			top[p.x] = p.y
		if not left.has(p.y) or p.x < left[p.y]:
			left[p.y] = p.x
		if not right.has(p.y) or p.x > right[p.y]:
			right[p.y] = p.x

	for x in top:
		if not serrate or posmod(x - box.position.x, SERRATE_PERIOD) == 1:
			_grow(img, Vector2i(x, top[x]), Vector2i.UP)
	if not serrate:
		for y in left:
			if y <= side_cutoff:
				_grow(img, Vector2i(left[y], y), Vector2i.LEFT)
		for y in right:
			if y <= side_cutoff:
				_grow(img, Vector2i(right[y], y), Vector2i.RIGHT)

	_reoutline(img, ox, oy)


## Volume, then a serrated crown - applied per frame so the pattern stays
## anchored to the head no matter where the head sits inside the frame.
func _shape_curls(img: Image, ox: int, oy: int) -> void:
	_expand(img, ox, oy, false)
	_expand(img, ox, oy, true)


## Highlights sit only on the outer rim of the hair mass, staggered row by row:
## that is where light catches a curl, and it leaves the interior solid black
## instead of an all-over checkerboard.
func _texture_curls(img: Image, ox: int, oy: int) -> void:
	var hair := _pixels_of(img, ox, oy, NEW[SRC_HAIR])
	if hair.is_empty():
		return
	var box := _bbox(hair)
	var mass := {}
	for p in hair:
		mass[p] = true
	for p in hair:
		var rim := false
		for n in N4:
			if not mass.has(p + n):
				rim = true
				break
		if not rim:
			continue
		var lx := p.x - box.position.x
		var ly := p.y - box.position.y
		if posmod(lx + (2 if ly % 2 == 1 else 0), HIGHLIGHT_PERIOD) == 0:
			img.set_pixelv(p, _c(HAIR_LIGHT))


func _initialize() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC))
	if img == null:
		printerr("Could not load ", SRC)
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)

	# 1. Silhouette, while the hair is still its source colour.
	for row in ROWS:
		for col in COLS:
			_shape_curls(img, col * FRAME, row * FRAME)

	# 2. Recolour everything.
	var unknown := {}
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			if p.a == 0.0:
				continue
			var hex := p.to_html(false)
			if NEW.has(hex):
				img.set_pixel(x, y, _c(NEW[hex]))
			else:
				unknown[hex] = unknown.get(hex, 0) + 1
	if not unknown.is_empty():
		printerr("unmapped source colours: ", unknown)

	# 3. Curl highlights, now in the new hair colour.
	for row in ROWS:
		for col in COLS:
			_texture_curls(img, col * FRAME, row * FRAME)

	var err := img.save_png(ProjectSettings.globalize_path(OUT))
	print("saved ", OUT, " -> ", error_string(err))
	quit(0 if err == OK else 1)
