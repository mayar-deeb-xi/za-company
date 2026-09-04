extends SceneTree
## Regenerates the per-biome tilesets and props (columns, doors).
## Run: godot --headless --path . --script res://tools/build_biomes.gd
##
## Floors and walls are palette-swapped from the shared dungeon sheet, so they
## keep the pixel structure of the art the player sprite already matches.
## Columns and doors have no counterpart in that sheet and are drawn here.
##
## Every texture is embedded in its .tres as a lossless
## PortableCompressedTexture2D instead of being written out as a PNG: a
## regenerated biome is then usable headless straight away, with no --import
## pass, which matters because the Godot editor is usually open.

const SRC := "res://assets/tiles/dungeon.png"
const TILE := 16

## Source tiles, chosen because they repeat against themselves without a visible
## seam - most of dungeon.png is pre-composed room motifs that do not.
const FLOOR := Vector2i(7, 7)
const FLOOR_ALT := Vector2i(2, 7)
const FLOOR_PLAIN := Vector2i(11, 11)
const WALL := Vector2i(7, 6)
const WALL_ALT := Vector2i(6, 0)

## Atlas layout shared by every biome, so level scenes are theme-agnostic:
## row 0 walks, row 1 blocks.
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

## Value ramps. Index 0 is deepest shadow, the last entry is the brightest
## highlight; source pixels are mapped onto the ramp by luminance.
##
## `gamma` bends that mapping before the ramp is sampled. Above 1.0 it pushes
## mid-tones down while leaving the top of the ramp intact, so hellfire walls
## read as scorched brick with embers still glowing in the mortar.
##
## `floor_band` then confines floors to a slice of the ramp. Walls and props may
## use its full length, but a floor that reaches the hot end of the hellfire
## ramp turns into gold flooring, and the player sprite stops reading against
## it - so hell floors are pinned to the dark half whatever the source tile's
## own brightness was.
const BIOMES := {
	"marble": {
		"dir": "res://game/levels/marble_hall",
		"ramp": ["2f323c", "6e7382", "a9aebb", "d5d9e2", "f0f2f6", "ffffff"],
		"accent": "e8c56a",
		"gamma": 0.85,
		"floor_band": Vector2(0.30, 1.00),
	},
	"hellfire": {
		"dir": "res://game/levels/hellfire",
		"ramp": ["120309", "3a0b12", "71160f", "b8300d", "f0761a", "ffd45e"],
		"accent": "ffd45e",
		"gamma": 2.1,
		"floor_band": Vector2(0.02, 0.42),
	},
}


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
	for name in BIOMES:
		print(name, ":")
		failed = _build_biome(name, sheet, lo, hi) or failed
	quit(1 if failed else 0)


func _build_biome(name: String, sheet: Image, lo: float, hi: float) -> bool:
	var spec: Dictionary = BIOMES[name]
	var dir: String = spec["dir"]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))

	var atlas := _build_atlas(sheet, spec, lo, hi)
	var bad := false
	bad = _save(_tileset(atlas), "%s/%s_tileset.tres" % [dir, name]) or bad
	bad = _save(_texture(_column(spec)), "%s/%s_column.tres" % [dir, name]) or bad
	bad = _save(_texture(_door(spec)),
		"res://game/props/door/door_%s.tres" % name) or bad
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
				img.set_pixel(to.x * TILE + x, to.y * TILE + y,
					_ramp(ramp, shade, 1.0))

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


## A 32x48 arch. The opening is filled with the accent colour so a doorway
## reads as lit from the far side - the biome you are about to walk into.
func _door(spec: Dictionary) -> Image:
	var w := 32
	var h := 48
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ramp: Array = spec["ramp"]
	var gamma: float = spec["gamma"]
	var accent := Color(spec["accent"])
	var cx := 15.5
	for y in h:
		for x in w:
			if not _in_arch(x, y, cx, 13.0, 18):
				continue
			if _in_arch(x, y, cx, 9.0, 14):
				# Fade the glow from bright at the threshold to dark at the top.
				var g := clampf(float(y - 12) / float(h - 16), 0.0, 1.0)
				img.set_pixel(x, y, accent.darkened(1.0 - g * 0.85))
				continue
			var t := 0.62
			if absf(float(x) - cx) > 12.0 or y >= h - 2:
				t = 0.10
			elif float(x) < cx:
				t = 0.86 - 0.02 * float(y % 6)
			else:
				t = 0.40 - 0.02 * float(y % 6)
			if y % 6 == 0:
				t = minf(t, 0.24)              # mortar course
			img.set_pixel(x, y, _ramp(ramp, t, gamma))
	return img


## Rounded-top opening: a half-circle cap of `radius` sitting on straight jambs.
func _in_arch(x: int, y: int, cx: float, radius: float, top: int) -> bool:
	if y < top - int(radius):
		return false
	if y < top:
		return Vector2(float(x) - cx, float(y - top)).length() <= radius
	return absf(float(x) - cx) <= radius


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
