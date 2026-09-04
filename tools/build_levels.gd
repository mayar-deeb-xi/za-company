extends SceneTree
## Lays out the biome level scenes from one shared floor plan.
## Run: godot --headless --path . --script res://tools/build_levels.gd
## Requires tools/build_biomes.gd to have produced the tilesets first.
##
## Unlike the other generators, the scenes this writes are a STARTING POINT, not
## a resource to keep regenerating: once a level is dressed by hand in the
## editor, re-running this overwrites that work. Regenerate only to reset a
## level or to add a new one to CHAIN.

const TILE := 16
const COLS := 40                 # 640 px - the viewport width, as before
const ROWS := 22                 # 352 px - 360 rounded down to whole tiles

const COLUMN_SCENE := "res://game/props/column/column.tscn"
const DOOR_SCENE := "res://game/props/door/door.tscn"
const LEVEL_SCRIPT := "res://game/levels/level.gd"

## Atlas coordinates, mirroring the layout in tools/build_biomes.gd.
const FLOOR := Vector2i(0, 0)
const FLOOR_ALT := Vector2i(1, 0)
const FLOOR_WORN := Vector2i(3, 0)
const WALL := Vector2i(0, 1)
const WALL_LIT := Vector2i(2, 1)
const WALL_DARK := Vector2i(3, 1)

## Door targets follow this order and wrap, so extending the game is a matter of
## generating another biome and adding it here.
const CHAIN := ["marble_hall", "hellfire"]

const LEVELS := {
	"marble_hall": {
		"node": "MarbleHall",
		"tileset": "res://game/levels/marble_hall/marble_tileset.tres",
		"column": "res://game/levels/marble_hall/marble_column.tres",
		"dir": "res://game/levels/marble_hall",
	},
	"hellfire": {
		"node": "Hellfire",
		"tileset": "res://game/levels/hellfire/hellfire_tileset.tres",
		"column": "res://game/levels/hellfire/hellfire_column.tres",
		"dir": "res://game/levels/hellfire",
	},
}

## The colonnade: pillars flank a central runner. Spaced 6 tiles so that no
## column lands on DOOR_COL - the straight walk from the entrance to the arch
## has to stay clear, and at 5 tiles apart a pillar sits right in it.
const COLUMN_ROWS := [6, 15]
const COLUMN_XS := [5, 11, 17, 23, 29, 35]
const RUNNER_TOP := 9
const RUNNER_BOTTOM := 12
const DOOR_COL := 19             # 2 tiles wide, centred on a 40-tile map


func _initialize() -> void:
	var failed := false
	for i in CHAIN.size():
		var name: String = CHAIN[i]
		var next: String = CHAIN[(i + 1) % CHAIN.size()]
		failed = _build(name, next) or failed
	quit(1 if failed else 0)


func _build(name: String, next: String) -> bool:
	var spec: Dictionary = LEVELS[name]
	var tileset := load(spec["tileset"]) as TileSet
	if tileset == null:
		printerr("missing ", spec["tileset"], " - run tools/build_biomes.gd first")
		return true

	var root := Node2D.new()
	root.name = spec["node"]
	root.y_sort_enabled = true
	root.set_script(load(LEVEL_SCRIPT))

	var floor_layer := _layer("Floor", tileset, root)
	var walls := _layer("Walls", tileset, root)
	walls.y_sort_enabled = true
	_paint(floor_layer, walls)

	var props := Node2D.new()
	props.name = "Props"
	props.y_sort_enabled = true
	root.add_child(props)
	props.owner = root

	var column_art := load(spec["column"]) as Texture2D
	var column_scene := load(COLUMN_SCENE) as PackedScene
	for row in COLUMN_ROWS:
		for col in COLUMN_XS:
			var column := column_scene.instantiate()
			column.name = "Column_%d_%d" % [col, row]
			# Origin at the foot of the pillar: the bottom edge of its tile.
			column.position = Vector2(col * TILE + TILE / 2, (row + 1) * TILE)
			column.art = column_art
			props.add_child(column)
			column.owner = root

	var door := (load(DOOR_SCENE) as PackedScene).instantiate()
	door.name = "Exit"
	# The threshold sits on the floor in front of the arch, which is drawn over
	# the wall ring above it. The ring itself stays solid, so a player who does
	# not trigger the door still cannot walk out of the map.
	door.position = Vector2(DOOR_COL * TILE + TILE, 3 * TILE + TILE / 2)
	door.art = load("res://game/props/door/door_%s.tres" % _biome_of(next)) as Texture2D
	door.target_level = "%s/%s.tscn" % [LEVELS[next]["dir"], next]
	door.target_spawn = &"start"
	props.add_child(door)
	door.owner = root

	var spawns := Node2D.new()
	spawns.name = "Spawns"
	root.add_child(spawns)
	spawns.owner = root
	# Entrance at the far end of the hall, so the door is a walk away rather
	# than something you fall through on arrival.
	_marker(spawns, root, "start", Vector2(COLS * TILE / 2, (ROWS - 4) * TILE))

	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, "%s/%s.tscn" % [spec["dir"], name])
	print("  %s/%s.tscn -> %s" % [spec["dir"], name, error_string(err)])
	# pack() copied everything it needs; this tree was never in the SceneTree,
	# so nothing else will ever free it.
	root.free()
	return err != OK


## The door art is named for the biome it leads into, so an arch always glows
## with the colour of the place on the other side of it.
func _biome_of(level: String) -> String:
	return "marble" if level == "marble_hall" else "hellfire"


func _layer(name: String, tileset: TileSet, root: Node2D) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = name
	layer.tile_set = tileset
	root.add_child(layer)
	layer.owner = root
	return layer


func _marker(parent: Node2D, root: Node2D, name: String, at: Vector2) -> void:
	var marker := Marker2D.new()
	marker.name = name
	marker.position = at
	parent.add_child(marker)
	marker.owner = root


## One tile of wall all the way round - the same 16 px border the placeholder
## room had - with the floor pattern inside it.
func _paint(floor_layer: TileMapLayer, walls: TileMapLayer) -> void:
	for row in ROWS:
		for col in COLS:
			var at := Vector2i(col, row)
			var on_edge := col == 0 or row == 0 or col == COLS - 1 or row == ROWS - 1
			if on_edge:
				var corner := (col == 0 or col == COLS - 1) \
					and (row == 0 or row == ROWS - 1)
				var tile := WALL_DARK if corner else (WALL_LIT if row == 0 else WALL)
				walls.set_cell(at, 0, tile)
				continue
			floor_layer.set_cell(at, 0, _floor_tile(col, row))


func _floor_tile(col: int, row: int) -> Vector2i:
	# A darker course hugging the wall reads as the shadow the wall casts.
	if col == 1 or row == 1 or col == COLS - 2 or row == ROWS - 2:
		return FLOOR_WORN
	if row >= RUNNER_TOP and row <= RUNNER_BOTTOM:
		return FLOOR_ALT
	return FLOOR
