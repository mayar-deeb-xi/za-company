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


## The name this room announces itself by. Authored per biome in
## tools/biomes.gd and written in by the generator.
@export var display_name: String = ""

## The track this floor plays, empty for the building's bed (Music.DEFAULT).
## Authored per biome and written in by the generator exactly as display_name
## is, because a floor's music is the same kind of fact about it as its name.
##
## It hangs on the FLOOR rather than on a boss, which is the one thing to
## understand here. A boss names his own theme on his scene and that still wins
## while he is fighting (game.gd's _watch_boss), but a theme is HIS and dies
## with the fight: the last two floors share one track across a door, and only
## one of them has anybody standing on it to name it.
@export_file("*.wav") var music: String = ""


## Third of the questions a level answers about itself, alongside bounds() and
## spawn_position(). Falls back to the node name so a level hand-built in the
## editor still announces something rather than a blank card.
func title() -> String:
	return display_name if not display_name.is_empty() else name


## World-space extent of the map, measured from the wall ring rather than stored
## as a constant, so resizing a level in the editor moves the camera limits with
## it automatically.
func bounds() -> Rect2:
	var walls := $Walls as TileMapLayer
	var used := walls.get_used_rect()
	var tile := Vector2(walls.tile_set.tile_size)
	return Rect2(Vector2(used.position) * tile, Vector2(used.size) * tile)


## The walk between the two doors, in world pixels, as a list of legs. Authored
## per biome and written in by the generator exactly as display_name and music
## are - and empty on every floor that is the room every floor is, where the
## walk is the straight band the whole building keeps clear.
##
## Nothing in game/ reads it, which is the one thing to understand about it
## being here. The rule it carries - no enemy's sight, no hazard and no prop on
## the walk between the doors - is the oldest one in the project and the only
## one enforced from OUTSIDE the game, by four suites reading the chain off
## disk. They agreed on x 246-300 by each writing it down, which was true while
## every floor was the same rectangle; the call floor's way up is now at the top
## of an arm, so its walk has two turns in it. A floor that knows its own shape
## is the alternative to four files being told about it.
@export var lane: Array[Rect2] = []

## The default it is empty for: the straight band both doors are cut into, the
## full height of the room. DOOR_COL 16 of 34 puts their centre at x 272, and
## the band is a body's width either side of it.
const STRAIGHT_LANE_X := 246.0
const STRAIGHT_LANE_WIDTH := 54.0


## Where the player walks from one door to the other, whatever shape the room
## is. Legs may overlap - they meet at the corners, which is the whole point:
## the turn has to be inside the lane or the walk clips a wall.
##
## The default is inset by the wall ring rather than run the full height of the
## map. A doorway is a gap two tiles wide and the band is three and a half, so
## the corners of an un-inset band are the masonry either side of the door -
## which reads as a walk that starts inside a wall.
func walk_lane() -> Array[Rect2]:
	if not lane.is_empty():
		return lane
	var box := bounds()
	var ring := Vector2(($Walls as TileMapLayer).tile_set.tile_size).y
	return [Rect2(STRAIGHT_LANE_X, box.position.y + ring,
		STRAIGHT_LANE_WIDTH, box.size.y - ring * 2.0)]


## How far a point is from the walk: 0 while it is standing on it. What the
## placement rule is measured in - an enemy clears the lane by its own sight
## radius, so a body with 80 px of sight needs 80 back from every leg.
func lane_clearance(at: Vector2) -> float:
	var clear := INF
	for leg in walk_lane():
		var inside := Vector2(
			clampf(at.x, leg.position.x, leg.end.x),
			clampf(at.y, leg.position.y, leg.end.y))
		clear = minf(clear, at.distance_to(inside))
	return clear


## Where the player stands on arrival. An unknown name falls back to the middle
## of the map: a mistyped door target should drop you somewhere recoverable
## rather than at the world origin, outside the walls.
func spawn_position(spawn: StringName) -> Vector2:
	var marker := $Spawns.get_node_or_null(NodePath(String(spawn)))
	if marker is Marker2D:
		return (marker as Marker2D).global_position
	push_warning("%s has no spawn named '%s'" % [scene_file_path, spawn])
	return bounds().get_center()
