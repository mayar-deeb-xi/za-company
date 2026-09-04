extends SceneTree
## Regenerates each level's own art: tileset, column, torch, heal pickup, and
## one doorway texture per neighbouring level.
## Run: godot --headless --path . --script res://tools/build_biomes.gd
##
## Everything lands in the level's own folder - no level borrows another's art.
## Floors and walls are palette-swapped from the shared dungeon sheet, so they
## keep the pixel structure of the art the player sprite already matches.
## Columns and doorways have no counterpart in that sheet and are drawn here.
##
## Every texture is embedded in its .tres as a lossless
## PortableCompressedTexture2D instead of being written out as a PNG: a
## regenerated biome is then usable headless straight away, with no --import
## pass, which matters because the Godot editor is usually open.

const Biomes := preload("res://tools/biomes.gd")

const SRC := "res://assets/tiles/dungeon.png"
const TILE := 16

## Source tiles, chosen because they repeat against themselves without a visible
## seam - most of dungeon.png is pre-composed room motifs that do not.
const FLOOR := Vector2i(7, 7)
const FLOOR_ALT := Vector2i(2, 7)
const FLOOR_PLAIN := Vector2i(11, 11)
const WALL := Vector2i(7, 6)
const WALL_ALT := Vector2i(6, 0)

## Atlas layout shared by every biome, so the level generator can paint any of
## them with the same coordinates: row 0 walks, row 1 blocks.
const ATLAS := {
	"floor": Vector2i(0, 0),
	"floor_alt": Vector2i(1, 0),
	"floor_plain": Vector2i(2, 0),
	"floor_worn": Vector2i(3, 0),
	"wall": Vector2i(0, 1),
	"wall_alt": Vector2i(1, 1),
	"wall_lit": Vector2i(2, 1),
	"wall_dark": Vector2i(3, 1),
}
const ATLAS_COLS := 4
const ATLAS_ROWS := 2
const SOLID_ROW := 1

## A doorway fills the 2-tile gap cut in the wall ring, plus one row of floor.
const DOOR_W := 32
const DOOR_H := 32

## Flame colours shared by every biome's torch: fire has to read as fire
## everywhere, while the stand under it is the biome's own stone.
const FLAME_EDGE := Color("b8300d")
const FLAME_BODY := Color("f0761a")
const FLAME_CORE := Color("ffd45e")

## The heal pickup, identical in every biome on purpose: red means health
## everywhere. Row-major mask, X = filled.
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


func _initialize() -> void:
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(SRC))
	if sheet == null:
		printerr("could not read ", SRC)
		quit(1)
		return

	# Normalise against the luminance actually present in the tiles we copy,
	# so each ramp is used end to end instead of bunching in its middle.
	var lo := 1.0
	var hi := 0.0
	for coord in [FLOOR, FLOOR_ALT, FLOOR_PLAIN, WALL, WALL_ALT]:
		for y in TILE:
			for x in TILE:
				var l := sheet.get_pixel(coord.x * TILE + x, coord.y * TILE + y) \
					.get_luminance()
				lo = minf(lo, l)
				hi = maxf(hi, l)
	print("source luminance range %.3f .. %.3f" % [lo, hi])

	var failed := false
	for level in Biomes.CHAIN:
		print(level, ":")
		failed = _build(level, sheet, lo, hi) or failed
	quit(1 if failed else 0)


func _build(level: String, sheet: Image, lo: float, hi: float) -> bool:
	var spec: Dictionary = Biomes.BIOMES[level]
	var dir: String = Biomes.dir(level)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))

	var bad := false
	bad = _save(_tileset(_build_atlas(sheet, spec, lo, hi)),
		"%s/tileset.tres" % dir) or bad
	bad = _save(_texture(_column(spec)), "%s/column_art.tres" % dir) or bad
	bad = _save(_texture(_torch(spec)), "%s/torch_art.tres" % dir) or bad
	bad = _save(_texture(_heart()), "%s/health_art.tres" % dir) or bad

	# One doorway per neighbour: this level's own stonework framing a passage
	# lit by the colour of the place on the other side of it.
	for pair in [["out", Biomes.next_of(level)], ["back", Biomes.previous_of(level)]]:
		if pair[1] == "":
			continue
		var beyond := Color(Biomes.BIOMES[pair[1]]["accent"])
		bad = _save(_texture(_doorway(spec, beyond)),
			"%s/doorway_%s.tres" % [dir, pair[0]]) or bad
	return bad


## Copies the chosen source tiles into the shared atlas layout, recolouring as
## it goes, then derives the two lit/dark wall variants from the base wall.
func _build_atlas(sheet: Image, spec: Dictionary, lo: float, hi: float) -> Image:
	var img := Image.create(ATLAS_COLS * TILE, ATLAS_ROWS * TILE, false,
		Image.FORMAT_RGBA8)
	var ramp: Array = spec["ramp"]
	var gamma: float = spec["gamma"]
	var band: Vector2 = spec["floor_band"]
	var copies := {
		"floor": FLOOR, "floor_alt": FLOOR_ALT,
		"floor_plain": FLOOR_PLAIN, "floor_worn": FLOOR_PLAIN,
		"wall": WALL, "wall_alt": WALL_ALT,
		"wall_lit": WALL, "wall_dark": WALL,
	}
	for key in copies:
		var from: Vector2i = copies[key]
		var to: Vector2i = ATLAS[key]
		for y in TILE:
			for x in TILE:
				var src_px := sheet.get_pixel(from.x * TILE + x, from.y * TILE + y)
				var t := clampf((src_px.get_luminance() - lo) / maxf(hi - lo, 0.001),
					0.0, 1.0)
				if key == "floor_worn":
					t *= 0.72
				elif key == "wall_dark":
					t *= 0.55
				var shade := pow(clampf(t, 0.0, 1.0), gamma)
				if key.begins_with("floor"):
					shade = band.x + shade * (band.y - band.x)
				img.set_pixel(to.x * TILE + x, to.y * TILE + y, _ramp(ramp, shade, 1.0))

	# wall_lit gets a bright top course: it caps the wall ring so the inner
	# face of the border catches light instead of reading as a flat band.
	var lit: Vector2i = ATLAS["wall_lit"]
	for x in TILE:
		img.set_pixel(lit.x * TILE + x, lit.y * TILE, _ramp(ramp, 0.95, gamma))
		img.set_pixel(lit.x * TILE + x, lit.y * TILE + 1, _ramp(ramp, 0.75, gamma))
		img.set_pixel(lit.x * TILE + x, lit.y * TILE + TILE - 1, _ramp(ramp, 0.08, gamma))
	return img


func _tileset(atlas: Image) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer(0)

	var source := TileSetAtlasSource.new()
	source.texture = _texture(atlas)
	source.texture_region_size = Vector2i(TILE, TILE)
	# Attach first: a tile's TileData only grows a physics slot once its source
	# belongs to a TileSet that has the layer.
	ts.add_source(source, 0)

	var half := TILE / 2.0
	var box := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half),
	])
	for key in ATLAS:
		var coord: Vector2i = ATLAS[key]
		source.create_tile(coord)
		if coord.y == SOLID_ROW:
			var data := source.get_tile_data(coord, 0)
			data.set_collision_polygons_count(0, 1)
			data.set_collision_polygon_points(0, 0, box)
	return ts


## A 16x48 column: abacus, flared echinus, fluted shaft, flared plinth.
## Drawn rather than sampled - the source sheet has no pillar of any kind.
func _column(spec: Dictionary) -> Image:
	var height := 48
	var img := Image.create(TILE, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ramp: Array = spec["ramp"]
	var gamma: float = spec["gamma"]
	for y in height:
		var hw := _column_half_width(y)
		var left := 8 - hw
		var w := hw * 2
		for dx in w:
			var t := 0.70
			if dx == 0 or dx == w - 1:
				t = 0.06                       # silhouette outline
			elif dx == 1:
				t = 1.00                       # lit edge, light comes from the left
			elif dx == 2:
				t = 0.88
			elif dx >= w - 3:
				t = 0.34                       # shaded edge
			elif dx % 3 == 0:
				t = 0.55                       # flute groove
			# Horizontal breaks that read as the joints of stacked stone.
			if y == 2 or y == 9 or y == 39 or y == height - 1:
				t = minf(t, 0.22)
			elif y == 0 or y == 10 or y == 40:
				t = maxf(t, 0.92)
			img.set_pixel(left + dx, y, _ramp(ramp, t, gamma))
	return img


## A 16x24 standing torch: biome-stone stem and plinth with fire on top.
## Drawn, like the column - the source sheet has no torch to sample.
func _torch(spec: Dictionary) -> Image:
	var img := Image.create(16, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ramp: Array = spec["ramp"]
	var gamma: float = spec["gamma"]

	# Stem, lit from the left like everything else in the biome.
	for y in range(10, 22):
		img.set_pixel(7, y, _ramp(ramp, 0.62, gamma))
		img.set_pixel(8, y, _ramp(ramp, 0.28, gamma))
	# Bowl the flame sits in.
	for x in range(5, 11):
		img.set_pixel(x, 9, _ramp(ramp, 0.20, gamma))
		img.set_pixel(x, 10, _ramp(ramp, 0.75 if x <= 7 else 0.40, gamma))
	# Plinth.
	for x in range(6, 10):
		img.set_pixel(x, 21, _ramp(ramp, 0.85, gamma))
	for x in range(5, 11):
		img.set_pixel(x, 22, _ramp(ramp, 0.50 if x <= 7 else 0.30, gamma))
		img.set_pixel(x, 23, _ramp(ramp, 0.10, gamma))

	# Teardrop flame, hottest low and centred, dark-edged all round so it holds
	# its shape against both a pale and a hot floor.
	var half_widths := [1, 2, 3, 3, 3, 3, 2]
	for i in half_widths.size():
		var y: int = 2 + i
		var hw: int = half_widths[i]
		for x in range(8 - hw, 8 + hw):
			var c := FLAME_BODY
			if i == 0 or x == 8 - hw or x == 8 + hw - 1:
				c = FLAME_EDGE
			elif i >= 3 and x >= 7 and x <= 8:
				c = FLAME_CORE
			img.set_pixel(x, y, c)
	return img


## The HEART mask coloured: lighter lobes, darker point, one pink glint.
func _heart() -> Image:
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


func _column_half_width(y: int) -> int:
	if y <= 2:
		return 7
	elif y <= 4:
		return 6
	elif y <= 39:
		return 5
	elif y <= 43:
		return 6
	return 7


## A 32x32 doorway that drops into the 2-tile gap cut in the wall ring.
##
## The top half is the gap itself - this biome's stone cut into jambs either
## side of a passage lit by `beyond`, brightest deep in. The bottom half is the
## floor in front of it, carrying only the light that spills out, so the level's
## own floor tiles still show through.
##
## Directional on purpose: a south door is this same texture rotated half a
## turn, which puts the wall half back in the wall and the spill back on the
## floor. Mirroring it would not.
func _doorway(spec: Dictionary, beyond: Color) -> Image:
	var img := Image.create(DOOR_W, DOOR_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ramp: Array = spec["ramp"]
	var gamma: float = spec["gamma"]
	var jamb_w := 6
	var cx := (DOOR_W - 1) / 2.0
	for y in DOOR_H:
		for x in DOOR_W:
			var in_jamb := x < jamb_w or x >= DOOR_W - jamb_w
			if y < TILE:
				if in_jamb:
					img.set_pixel(x, y, _ramp(ramp, _jamb_shade(x, y, cx), gamma))
				elif x == jamb_w or x == DOOR_W - jamb_w - 1:
					img.set_pixel(x, y, _ramp(ramp, 0.04, gamma))      # inner lip
				else:
					# Brightest at the far end, dimming towards the threshold, so
					# the gap reads as depth rather than a painted rectangle.
					img.set_pixel(x, y,
						beyond.darkened(0.10 + float(y) / float(TILE) * 0.45))
			elif in_jamb and y < TILE + 4:
				# Feet of the jambs, sitting on the floor.
				img.set_pixel(x, y, _ramp(ramp, _jamb_shade(x, y, cx) * 0.7, gamma))
			elif not in_jamb:
				# Light thrown onto the floor, fading out over one tile.
				var fade := 1.0 - float(y - TILE) / float(TILE)
				var across := 1.0 - clampf(absf(float(x) - cx) / 10.0, 0.0, 1.0)
				var spill := beyond
				spill.a = fade * fade * across * 0.55
				img.set_pixel(x, y, spill)
	return img


## Jamb stonework: lit from the left like everything else, coursed, and darker
## than the wall around it so the gap reads as cut into the ring.
func _jamb_shade(x: int, y: int, cx: float) -> float:
	if x <= 1 or x >= DOOR_W - 2:
		return 0.10                                                # outer edge
	if y % 5 == 0:
		return 0.15                                                # mortar course
	return 0.58 if float(x) < cx else 0.30


func _ramp(ramp: Array, t: float, gamma: float) -> Color:
	var scaled := pow(clampf(t, 0.0, 1.0), gamma) * float(ramp.size() - 1)
	var i := int(floor(scaled))
	if i >= ramp.size() - 1:
		return Color(ramp[ramp.size() - 1])
	return Color(ramp[i]).lerp(Color(ramp[i + 1]), scaled - float(i))


func _texture(img: Image) -> PortableCompressedTexture2D:
	var tex := PortableCompressedTexture2D.new()
	tex.keep_compressed_buffer = true
	tex.create_from_image(img, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
	return tex


func _save(res: Resource, path: String) -> bool:
	var err := ResourceSaver.save(res, path)
	print("  ", path, " -> ", error_string(err))
	return err != OK
