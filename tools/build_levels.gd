extends SceneTree
## Lays out each level scene and every scene that level owns.
## Run: godot --headless --path . --script res://tools/build_levels.gd
## Requires tools/build_biomes.gd to have produced the tileset first.
##
## A level's folder is split by what the files ARE, not by their type:
##
##   <biome>/                the room, and it never grows
##     <biome>.tscn          the level
##     tileset.tres          its floors and walls      <- build_biomes.gd
##     doorway_out/back.tres its passages              <- build_biomes.gd
##     door.tscn             how it connects
##     props/                everything STANDING in the room, one scene each,
##                           on the same shelves as tools/props/ - fixtures/
##                           (column, torch, health_item) plus whichever of
##                           furniture/, hardware/, signs/ the biome places
##
## Every level gets its own door and its own copy of each prop it uses, free to
## diverge in art, collision and structure. Only the _base.gd scripts are
## shared, because game.gd and the player have to talk to every door, hazard and
## pickup the same way.
##
## **Each prop scene carries its own picture, embedded.** The texture is painted
## here (by tools/props.gd) and handed to the Sprite2D unsaved, so it has no
## resource_path and PackedScene bakes it in as a sub-resource - exactly as the
## collision box already was. There used to be a matching <prop>_art.tres beside
## every prop scene, and each of those had precisely one consumer: its sibling.
## Sixteen of them buried the five files that say what a level actually is.
##
## The consequence to know: re-palettizing a prop now means running THIS script,
## not just build_biomes.gd. That is the trade, and it is a cheap one because
## everything here is written from data in tools/biomes.gd.
##
## Unlike the other generators, what this writes is a STARTING POINT: anything
## hand-tuned in the level scene afterwards - a nudged tile, a moved instance -
## is lost on the next run. Run it to reset a level or to add a new one to
## CHAIN, and prefer moving positions into biomes.gd over nudging them here.

const Biomes := preload("res://tools/biomes.gd")
const Props := preload("res://tools/props.gd")
const StableIds := preload("res://tools/stable_ids.gd")

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
## A biome overrides either list with a `columns` dictionary, because a room
## that is furnished needs the floor a full colonnade would take up.
const COLUMN_ROWS := [5, 13]
const COLUMN_XS := [4, 9, 14, 19, 24, 29]
const RUNNER_TOP := 8
const RUNNER_BOTTOM := 10

## Far enough from a threshold that arriving here does not re-trigger the door
## you just came out of.
const SPAWN_START_Y := 240       # by the south door: you came from the previous level
const SPAWN_RETURN_Y := 80       # by the north door: you came back from the next one

## The starting-point dressing for health: a heart to heal on, and - on the
## floors whose biome asks for one - a hazard to hurt on, either side of the
## room, both clear of the door line and the colonnade so the straight walk
## between the doors stays safe.
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
	var spec: Dictionary = Biomes.BIOMES[level]
	var dir: String = Biomes.dir(level)
	var props: String = Biomes.props_dir(level)
	var tileset := load("%s/tileset.tres" % dir) as TileSet
	if tileset == null:
		printerr("  missing %s/tileset.tres - run tools/build_biomes.gd first" % dir)
		return true
	DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("%s/fixtures" % props))

	# The room's own files stay at the level's root - the level scene, its door,
	# and the tileset and doorways build_biomes.gd wrote. Everything that STANDS
	# in the room goes in props/, one scene each with its picture baked in.
	var bad := false
	bad = _write_door_scene(dir) or bad
	if Biomes.has_columns(level):
		bad = _write_column_scene(props, spec) or bad
	else:
		_drop("%s/fixtures/column.tscn" % props)
	if Biomes.has_hazard(level):
		bad = _write_torch_scene(props, spec) or bad
	else:
		# A floor that stops having a hazard stops having the scene for one:
		# otherwise the level folder keeps a torch nothing points at, and the
		# next reader has to open the biome to find out which is the truth.
		_drop("%s/fixtures/torch.tscn" % props)
	if Biomes.has_heart(level):
		bad = _write_health_scene(props, spec) or bad
	else:
		_drop("%s/fixtures/health_item.tscn" % props)
	for type in Biomes.prop_types(level):
		bad = _write_prop_scene(props, type, spec) or bad
	bad = _write_level_scene(level, dir, props, tileset) or bad
	return bad


## The level's own pillar, art baked in. No script: a column has no behaviour to
## share, and a level that wants one adds it here without affecting any other.
func _write_column_scene(dir: String, spec: Dictionary) -> bool:
	var root := StaticBody2D.new()
	root.name = "Column"

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.centered = false
	# Origin at the foot of the column: that is what Y-sorting reads to decide
	# whether the player draws in front of it or behind it.
	sprite.position = Vector2(-8, -48)
	sprite.texture = Props.texture(Props.column(spec))
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

	return _pack(root, "%s/fixtures/column.tscn" % dir)


## One piece of furniture, art baked in, in the level's own folder like every
## other prop a level owns. A solid prop blocks only its base - the same trick
## the column uses, so the player passes behind its upper half and Y-sorting
## draws the two in the right order. Decor gets a bare Node2D: a banner nailed
## to a wall has nothing to walk into, and a body with no shape is a lie.
##
## No script: furniture has no behaviour to share. The ones that grow some -
## DESIGN.md's arcing power strip and jammed photocopier - are hazards, and will
## carry hazard_base.gd exactly the way the torch does.
func _write_prop_scene(dir: String, type: String, spec: Dictionary) -> bool:
	# The friendly failure: a biome placing a type tools/props/ has no file for
	# should say so, not die inside a null texture three calls later.
	if not Props.known(type):
		printerr("  nothing in tools/props/ draws '%s'" % type)
		return true
	var blocks := Props.blocks(type)
	var solid := blocks != Vector2.ZERO
	var root: Node2D = StaticBody2D.new() if solid else Node2D.new()
	root.name = type.to_pascal_case()

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.centered = false
	# Props.offset() puts the art's foot on the origin, which is the pixel
	# Y-sorting reads and the pixel the biome's position refers to.
	sprite.position = Props.offset(type)
	sprite.texture = Props.texture(Props.paint(type, spec))
	root.add_child(sprite)
	sprite.owner = root

	if solid:
		var body := CollisionShape2D.new()
		body.name = "CollisionShape2D"
		body.position = Vector2(0, -blocks.y / 2.0)
		var shape := RectangleShape2D.new()
		shape.size = blocks
		body.shape = shape
		root.add_child(body)
		body.owner = root

	# The scene lands on the same shelf its painter sits on in tools/props/,
	# so finding a prop in a level is the same walk as finding its brush.
	var shelf := Props.shelf_of(type)
	DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("%s/%s" % [dir, shelf]))
	return _pack(root, "%s/%s/%s.tscn" % [dir, shelf, type])


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
func _write_torch_scene(dir: String, spec: Dictionary) -> bool:
	var root := Area2D.new()
	root.name = "Torch"
	root.monitorable = false
	root.set_script(load(HAZARD_SCRIPT))

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.centered = false
	# Foot origin, like the column: what Y-sorting reads.
	sprite.position = Vector2(-8, -24)
	sprite.texture = Props.texture(Props.hazard(spec))
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

	return _pack(root, "%s/fixtures/torch.tscn" % dir)


## The level's own heal pickup, on the shared pickup_base.gd.
func _write_health_scene(dir: String, spec: Dictionary) -> bool:
	var root := Area2D.new()
	root.name = "Health"
	root.monitorable = false
	root.set_script(load(PICKUP_SCRIPT))

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.centered = false
	sprite.position = Vector2(-4, -8)
	sprite.texture = Props.texture(Props.heart())
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

	return _pack(root, "%s/fixtures/health_item.tscn" % dir)


func _write_level_scene(level: String, dir: String, props_dir: String, tileset: TileSet) -> bool:
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

	# The colonnade, unless this floor asked for none: DESIGN.md's gym is a
	# tight arena with nothing in it to hide behind, and a biome says so by
	# handing in an empty `columns` layout.
	if Biomes.has_columns(level):
		var layout: Dictionary = Biomes.BIOMES[level].get("columns", {})
		var column_rows: Array = layout.get("rows", COLUMN_ROWS)
		var column_xs: Array = layout.get("xs", COLUMN_XS)
		var column_scene := _reload("%s/fixtures/column.tscn" % props_dir)
		for row in column_rows:
			for col in column_xs:
				var column := column_scene.instantiate()
				column.name = "Column_%d_%d" % [col, row]
				column.position = Vector2(col * TILE + TILE / 2, (row + 1) * TILE)
				props.add_child(column)
				column.owner = root

	# The hazard is per-biome, and a room is allowed to have nothing in it that
	# hurts: see Biomes.has_hazard().
	if Biomes.has_hazard(level):
		var torch := _reload("%s/fixtures/torch.tscn" % props_dir).instantiate()
		torch.name = "Torch"
		torch.position = TORCH_POS
		props.add_child(torch)
		torch.owner = root

	# Same as the hazard: a heart is per-biome, and almost no floor has one.
	if Biomes.has_heart(level):
		var health := _reload("%s/fixtures/health_item.tscn" % props_dir).instantiate()
		health.name = "Health"
		health.position = HEALTH_POS
		props.add_child(health)
		health.owner = root

	# The biome's furniture, from the same list that decided which art to paint.
	# Suffixed by type the way enemies are numbered, so two desks are Desk1 and
	# Desk2 rather than a name collision the packer would silently rename.
	var placed := {}
	for spec in Biomes.BIOMES[level].get("props", []):
		var type: String = spec["type"]
		if not Props.known(type):
			continue   # _write_prop_scene already reported it; do not cascade
		placed[type] = placed.get(type, 0) + 1
		var prop := _reload("%s/%s/%s.tscn"
				% [props_dir, Props.shelf_of(type), type]).instantiate()
		prop.name = "%s%d" % [type.to_pascal_case(), placed[type]]
		prop.position = spec["at"]
		# Rotation is placement, not art: the banner is drawn square and hung
		# crooked, so the same cloth can hang straight somewhere else.
		prop.rotation = spec.get("turn", 0.0)
		props.add_child(prop)
		prop.owner = root

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
	var kept_uid := StableIds.uid_of(path)
	if err == OK:
		err = ResourceSaver.save(packed, path)
	if err == OK:
		StableIds.stabilize(path, kept_uid)
	print("  ", path, " -> ", error_string(err))
	# This tree was never in the SceneTree, so nothing else will ever free it.
	root.free()
	return err != OK


## Removes a scene this level no longer has any use for. Only the fixtures can
## reach this - a floor that gives up its hazard - because they are the ones
## written unconditionally; a prop scene is written from the biome's own list,
## so it simply never appears.
func _drop(path: String) -> void:
	if FileAccess.file_exists(path):
		var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		print("  ", path, " -> removed, ", error_string(err))
