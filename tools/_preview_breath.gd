extends SceneTree
## TEMPORARY preview generator - writes idle-frame PNGs so the breathing idea
## can be judged before any of it lands in the real generators. Delete after.

const Art := preload("res://tools/character_art.gd")
const Roster := preload("res://game/player/characters/roster.gd")
const SRC := "res://game/player/src/character_cc0.png"
const FRAME := 32
const OUT := "C:/Users/chrol/AppData/Local/Temp/claude/c--Users-chrol-OneDrive-Desktop-Game-dev-za-company/626bc28c-0032-43fd-be11-cb1cf860a8a9/scratchpad/"
const IDLE_ROWS := {"down": 0, "up": 2, "side": 4}


static func _opaque_bbox(img: Image, ox: int, oy: int) -> Rect2i:
	var minx := 99; var miny := 99; var maxx := -1; var maxy := -1
	for y in FRAME:
		for x in FRAME:
			if img.get_pixel(ox + x, oy + y).a > 0.0:
				minx = mini(minx, x); miny = mini(miny, y)
				maxx = maxi(maxx, x); maxy = maxi(maxy, y)
	if maxy < 0:
		return Rect2i()
	return Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1)


## The proposal: everything above a waist seam drops one row, feet planted.
static func _compress(img: Image, ox: int, oy: int, ratio: float) -> void:
	var box := _opaque_bbox(img, ox, oy)
	if box.size.y <= 4:
		return
	var seam := oy + box.position.y + int(box.size.y * ratio)
	for x in FRAME:
		var ax := ox + x
		for y in range(seam, oy, -1):
			img.set_pixel(ax, y, img.get_pixel(ax, y - 1))
		img.set_pixel(ax, oy, Color(0, 0, 0, 0))


## The alternative: the whole sprite drops one row, feet included.
static func _bob(img: Image, ox: int, oy: int) -> void:
	for x in FRAME:
		var ax := ox + x
		for y in range(oy + FRAME - 1, oy, -1):
			img.set_pixel(ax, y, img.get_pixel(ax, y - 1))
		img.set_pixel(ax, oy, Color(0, 0, 0, 0))


static func _cut(img: Image, ox: int, oy: int) -> Image:
	var out := Image.create(FRAME, FRAME, false, Image.FORMAT_RGBA8)
	out.blit_rect(img, Rect2i(ox, oy, FRAME, FRAME), Vector2i.ZERO)
	return out


func _initialize() -> void:
	for entry in Roster.CHARACTERS:
		var sheet := Art.restyle(SRC, entry["recipe"])
		if sheet == null:
			printerr("no sheet"); quit(1); return
		for dir_name in IDLE_ROWS:
			var oy: int = IDLE_ROWS[dir_name] * FRAME
			var stand := _cut(sheet, 0, oy)

			var a := _cut(sheet, 0, oy)
			_compress(a, 0, 0, 0.55)
			var b := _cut(sheet, 0, oy)
			_compress(b, 0, 0, 0.75)
			var c := _cut(sheet, 0, oy)
			_bob(c, 0, 0)

			var id: String = entry["id"]
			stand.save_png(OUT + "%s_%s_stand.png" % [id, dir_name])
			a.save_png(OUT + "%s_%s_waist.png" % [id, dir_name])
			b.save_png(OUT + "%s_%s_low.png" % [id, dir_name])
			c.save_png(OUT + "%s_%s_bob.png" % [id, dir_name])
		print("done ", entry["id"])
	quit(0)
