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
const Props := preload("res://tools/props.gd")

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

## The office floors' hazard throws sparks instead of burning, and they are
## fixed for the same reason the flame is - see _polisher(). Placed by hand off
## the pad rim and from under it, because a scatter that reads as a shorting
## motor is not something a formula gets right at this size.
const SPARK_CORE := Color("fff8e0")
const SPARK_BODY := Color("ffd45e")
const SPARK_EDGE := Color("ff8a3c")
const SPARKS := [
	Vector2i(1, 17), Vector2i(3, 14), Vector2i(14, 17), Vector2i(12, 13),
	Vector2i(4, 21), Vector2i(12, 21), Vector2i(0, 20), Vector2i(15, 20),
]
## A shorting motor arcs as well as sprays. Two jagged bolts off the housing,
## as pixel runs rather than a formula: at 16 px wide the difference between a
## bolt and a smear is which four pixels you pick.
const ARCS := [
	[Vector2i(3, 15), Vector2i(2, 14), Vector2i(3, 13), Vector2i(1, 11)],
	[Vector2i(12, 15), Vector2i(13, 14), Vector2i(12, 12), Vector2i(14, 11)],
]

## The power strip's own short: the arc jumps BETWEEN two sockets and throws up,
## which is a different picture from a pad grinding the floor, so it gets its
## own placements rather than reusing the polisher's.
const STRIP_ARCS := [
	[Vector2i(5, 17), Vector2i(6, 15), Vector2i(7, 13), Vector2i(6, 11)],
	[Vector2i(8, 17), Vector2i(9, 15), Vector2i(10, 14)],
]
const STRIP_SPARKS := [
	Vector2i(4, 13), Vector2i(9, 11), Vector2i(12, 15), Vector2i(2, 16),
	Vector2i(7, 9), Vector2i(13, 19), Vector2i(3, 20),
]

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

	# The furniture this biome dresses its rooms with, painted in its own ramp.
	# Which props exist is derived from where the biome puts them, so the one
	# list in biomes.gd drives the art here and the placement in build_levels.gd
	# - a floor cannot end up with a desk it never asked for or a desk it placed
	# and has no art for.
	for type in Biomes.prop_types(level):
		if not Props.known(type):
			printerr("  '%s' places prop '%s', which nothing in props.gd draws"
				% [level, type])
			bad = true
			continue
		bad = _save(_texture(Props.paint(type, spec)),
			"%s/%s_art.tres" % [dir, type]) or bad

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
				var c := _ramp(ramp, shade, 1.0)
				# `runner` turns the central band from more polished stone into
				# carpet. A biome that asks for one gets the accent mixed in and
				# the shine taken off, because a runner has to read as a
				# different MATERIAL - the marble hall's runner is a slightly
				# different marble and disappears, which is fine in a room full
				# of columns and dreadful in a room with a floor to spare.
				if key == "floor_alt" and spec.has("runner"):
					c = _ramp(ramp, shade * 0.74, 1.0) \
						.lerp(Color(spec["accent"]), spec["runner"])
				img.set_pixel(to.x * TILE + x, to.y * TILE + y, c)

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


## Architecture is per-biome style, chosen by the `column` key. There is exactly
## one reason for the split: the fluted classical column is most of what makes
## the marble hall read as a hall, and it is also most of what made the office
## lobby read as a temple. The office floors get a glazed pillar instead.
func _column(spec: Dictionary) -> Image:
	match spec.get("column", "classical"):
		"pillar":
			return _pillar(spec)
		"divider":
			return _divider(spec)
		_:
			return _classical_column(spec)


## A 16x48 cubicle divider: fabric panel in a metal frame, on feet. DESIGN.md's
## "dividers as columns" for the open-plan floors - the same slot in the level
## that holds a pillar downstairs, because what a room uses to break up its
## floor is exactly what changes between a lobby and a bullpen.
##
## Shorter in the frame than the pillar and the column deliberately: a divider
## is something you see over, and drawing it floor-to-ceiling would wall the
## room off visually in a room that has to stay readable during a four-on-one
## fight.
func _divider(spec: Dictionary) -> Image:
	var height := 48
	var img := Image.create(TILE, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ramp: Array = spec["ramp"]
	var gamma: float = spec["gamma"]
	var accent := Color(spec["accent"])
	# The panel starts a third of the way down, so the divider reads as waist
	# height with the room carrying on above it.
	for y in range(14, 44):
		for x in range(1, 15):
			var t := 0.40
			if x == 1 or x == 14:
				t = 0.08                           # frame upright
			elif x == 2:
				t = 0.66                           # lit edge
			elif x >= 12:
				t = 0.24
			# The weave: a two-pixel check, which is what makes it read as
			# fabric next to all the flat painted metal on this floor.
			elif (x + y) % 2 == 0:
				t = 0.46
			if y == 14 or y == 15:
				t = 0.72                           # capping rail
			elif y == 43:
				t = 0.10
			var c := _ramp(ramp, t, gamma)
			if y > 16 and y < 43 and x > 2 and x < 12:
				c = c.lerp(accent, 0.10)           # the fabric takes a dye
			img.set_pixel(x, y, c)
	# Feet, splayed either side so it looks free-standing rather than sunk in.
	for x in range(0, 5):
		img.set_pixel(x, 44, _ramp(ramp, 0.50, gamma))
		img.set_pixel(x, 45, _ramp(ramp, 0.12, gamma))
	for x in range(11, 16):
		img.set_pixel(x, 44, _ramp(ramp, 0.34, gamma))
		img.set_pixel(x, 45, _ramp(ramp, 0.10, gamma))
	return img


## A 16x48 glass-and-steel pillar: steel stiles either side of a glazed face,
## faintly tinted with the biome's accent the way a curtain wall is, capped top
## and bottom. Straight-sided, because a corporate lobby has no entasis.
func _pillar(spec: Dictionary) -> Image:
	var height := 48
	var img := Image.create(TILE, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ramp: Array = spec["ramp"]
	var gamma: float = spec["gamma"]
	var accent := Color(spec["accent"])
	for y in range(3, 45):
		for x in range(1, 15):
			var t := 0.34                          # glazing
			if x == 1 or x == 14:
				t = 0.06                           # silhouette outline
			elif x == 2:
				t = 1.00                           # lit steel stile, light left
			elif x == 3:
				t = 0.78
			elif x == 13:
				t = 0.18                           # shaded stile
			elif x == 12:
				t = 0.30
			elif x == 5:
				t = 0.62                           # sheen down the glass
			var mullion := (y - 3) % 14 == 0 or y == 44
			if mullion:
				t = minf(t, 0.16)
			var c := _ramp(ramp, t, gamma)
			if x >= 4 and x <= 11 and not mullion:
				c = c.lerp(accent, 0.20)
			img.set_pixel(x, y, c)
	# Cap and base plate, both a tile wide so the pillar reads as fixed to the
	# floor and the ceiling rather than floating in the room.
	for x in TILE:
		img.set_pixel(x, 0, _ramp(ramp, 0.30, gamma))
		img.set_pixel(x, 1, _ramp(ramp, 0.98, gamma))
		img.set_pixel(x, 2, _ramp(ramp, 0.72, gamma))
		img.set_pixel(x, 45, _ramp(ramp, 0.90, gamma))
		img.set_pixel(x, 46, _ramp(ramp, 0.52, gamma))
		img.set_pixel(x, 47, _ramp(ramp, 0.08, gamma))
	return img


## A 16x48 column: abacus, flared echinus, fluted shaft, flared plinth.
## Drawn rather than sampled - the source sheet has no pillar of any kind.
func _classical_column(spec: Dictionary) -> Image:
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


## The hazard slot, per-biome style like the column. Both styles are 16x24 with
## the same foot, so the hazard scene and the collision box the level places are
## untouched by the choice - only what the danger looks like changes. What must
## not change is that it reads as harmful at a glance, which is why the sparks
## are as generous as the flame is.
func _torch(spec: Dictionary) -> Image:
	match spec.get("hazard", "torch"):
		"polisher":
			return _polisher(spec)
		"power_strip":
			return _power_strip(spec)
		_:
			return _standing_torch(spec)


## DESIGN.md's hazard for the bullpen: an overloaded power strip on the floor,
## arcing, with far too much plugged into it. Lower and flatter than the other
## two hazards - it is something you tread ON rather than walk INTO - so the
## sparks do most of the work of being visible, and there are more of them than
## the polisher has for exactly that reason.
func _power_strip(spec: Dictionary) -> Image:
	var img := Image.create(16, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ramp: Array = spec["ramp"]
	var gamma: float = spec["gamma"]

	# The strip itself, lying on the floor at the bottom of the canvas.
	for y in range(16, 22):
		for x in range(1, 15):
			var t := 0.46
			if y == 16:
				t = 0.70                           # top face, catching light
			elif y == 21:
				t = Props.OUTLINE
			elif x <= 2:
				t = 0.62
			elif x >= 12:
				t = 0.26
			img.set_pixel(x, y, _ramp(ramp, t, gamma))
	# Sockets: four of them, all occupied.
	for i in 4:
		var x := 2 + i * 3
		img.set_pixel(x, 18, _ramp(ramp, Props.OUTLINE, gamma))
		img.set_pixel(x + 1, 18, _ramp(ramp, Props.OUTLINE, gamma))
		img.set_pixel(x, 19, _ramp(ramp, 0.86, gamma))
	# A daisy-chained second strip, because one was not enough for anybody.
	for x in range(4, 14):
		img.set_pixel(x, 14, _ramp(ramp, 0.34, gamma))
		img.set_pixel(x, 15, _ramp(ramp, 0.14, gamma))
	# The cables, going off in three directions and none of them tidy.
	for step in 8:
		img.set_pixel(mini(15, 14 + step / 4), 22 - step / 2,
			_ramp(ramp, 0.08, gamma))
		img.set_pixel(maxi(0, 1 - step / 6), mini(23, 17 + step / 3),
			_ramp(ramp, 0.08, gamma))
		img.set_pixel(3 + step / 3, mini(23, 22 + step / 7),
			_ramp(ramp, 0.10, gamma))

	# The short. Arcs between the sockets rather than off a spinning pad, and
	# the fixed spark colours are the same ones the polisher uses: whatever the
	# floor's palette, a hazard has to read as one.
	for arc in STRIP_ARCS:
		for at in arc:
			_spark(img, at, SPARK_BODY)
	for at in STRIP_SPARKS:
		for step in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			_spark(img, at + step, SPARK_BODY if at.y < 18 else SPARK_EDGE)
		_spark(img, at, SPARK_CORE)
	return img


## A floor polisher someone left running with a shorted motor: DESIGN.md's
## reskin of the torch for the office floors. Handle bar, post, motor housing
## and a buffing pad, throwing sparks off the rim it is grinding into.
func _polisher(spec: Dictionary) -> Image:
	var img := Image.create(16, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ramp: Array = spec["ramp"]
	var gamma: float = spec["gamma"]

	# T-grip and the post down to the motor, lit from the left like everything.
	for x in range(4, 12):
		img.set_pixel(x, 2, _ramp(ramp, 0.16, gamma))
		img.set_pixel(x, 3, _ramp(ramp, 0.88 if x <= 7 else 0.55, gamma))
	for y in range(4, 14):
		img.set_pixel(7, y, _ramp(ramp, 0.70, gamma))
		img.set_pixel(8, y, _ramp(ramp, 0.30, gamma))
	# Motor housing.
	for y in range(13, 18):
		for x in range(3, 13):
			var t := 0.52
			if x <= 4:
				t = 0.80
			elif x >= 11:
				t = 0.24
			if y == 13 or y == 17:
				t = 0.14
			img.set_pixel(x, y, _ramp(ramp, t, gamma))
	# Buffing pad, widest where it meets the floor.
	var pad := {18: [2, 14], 19: [1, 15], 20: [1, 15], 21: [2, 14], 22: [4, 12]}
	for y in pad:
		var span: Array = pad[y]
		for x in range(span[0], span[1]):
			var t := 0.66 if y <= 19 else 0.34
			if x <= span[0] + 1:
				t += 0.20
			elif x >= span[1] - 2:
				t -= 0.16
			if y == 22:
				t = 0.08                        # the shadow it sits in
			img.set_pixel(x, y, _ramp(ramp, t, gamma))

	# The sparks, and they are as generous as the flame is on purpose: this is a
	# hazard, and a hazard the player reads as scenery is a hazard that feels
	# like the game cheating. Crosses rather than dots so a 16 px prop still
	# says "live" at 1x, in fixed colours for the same reason the flame is - a
	# hazard that took the room's palette would camouflage itself in it.
	for arc in ARCS:
		for at in arc:
			_spark(img, at, SPARK_BODY)
	for at in SPARKS:
		for step in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			_spark(img, at + step, SPARK_BODY if at.y < 20 else SPARK_EDGE)
		_spark(img, at, SPARK_CORE)
	return img


func _spark(img: Image, at: Vector2i, c: Color) -> void:
	if at.x >= 0 and at.y >= 0 and at.x < img.get_width() and at.y < img.get_height():
		img.set_pixel(at.x, at.y, c)


## A 16x24 standing torch: biome-stone stem and plinth with fire on top.
## Drawn, like the column - the source sheet has no torch to sample.
func _standing_torch(spec: Dictionary) -> Image:
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
	return Biomes.ramp(ramp, t, gamma)


func _texture(img: Image) -> PortableCompressedTexture2D:
	var tex := PortableCompressedTexture2D.new()
	tex.keep_compressed_buffer = true
	tex.create_from_image(img, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
	return tex


func _save(res: Resource, path: String) -> bool:
	var err := ResourceSaver.save(res, path)
	print("  ", path, " -> ", error_string(err))
	return err != OK
