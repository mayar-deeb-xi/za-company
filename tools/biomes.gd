extends RefCounted
## The floor plan of the game: which levels exist, in what order, and the
## helpers every generator reads them through. Editor-side only - nothing under
## res://game or res://tests loads this.
##
## THE DATA LIVES IN tools/biomes/<level>.gd, ONE FILE PER FLOOR. You design a
## room as a room, so everything about one floor - palette, furniture, enemies,
## and the comments about which lanes must stay clear - sits in one small file
## you can hold in one screen. Adding a floor is a new file there plus its name
## in CHAIN below, then a run of build_biomes.gd and build_levels.gd (and its
## NEIGHBOURS in build_levels.gd too, if it was inserted mid-chain - their door
## targets bake in).
##
## ## The keys a floor's BIOME dictionary can carry
##
## Value ramps run darkest first. Source pixels from the shared dungeon sheet
## are mapped onto a ramp by luminance; `gamma` bends that mapping (above 1.0
## pushes mid-tones down while leaving highlights hot) and `floor_band` then
## confines floors to a slice of the ramp, because a floor that reaches the hot
## end of the hellfire ramp turns into gold flooring the player cannot be seen
## against.
##
## `title` is the name the room announces itself by on arrival, written into
## the level scene as an export. It is authored rather than derived from
## `node`, because "THE MARBLE HALL" is not a transformation of "MarbleHall"
## that any rule gets right for every room ("HELLFIRE" takes no article).
##
## `enemies` is what build_levels.gd dresses a fresh level with: a type (a
## folder under game/enemies/) and a position in level pixels. Composition is
## most of what makes one room feel unlike the next. Positions are chosen so no
## enemy's sight reaches the door line, the spawns or the hazard and heart
## stands: the straight walk between the two doors stays safe in every biome.
##
## `props` is the same idea for furniture - a type from tools/props/ and a
## position - and it is what dresses a room as somewhere rather than as a
## rectangle. Keys that go with it, all optional and all defaulted so the two
## demo biomes need none of them:
##
##   props    furniture: [{type, at, turn}]. `turn` rotates the instance about
##            its pin, which is how the banner hangs crooked.
##   column   which architecture the level's pillar is - "classical" (the
##            fluted stone default), "pillar" (glazed steel) or "divider"
##            (cubicle partition).
##   columns  {rows, xs} overriding the generator's colonnade, because a
##            furnished room needs the floor a full colonnade takes up.
##   hazard   which hazard art the level gets - "torch", "polisher" or
##            "power_strip".
##   runner   how far the central floor band is tinted towards the accent, i.e.
##            whether that band is carpet or just more of the same stone.

## Floor order. The office floors are being built in front of the two demo
## biomes, which stay on the end until they are replaced.
const CHAIN := ["lobby", "bullpen", "marble_hall", "hellfire"]

## Assembled from the per-floor files at load, keyed by CHAIN name, so every
## existing `Biomes.BIOMES[level]` read works exactly as it did when this was
## one hand-written dictionary.
static var BIOMES: Dictionary = _collect()


static func _collect() -> Dictionary:
	var all := {}
	for level in CHAIN:
		var script := load("res://tools/biomes/%s.gd" % level) as GDScript
		if script == null:
			push_error("no tools/biomes/%s.gd for CHAIN entry '%s'" % [level, level])
			continue
		all[level] = script.get_script_constant_map()["BIOME"]
	return all


static func dir(level: String) -> String:
	return "res://game/levels/%s" % level


## Where a level keeps the scenes for the things standing in it. Split out from
## the level's own folder because those two groups behave completely
## differently: the room is a handful of files that never grow (the level scene,
## its tileset, its door and one doorway per neighbour), while this holds one
## scene per prop the biome uses and grows every time a floor wants a new piece
## of furniture. The bullpen wanted sixteen, which buried the five files that
## actually say what the level IS. Inside it, build_levels.gd shelves each
## scene the way its painter is shelved in tools/props/ (Props.shelf_of()),
## plus fixtures/ for the level-placed column, torch and health item.
static func props_dir(level: String) -> String:
	return "%s/props" % dir(level)


## The distinct prop types a biome places, in the order it first places them.
## Derived rather than declared: build_levels.gd writes a scene for exactly
## this list, so a floor cannot carry scenes for furniture it never puts down.
static func prop_types(level: String) -> Array:
	var types: Array = []
	for entry in BIOMES[level].get("props", []):
		var type: String = entry["type"]
		if not types.has(type):
			types.append(type)
	return types


## The level one step further along the chain, or "" at the end of it.
static func next_of(level: String) -> String:
	var i := CHAIN.find(level)
	return CHAIN[i + 1] if i >= 0 and i + 1 < CHAIN.size() else ""


## The level one step back along the chain, or "" at the start of it.
static func previous_of(level: String) -> String:
	var i := CHAIN.find(level)
	return CHAIN[i - 1] if i > 0 else ""


## Reads a biome's own ramp at `t` (0 = darkest stop, 1 = brightest), bent by
## that biome's gamma. The one place a shade is resolved: the tileset, the
## doorways and every prop are all lit by the same curve.
static func shade(spec: Dictionary, t: float) -> Color:
	return ramp(spec["ramp"], t, spec["gamma"])


static func ramp(stops: Array, t: float, gamma: float) -> Color:
	var scaled := pow(clampf(t, 0.0, 1.0), gamma) * float(stops.size() - 1)
	var i := int(floor(scaled))
	if i >= stops.size() - 1:
		return Color(stops[stops.size() - 1])
	return Color(stops[i]).lerp(Color(stops[i + 1]), scaled - float(i))
