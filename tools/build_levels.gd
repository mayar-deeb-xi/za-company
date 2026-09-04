extends SceneTree
## Lays out each level scene, plus the door and column scenes that level owns.
## Run: godot --headless --path . --script res://tools/build_levels.gd
## Requires tools/build_biomes.gd to have produced the art first.
##
## Every level gets its own door.tscn and column.tscn in its own folder, free to
## diverge in art, collision and structure. Only door_base.gd is shared, because
## game.gd has to talk to every door the same way.
##
## Unlike the other generators, what this writes is a STARTING POINT: once a
## level is dressed by hand in the editor, re-running this overwrites that work.
## Run it to reset a level or to add a new one to CHAIN.

const Biomes := preload("res://tools/biomes.gd")

const LEVEL_SCRIPT := "res://game/levels/level.gd"
const DOOR_SCRIPT := "res://game/levels/door_base.gd"
const HAZARD_SCRIPT := "res://game/levels/hazard_base.gd"
const PICKUP_SCRIPT := "res://game/levels/pickup_base.gd"

const TILE := 16
const COLS := 34                 # 544 px
const ROWS := 19                 # 304 px - about a quarter less area than 40x22

## Atlas coordinates, mirroring the layout in tools/build_biomes.gd.
const FLOOR := Vector2i(0, 0)
const FLOOR_ALT := Vector2i(1, 0)
const FLOOR_WORN := Vector2i(3, 0)
const WALL := Vector2i(0, 1)
const WALL_LIT := Vector2i(2, 1)
const WALL_DARK := Vector2i(3, 1)

## Doors sit in a 2-tile gap cut through the wall ring: north to the next level,
## south back to the previous one. DOOR_COL is chosen so the gap straddles the
## map's centre line.
const DOOR_COL := 16
const DOOR_CENTRE_X := DOOR_COL * TILE + TILE

## The colonnade flanks a central runner. Offset so no pillar lands on the
## centre line - the straight walk between the two doors has to stay clear.
const COLUMN_ROWS := [5, 13]
const COLUMN_XS := [4, 9, 14, 19, 24, 29]
const RUNNER_TOP := 8
const RUNNER_BOTTOM := 10

## Far enough from a threshold that arriving here does not re-trigger the door
## you just came out of.
const SPAWN_START_Y := 240       # by the south door: you came from the previous level
const SPAWN_RETURN_Y := 80       # by the north door: you came back from the next one

## The starting-point dressing for health: one torch to hurt on and one heart
## to heal on, either side of the room, both clear of the door line and the
## colonnade so the straight walk between the doors stays safe.
const TORCH_POS := Vector2(120, 152)
const HEALTH_POS := Vector2(424, 152)

## Enemies are the one prop a level does NOT own a copy of: types are shared
## from game/enemies/<type>/, and which ones a room gets is per-biome data in
## tools/biomes.gd. A level that wants a variant swaps the instance by hand.
const ENEMY_SCENE := "res://game/enemies/%s/%s.tscn"


## Names passed after `--` build only those levels. Since a re-run overwrites
## hand-dressing, adding one floor to a chain of eight must not mean re-rolling
## the seven that are already dressed:
##   godot --headless --path . --script res://tools/build_levels.gd -- lobby
func _initialize() -> void:
	var only := OS.get_cmdline_user_args()
	var failed := false
	for level in Biomes.CHAIN:
		if not only.is_empty() and not only.has(level):
			continue
		print(level, ":")
		failed = _build(level) or failed
	for name in only:
		if not Biomes.CHAIN.has(name):
			printerr("unknown level '%s' - not in Biomes.CHAIN" % name)
			failed = true
	quit(1 if failed else 0)


func _build(level: String) -> bool:
	var dir: String = Biomes.dir(level)
	var tileset := load("%s/tileset.tres" % dir) as TileSet
	if tileset == null:
		printerr("  missing %s/tileset.tres - run tools/build_biomes.gd first" % dir)
		return true

	var bad := false
	bad = _write_column_scene(dir) or bad
	bad = _write_door_scene(dir) or bad
	bad = _write_torch_scene(dir) or bad
	bad = _write_health_scene(dir) or bad
	bad = _write_level_scene(level, dir, tileset) or bad
	return bad


## The level's own pillar, art baked in. No script: a column has no behaviour to
## share, and a level that wants one adds it here without affecting any other.
func _write_column_scene(dir: String) -> bool:
	var root := StaticBody2D.new()
	root.name = "Column"

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.centered = false
	# Origin at the foot of the column: that is what Y-sorting reads to decide
	# whether the player draws in front of it or behind it.
	sprite.position = Vector2(-8, -48)
	sprite.texture = load("%s/column_art.tres" % dir) as Texture2D
	root.add_child(sprite)
	sprite.owner = root

	var body := CollisionShape2D.new()
	body.name = "CollisionShape2D"
	body.position = Vector2(0, -3)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(11, 6)
	body.shape = shape
	root.add_child(body)
	body.owner = root

	return _pack(root, "%s/column.tscn" % dir)


## The level's own door. Origin sits at the centre of the gap in the wall ring,
## so a south door is the same scene rotated half a turn.
func _write_door_scene(dir: String) -> bool:
	var root := Area2D.new()
	root.name = "Door"
	root.monitorable = false
	root.set_script(load(DOOR_SCRIPT))
	root.add_to_group("door", true)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.centered = false
	sprite.position = Vector2(-16, -8)
	root.add_child(sprite)
	sprite.owner = root

	# Closes the gap the doorway was cut into. The map stays sealed whether or
	# not the transition fires, and a locked door keeps this body while its art
	# goes dark.
	var seal := StaticBody2D.new()
	seal.name = "Seal"
	root.add_child(seal)
	seal.owner = root
	var seal_shape := CollisionShape2D.new()
	seal_shape.name = "CollisionShape2D"
	var seal_rect := RectangleShape2D.new()
	seal_rect.size = Vector2(TILE * 2, TILE)
	seal_shape.shape = seal_rect
	seal.add_child(seal_shape)
	seal_shape.owner = root

	# The threshold you actually walk onto, on the floor just inside the arch.
	# Snug against the seal: further out and the player can scrape past the
	# trigger along the wall. This was tuned by hand in the dressed doors and the
	# generator used to write 38, so regenerating a door silently undid it.
	var trigger := CollisionShape2D.new()
	trigger.name = "CollisionShape2D"
	trigger.position = Vector2(0, 13)
	var trigger_rect := RectangleShape2D.new()
	trigger_rect.size = Vector2(26, 10)
	trigger.shape = trigger_rect
	root.add_child(trigger)
	trigger.owner = root

	return _pack(root, "%s/door.tscn" % dir)


## The level's own standing torch: walking into the fire hurts. Behaviour is
## the shared hazard_base.gd; the art, shape and anything extra are this
## level's to change.
func _write_torch_scene(dir: String) -> bool:
	var root := Area2D.new()
	root.name = "Torch"
	root.monitorable = false
	root.set_script(load(HAZARD_SCRIPT))

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.centered = false
	# Foot origin, like the column: what Y-sorting reads.
	sprite.position = Vector2(-8, -24)
	sprite.texture = load("%s/torch_art.tres" % dir) as Texture2D
	root.add_child(sprite)
	sprite.owner = root

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	shape.position = Vector2(0, -3)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 6)
	shape.shape = rect
	root.add_child(shape)
	shape.owner = root

	return _pack(root, "%s/torch.tscn" % dir)


## The level's own heal pickup, on the shared pickup_base.gd.
func _write_health_scene(dir: String) -> bool:
	var root := Area2D.new()
	root.name = "Health"
	root.monitorable = false
	root.set_script(load(PICKUP_SCRIPT))

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.centered = false
	sprite.position = Vector2(-4, -8)
	sprite.texture = load("%s/health_art.tres" % dir) as Texture2D
	root.add_child(sprite)
	sprite.owner = root

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	shape.position = Vector2(0, -4)
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	root.add_child(shape)
	shape.owner = root

	return _pack(root, "%s/health_item.tscn" % dir)


func _write_level_scene(level: String, dir: String, tileset: TileSet) -> bool:
	var root := Node2D.new()
	root.name = Biomes.BIOMES[level]["node"]
	root.y_sort_enabled = true
	root.set_script(load(LEVEL_SCRIPT))
	root.set("display_name", Biomes.BIOMES[level].get("title", ""))

	var floor_layer := _layer("Floor", tileset, root)
	var walls := _layer("Walls", tileset, root)
	walls.y_sort_enabled = true
	_paint(floor_layer, walls)

	var props := Node2D.new()
	props.name = "Props"
	props.y_sort_enabled = true
	root.add_child(props)
	props.owner = root

	var column_scene := _reload("%s/column.tscn" % dir)
	for row in COLUMN_ROWS:
		for col in COLUMN_XS:
			var column := column_scene.instantiate()
			column.name = "Column_%d_%d" % [col, row]
			column.position = Vector2(col * TILE + TILE / 2, (row + 1) * TILE)
			props.add_child(column)
			column.owner = root

	var torch := _reload("%s/torch.tscn" % dir).instantiate()
	torch.name = "Torch"
	torch.position = TORCH_POS
	props.add_child(torch)
	torch.owner = root

	var health := _reload("%s/health_item.tscn" % dir).instantiate()
	health.name = "Health"
	health.position = HEALTH_POS
	props.add_child(health)
	health.owner = root

	var roster: Array = Biomes.BIOMES[level].get("enemies", [])
	for i in roster.size():
		var spec: Dictionary = roster[i]
		var type: String = spec["type"]
		var enemy := _reload(ENEMY_SCENE % [type, type]).instantiate()
		enemy.name = "Enemy%d" % (i + 1)
		enemy.position = spec["at"]
		props.add_child(enemy)
		enemy.owner = root

	var door_scene := _reload("%s/door.tscn" % dir)
	var next: String = Biomes.next_of(level)
	if next != "":
		_add_door(props, root, door_scene, dir, "Exit", "out", 0, 0.0,
			next, &"start")
	var previous: String = Biomes.previous_of(level)
	if previous != "":
		# Half a turn puts the same scene's art, seal and threshold in the
		# south wall, facing back into the room.
		_add_door(props, root, door_scene, dir, "Return", "back", ROWS - 1, PI,
			previous, &"returned")
	_cut_doorways(walls, next != "", previous != "")

	var spawns := Node2D.new()
	spawns.name = "Spawns"
	root.add_child(spawns)
	spawns.owner = root
	_marker(spawns, root, "start", Vector2(DOOR_CENTRE_X, SPAWN_START_Y))
	_marker(spawns, root, "returned", Vector2(DOOR_CENTRE_X, SPAWN_RETURN_Y))

	return _pack(root, "%s/%s.tscn" % [dir, level])


func _add_door(props: Node2D, root: Node2D, scene: PackedScene, dir: String,
		node_name: String, art: String, wall_row: int, turn: float,
		target: String, spawn: StringName) -> void:
	var door := scene.instantiate()
	door.name = node_name
	door.position = Vector2(DOOR_CENTRE_X, wall_row * TILE + TILE / 2)
	door.rotation = turn
	door.art = load("%s/doorway_%s.tres" % [dir, art]) as Texture2D
	door.target_level = "%s/%s.tscn" % [Biomes.dir(target), target]
	door.target_spawn = spawn
	props.add_child(door)
	door.owner = root


## One tile of wall all the way round, with the floor pattern inside it.
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


## Removes the wall tiles a doorway stands in, so the arch reads as a way
## through the border rather than something parked in front of it. The door
## scene's own Seal body keeps the hole closed.
func _cut_doorways(walls: TileMapLayer, north: bool, south: bool) -> void:
	for pair in [[north, 0], [south, ROWS - 1]]:
		if not pair[0]:
			continue
		for col in [DOOR_COL, DOOR_COL + 1]:
			walls.erase_cell(Vector2i(col, pair[1]))


func _floor_tile(col: int, row: int) -> Vector2i:
	# A darker course hugging the wall reads as the shadow the wall casts.
	if col == 1 or row == 1 or col == COLS - 2 or row == ROWS - 2:
		return FLOOR_WORN
	if row >= RUNNER_TOP and row <= RUNNER_BOTTOM:
		return FLOOR_ALT
	return FLOOR


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


## Reads a scene back off disk so the instance carries a scene_file_path -
## without one, pack() would inline its nodes instead of recording a reference.
func _reload(path: String) -> PackedScene:
	return ResourceLoader.load(path, "PackedScene",
		ResourceLoader.CACHE_MODE_REPLACE) as PackedScene


func _pack(root: Node, path: String) -> bool:
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, path)
	print("  ", path, " -> ", error_string(err))
	# This tree was never in the SceneTree, so nothing else will ever free it.
	root.free()
	return err != OK
