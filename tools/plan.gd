extends RefCounted
## A floor's PLAN: how big the room is, what is cut out of it, where its two
## doors are cut, and which tile goes in every cell of the result.
##
## This is the one thing about a level that build_levels.gd does NOT assemble
## from a list - it asks here and paints what it is told - and it is its own
## file for the reason `tools/props.gd` is: the generator's job is putting
## things in a room, and a floor plan is a subject with its own vocabulary.
## Adding a shape nobody has drawn yet should be a new key HERE, and not a
## fourteenth branch in the middle of the code that places furniture.
##
## ## The room is a predicate, not a list of cases
##
## Everything a shape implies falls out of one question - `solid(col, row)`,
## is this cell the building or the room? The wall ring is drawn around
## whatever answers no, the shadow course hugs it, a doorway is cut where its
## own column meets the wall, and a colonnade skips the pillars that would
## land in masonry. So a new shape teaches this file one new way to answer
## that question and changes nothing anywhere else.
##
## Three ways to answer it today, in the order a floor should reach for them:
##
## - **nothing at all** - the 34 x 19 room every floor was before a floor plan
##   was a thing one could have. Eleven of the twelve floors say nothing.
## - **`cut`** - the room, minus a list of tile rectangles. One cut off a
##   corner is an L (the call floor), two facing cuts are a neck, a cut in the
##   middle is an atrium. This covers every shape that is still rectangles, and
##   the walls come for free: they are grown around whatever is left.
## - **`mask`** - the plan drawn out, one string per row, `#` for masonry and
##   anything else for floor. For the floor that is not rectangles at all: a
##   diagonal, a spiral, a room with a hole the shape of a lift shaft. It is
##   bulky on purpose, because a floor that needs it is a floor somebody has
##   actually drawn, and a picture of the room in the room's own data file is
##   worth thirty lines. It is also the one form taken LITERALLY - the hand
##   that drew the plan drew its walls - so a mask must include its own ring.
##
## A mask row that runs short is SOLID for the rest of the row, which is the
## failing that costs nothing: a truncated plan grows a wall, where the other
## way round it opens a hole into the void with the clear colour showing
## through it.

const TILE := 16
## The room every floor is unless its biome says otherwise.
const COLS := 34                 # 544 px
const ROWS := 19                 # 304 px - about a quarter less area than 40x22

## Doors sit in a 2-tile gap cut through the wall ring: north to the next
## level, south back to the previous one. This column is chosen so the gap
## straddles the map's centre line, which is where both doors are on every
## rectangular floor. A shaped floor may move either - the call floor's way up
## is at the top of an arm the rest of the room cannot see.
const DOOR_COL := 16

## Far enough from a threshold that arriving there does not re-trigger the door
## you just came out of. The southern one is measured from the wall it is cut
## into rather than written as a height, so a floor that grows southwards still
## puts the player a body's length inside the room instead of halfway up it.
const SPAWN_START_INSET := 48
const SPAWN_RETURN_Y := 80

## How many rows either side of the middle one the runner covers. The colonnade
## flanks it, and on a 19-row floor it is rows 8-10. Derived from the room's own
## height rather than written down, so a taller floor's carpet stays in the
## middle of it instead of a third of the way up.
const RUNNER_BAND := 1

## Atlas coordinates, mirroring the layout in tools/build_biomes.gd.
const FLOOR := Vector2i(0, 0)
const FLOOR_ALT := Vector2i(1, 0)
const FLOOR_WORN := Vector2i(3, 0)
const WALL := Vector2i(0, 1)
const WALL_LIT := Vector2i(2, 1)
const WALL_DARK := Vector2i(3, 1)

var cols := COLS
var rows := ROWS
## The tile column each doorway is cut at: `out` north to the next floor,
## `back` south to the previous one.
var out_col := DOOR_COL
var back_col := DOOR_COL

var _cut: Array[Rect2i] = []
var _mask := PackedStringArray()


## Built from a biome's `shape` key, which every floor is allowed not to have.
func _init(shape: Dictionary = {}) -> void:
	cols = shape.get("cols", COLS)
	rows = shape.get("rows", ROWS)
	for rect: Rect2i in shape.get("cut", []):
		_cut.append(rect)
	for line: String in shape.get("mask", []):
		_mask.append(line)
	if not _mask.is_empty():
		# A drawn plan is the authority on its own size, so the two numbers
		# above are read off it rather than repeated beside it and left to
		# drift. Width is the longest row: short rows fill with wall.
		rows = _mask.size()
		var widest := 0
		for line in _mask:
			widest = maxi(widest, line.length())
		cols = maxi(widest, 1)
	var doors: Dictionary = shape.get("doors", {})
	out_col = doors.get("out", DOOR_COL)
	back_col = doors.get("back", DOOR_COL)


## Is this tile the building rather than the room?
##
## The wall ring is GROWN rather than authored: a cell is solid where the room
## is not, and also where the room is but something next to it is not. That is
## the whole reason a 34 x 19 floor has a 32 x 17 walkable middle, and it is
## what makes a cut into a room with walls round it rather than a hole.
##
## A drawn `mask` is the exception and is taken literally - `#` is masonry and
## nothing else is. Somebody drawing a floor plan by hand has already drawn the
## walls, and growing a second ring inside theirs would eat the drawing.
func solid(col: int, row: int) -> bool:
	if not _mask.is_empty():
		if row < 0 or row >= _mask.size() or col < 0:
			return true
		var line: String = _mask[row]
		return col >= line.length() or line[col] == "#"
	if _beyond(col, row):
		return true
	for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if _beyond(col + step.x, row + step.y):
			return true
	return false


## Where the room is not at all, before any wall is grown around it: off the
## plan, or inside one of its cuts.
func _beyond(col: int, row: int) -> bool:
	if col < 0 or row < 0 or col >= cols or row >= rows:
		return true
	for rect in _cut:
		if rect.has_point(Vector2i(col, row)):
			return true
	return false


## Is this cell a wall anybody will ever SEE?
##
## A wall is the FACE the building turns to the room - one tile of it, corners
## included - and nothing behind that face is drawn at all. On the eleven
## rectangular floors that is every solid cell there is, so this says nothing
## about them; on a shaped floor it is the difference between a cut filled with
## masonry and a cut left as a hole.
##
## The hole is the one that looks right, and it is the same answer the camera
## already gives: the screen left over around a small room is void rather than
## rock, because a slab of the level's own stone with nothing happening in it
## reads as a room the player has been shut out of, where black reads as the
## edge of the picture. A cut is that void arriving in the middle of the map
## instead of around it, so it takes the same treatment.
func drawn(col: int, row: int) -> bool:
	if not solid(col, row):
		return false
	for x in [-1, 0, 1]:
		for y in [-1, 0, 1]:
			if not solid(col + x, row + y):
				return true
	return false


## The wall's three tiles, chosen by what a cell is NEXT to rather than by
## where it is in the grid. That is the same thing on a plain rectangle - a
## top-edge tile is exactly a solid one with room below it - and the only
## version of it that also dresses the inside of a cut.
func wall_tile(col: int, row: int) -> Vector2i:
	if not solid(col, row + 1):
		return WALL_LIT
	for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not solid(col + step.x, row + step.y):
			return WALL
	for step in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		if not solid(col + step.x, row + step.y):
			return WALL_DARK
	return WALL


func floor_tile(col: int, row: int) -> Vector2i:
	# A darker course hugging the wall reads as the shadow the wall casts. Read
	# off the neighbours for the reason the wall tiles are: on a rectangle this
	# is exactly one tile in from the edge, and on a shaped floor it is also
	# one tile in from the inside of every cut.
	for x in [-1, 0, 1]:
		for y in [-1, 0, 1]:
			if solid(col + x, row + y):
				return FLOOR_WORN
	if absi(row - (rows - 1) / 2) <= RUNNER_BAND:
		return FLOOR_ALT
	return FLOOR


## Where a doorway cut at tile column `col` in wall row `row` stands, in world
## pixels: the centre of the two-tile gap.
func door_at(col: int, row: int) -> Vector2:
	return Vector2(col * TILE + TILE, row * TILE + TILE / 2)


## The two tile columns a doorway occupies, so the wall can be opened there.
func doorway_cols(col: int) -> Array[int]:
	return [col, col + 1]


## Where the player stands having come UP from the floor below: inside the
## south door, which on a shaped floor need not be the one they leave by.
func start_at() -> Vector2:
	return Vector2(door_at(back_col, 0).x, (rows - 1) * TILE - SPAWN_START_INSET)


## And having come back DOWN from the floor above.
func returned_at() -> Vector2:
	return Vector2(door_at(out_col, 0).x, SPAWN_RETURN_Y)
