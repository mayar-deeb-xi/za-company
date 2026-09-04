extends Node2D
class_name Level
## One playable map: a floor layer, a solid wall layer, props, spawn markers.
##
## Levels never touch the player or the camera. The host scene (game.tscn) keeps
## those and asks the level where to stand and how far the camera may travel, so
## a new biome is a new folder and a line in tools/build_levels.gd - no changes
## to game.gd, and no per-level camera numbers to keep in sync by hand.
##
## Nodes are looked up per call rather than cached with @onready: callers ask
## for bounds and spawns in the same frame they add the level, and _ready has
## not necessarily run by then.


## World-space extent of the map, measured from the wall ring rather than stored
## as a constant, so resizing a level in the editor moves the camera limits with
## it automatically.
func bounds() -> Rect2:
	var walls := $Walls as TileMapLayer
	var used := walls.get_used_rect()
	var tile := Vector2(walls.tile_set.tile_size)
	return Rect2(Vector2(used.position) * tile, Vector2(used.size) * tile)


## Where the player stands on arrival. An unknown name falls back to the middle
## of the map: a mistyped door target should drop you somewhere recoverable
## rather than at the world origin, outside the walls.
func spawn_position(spawn: StringName) -> Vector2:
	var marker := $Spawns.get_node_or_null(NodePath(String(spawn)))
	if marker is Marker2D:
		return (marker as Marker2D).global_position
	push_warning("%s has no spawn named '%s'" % [scene_file_path, spawn])
	return bounds().get_center()
