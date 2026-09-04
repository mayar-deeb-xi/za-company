extends RefCounted
## Shared sprite-sheet work for the two generators that need it:
## build_characters.gd (the playable cast) and build_enemies.gd (the bestiary).
## Editor-side only - nothing under res://game or res://tests loads this.
##
## Two jobs, and they are deliberately separate:
##
## - restyle() takes the pristine CC0 sheet and a recipe and returns a recoloured,
##   reshaped copy. Used to SEED a new sheet, once.
## - slice() takes any sheet laid out on the 32px grid and cuts it into
##   SpriteFrames. Used every build, on whatever sheet is actually on disk.
##
## That split is what lets an enemy own its sheet: it is seeded from a recipe
## and sliced forever after, so hand-drawn frames are never overwritten by a
## rebuild.

const FRAME := 32
const COLS := 4

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
## Combo sparks (attack2 rows). Doubles as the default spark colour: a bald
## recipe has no hair to tint them from, so they stay this gold.
const SRC_SPARK := "ffd04d"

# Only these colours count as "the body" when picking a seam for a build tweak:
# attack frames also contain the slash arc, whose bounds would drag the seam off
# the character.
const BODY_COLOURS := [
	SRC_HAIR, SRC_SKIN, SRC_EYE, SRC_SHIRT, SRC_SHIRT_DARK, SRC_PANTS, SRC_PANTS_DARK,
]

# Curl shaping happens in two passes: the whole hair mass grows a pixel outward,
# then the crown is serrated every other column. One pass alone fails: serrating
# a thin cap gives two horns, growing without serrating gives a helmet.
const SERRATE_PERIOD := 2
const SIDE_LIMIT := 0.6
const HIGHLIGHT_PERIOD := 3

## Animation layout of the PRISTINE CC0 sheet: row indices, verified against it.
## The sheet only draws a right-facing profile; "side" is flipped for left.
##
## **Frozen, like the seed body it describes.** This is what a freshly seeded
## enemy sheet contains, and nothing else. It is deliberately NOT "the layout
## everything uses": the cast keeps its own in build_characters.gd, so a new
## player animation adds a row there without reaching over here. Were the two
## shared, adding row 9 for the player would tell every enemy to slice a row its
## own 9-row sheet does not have, and the frames would come back empty with
## nothing to say why.
##
## An enemy sheet that grows rows of its own declares a `layout` in its roster
## entry, which is the whole point of each enemy owning its sheet.
const CC0_LAYOUT := {
	"down": {"idle": 0, "walk": 1, "attack": 6},
	"up": {"idle": 2, "walk": 3, "attack": 7},
	"side": {"idle": 4, "walk": 5, "attack": 8},
}
const CC0_SPECS := {
	"idle": {"frames": 1, "fps": 1.0, "loop": true},
	"walk": {"frames": 4, "fps": 10.0, "loop": true},
	"attack": {"frames": 4, "fps": 14.0, "loop": false},
}

const N4 := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


static func _c(hex: String) -> Color:
	return Color(hex)


static func _inside(img: Image, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height()


static func _is(img: Image, x: int, y: int, hex: String) -> bool:
	if not _inside(img, x, y):
		return false
	var p := img.get_pixel(x, y)
	return p.a > 0.0 and p.to_html(false) == hex


static func _clear(img: Image, x: int, y: int) -> bool:
	return _inside(img, x, y) and img.get_pixel(x, y).a == 0.0


static func _pixels_of(img: Image, ox: int, oy: int, hex: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in FRAME:
		for x in FRAME:
			if _is(img, ox + x, oy + y, hex):
				out.append(Vector2i(ox + x, oy + y))
	return out


static func _bbox(pixels: Array[Vector2i]) -> Rect2i:
	if pixels.is_empty():
		return Rect2i()
	var box := Rect2i(pixels[0], Vector2i.ONE)
	for p in pixels:
		box = box.expand(p).expand(p + Vector2i.ONE)
	return box


# --- hair shaping --------------------------------------------------------------


static func _grow(img: Image, at: Vector2i, step: Vector2i) -> void:
	var edge := at + step
	if not _is(img, edge.x, edge.y, SRC_OUTLINE):
		return
	var beyond := edge + step
	if not (_clear(img, beyond.x, beyond.y) or _is(img, beyond.x, beyond.y, SRC_OUTLINE)):
		return
	img.set_pixelv(edge, _c(SRC_HAIR))


static func _reoutline(img: Image, ox: int, oy: int) -> void:
	for p in _pixels_of(img, ox, oy, SRC_HAIR):
		for n in N4:
			var q: Vector2i = p + n
			if _clear(img, q.x, q.y):
				img.set_pixelv(q, _c(SRC_OUTLINE))


static func _expand(img: Image, ox: int, oy: int, serrate: bool) -> void:
	var hair := _pixels_of(img, ox, oy, SRC_HAIR)
	if hair.is_empty():
		return
	var box := _bbox(hair)
	var side_cutoff := box.position.y + int(box.size.y * SIDE_LIMIT)

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


static func _texture_curls(img: Image, ox: int, oy: int, hair_hex: String,
		light_hex: String) -> void:
	var hair := _pixels_of(img, ox, oy, hair_hex)
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
			img.set_pixelv(p, _c(light_hex))


# --- beard --------------------------------------------------------------------


## Paints the chin and jaw in the hair colour. The face is found through the
## eyes, so back-of-head frames (which have none) stay clean; the search window
## around them keeps a raised attack arm from being mistaken for a jaw.
static func _add_beard(img: Image, ox: int, oy: int) -> void:
	var eyes := _pixels_of(img, ox, oy, SRC_EYE)
	if eyes.is_empty():
		return
	var eye_box := _bbox(eyes)
	var window := Rect2i(
		eye_box.position + Vector2i(-5, 0),
		eye_box.size + Vector2i(10, 9))

	var face: Array[Vector2i] = []
	var max_y := -1
	for y in range(window.position.y, window.end.y):
		for x in range(window.position.x, window.end.x):
			if _is(img, x, y, SRC_SKIN):
				face.append(Vector2i(x, y))
				max_y = maxi(max_y, y)
	for p in face:
		if p.y >= max_y - 1 and p.y > eye_box.end.y:
			img.set_pixelv(p, _c(SRC_HAIR))


## Spark colour for a recipe: the hair colour raised to flash intensity, so a
## near-black head still throws sparks that read on a dark floor; SRC_SPARK's
## gold where there is no hair to take it from. Nudged off an exact match with
## the hair so the curl-highlight pass can never mistake sparks for hair rim.
static func _spark_hex(recipe: Dictionary) -> String:
	if recipe["hair_style"] == "bald":
		return SRC_SPARK
	var c := _c(recipe["hair"])
	c.v = maxf(c.v, 0.9)
	if c.to_html(false) == recipe["hair"]:
		c = c.lightened(0.15)
	return c.to_html(false)


# --- build tweaks: one duplicated or removed pixel column / row ---------------


static func _body_bounds(img: Image, ox: int, oy: int) -> Rect2i:
	var pixels: Array[Vector2i] = []
	for hex in BODY_COLOURS:
		pixels.append_array(_pixels_of(img, ox, oy, hex))
	return _bbox(pixels)


## The seam column for widening/narrowing: the body's centre, nudged off any
## column that holds an eye pixel so an eye is never doubled or deleted.
static func _seam_x(img: Image, ox: int, oy: int) -> int:
	var body := _body_bounds(img, ox, oy)
	if body.size == Vector2i.ZERO:
		return -1
	var seam := body.position.x + body.size.x / 2
	var eye_columns := {}
	for p in _pixels_of(img, ox, oy, SRC_EYE):
		eye_columns[p.x] = true
	while eye_columns.has(seam):
		seam -= 1
	return seam


static func _widen(img: Image, ox: int, oy: int) -> void:
	for y in FRAME:
		if img.get_pixel(ox + FRAME - 1, oy + y).a > 0.0:
			return  # no room to shift right
	var seam := _seam_x(img, ox, oy)
	if seam < 0:
		return
	for y in FRAME:
		var ay := oy + y
		for x in range(ox + FRAME - 1, seam, -1):
			img.set_pixel(x, ay, img.get_pixel(x - 1, ay))


static func _narrow(img: Image, ox: int, oy: int) -> void:
	var seam := _seam_x(img, ox, oy)
	if seam < 0:
		return
	for y in FRAME:
		var ay := oy + y
		for x in range(seam, ox + FRAME - 1):
			img.set_pixel(x, ay, img.get_pixel(x + 1, ay))
		img.set_pixel(ox + FRAME - 1, ay, Color(0, 0, 0, 0))


## Grows the character up by one row, feet anchored: everything above the seam
## shifts up, the seam row is duplicated. The seam sits mid-shirt so the torso
## stretches rather than the head.
static func _heighten(img: Image, ox: int, oy: int) -> void:
	for x in FRAME:
		if img.get_pixel(ox + x, oy).a > 0.0:
			return  # no headroom
	var shirt := _pixels_of(img, ox, oy, SRC_SHIRT)
	var box := _bbox(shirt) if not shirt.is_empty() else _body_bounds(img, ox, oy)
	if box.size == Vector2i.ZERO:
		return
	var seam := box.position.y + box.size.y / 2
	for x in FRAME:
		var ax := ox + x
		for y in range(oy, seam):
			img.set_pixel(ax, y, img.get_pixel(ax, y + 1))


# --- the two public jobs ------------------------------------------------------


## A recoloured, reshaped copy of `src_path` per `recipe`. Row count comes from
## the image rather than a constant, so a taller sheet restyles just as happily.
static func restyle(src_path: String, recipe: Dictionary) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(src_path))
	if img == null:
		return null
	img.convert(Image.FORMAT_RGBA8)
	var rows := img.get_height() / FRAME

	# 1. Silhouette work per frame, while everything is still source colours.
	for row in rows:
		for col in COLS:
			var ox := col * FRAME
			var oy := row * FRAME
			match recipe["hair_style"]:
				"curly":
					_expand(img, ox, oy, false)
					_expand(img, ox, oy, true)
				"short_curly":
					_expand(img, ox, oy, true)
			if recipe["beard"]:
				_add_beard(img, ox, oy)
			match recipe["build"]:
				"wide":
					_widen(img, ox, oy)
				"skinny":
					_narrow(img, ox, oy)
				"tall":
					_heighten(img, ox, oy)

	# 2. Recolour. A bald head is simply hair recoloured to skin - the outline
	# already holds the skull's silhouette.
	var bald: bool = recipe["hair_style"] == "bald"
	var map := {
		SRC_OUTLINE: SRC_OUTLINE,
		SRC_HAIR: recipe["skin"] if bald else recipe["hair"],
		SRC_SKIN: recipe["skin"],
		SRC_EYE: recipe["eye"],
		SRC_SHIRT: recipe["shirt"],
		SRC_SHIRT_DARK: recipe["shirt_dark"],
		SRC_PANTS: recipe["pants"],
		SRC_PANTS_DARK: recipe["pants_dark"],
		SRC_SLASH: SRC_SLASH,
		SRC_SPARK: _spark_hex(recipe),
	}
	var unknown := {}
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			if p.a == 0.0:
				continue
			var hex := p.to_html(false)
			if map.has(hex):
				img.set_pixel(x, y, _c(map[hex]))
			else:
				unknown[hex] = unknown.get(hex, 0) + 1
	if not unknown.is_empty():
		printerr("unmapped source colours: ", unknown)

	# 3. Curl highlights, now in the new hair colour.
	if recipe["hair_style"] in ["curly", "short_curly"]:
		for row in rows:
			for col in COLS:
				_texture_curls(img, col * FRAME, row * FRAME,
					recipe["hair"], recipe["hair_light"])

	return img


## Cuts a sheet into SpriteFrames. The sheet is embedded in the resource as a
## lossless PortableCompressedTexture2D rather than referenced as a PNG, so the
## result works headless immediately with no --import pass - and the source PNG
## stays a pure art file that the game never loads.
static func slice(img: Image, layout: Dictionary, specs: Dictionary) -> SpriteFrames:
	var tex := PortableCompressedTexture2D.new()
	tex.keep_compressed_buffer = true
	tex.create_from_image(img, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)

	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for dir_name in layout:
		for state in layout[dir_name]:
			var anim := "%s_%s" % [state, dir_name]
			var spec: Dictionary = specs[state]
			sf.add_animation(anim)
			sf.set_animation_speed(anim, spec["fps"])
			sf.set_animation_loop(anim, spec["loop"])
			for col in spec["frames"]:
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2(col * FRAME, layout[dir_name][state] * FRAME,
					FRAME, FRAME)
				sf.add_frame(anim, at)
	return sf
