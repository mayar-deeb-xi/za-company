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
##            furnished room needs the floor a full colonnade takes up. Both
##            lists EMPTY means no colonnade at all, and then the level has no
##            column scene either - DESIGN.md's gym is a tight arena with
##            nothing in it to hide behind.
##   hazard   which hazard art the level gets - "torch", "polisher",
##            "power_strip", "fallen_light" or "copier", or "none" for a floor
##            with nothing on it to hurt you. Omitted means "torch": a floor
##            that has no hazard says so, rather than the absence of a key
##            deciding it.
##   heart    true to stand a heal pickup in the room. Omitted means NO, and
##            that default is the rule rather than a convenience - only the
##            lobby hands one out, and from floor 2 up healing is Ivan's job.
##   runner   how far the central floor band is tinted towards the accent, i.e.
##            whether that band is carpet or just more of the same stone.

## Floor order, and it is the order a run walks: south door goes back down
## the list, north door goes up it. The building is DESIGN.md's ten floors in
## its own order, and the two demo biomes are dealt INTO it - the marble hall
## between the shared floor and the dev floor, hellfire between the bullpen
## and the executive floor - so a run still walks through both of them and
## ends where the story ends, in Khaled's office.
const CHAIN := ["lobby", "content_studio", "call_center", "ahmed_office",
		"shared_floor", "marble_hall", "dev_floor", "conflict_resolution",
		"bullpen", "hellfire", "executive_floor", "khaled_office"]

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


## Whether this floor stands a hazard in the room at all. The lobby is the
## reason it can say no: floor 1 is where a new player learns to walk, and the
## one thing a tutorial room must not have is a way to lose health by walking
## into the scenery. Ahmed's office says no for the opposite reason - the only
## thing in there that hurts is Ahmed.
static func has_hazard(level: String) -> bool:
	return BIOMES[level].get("hazard", "torch") != "none"


## Whether this floor puts a heart on its floor, and the default is NO - which
## is the whole of the rule. Healing is not something a room hands out: the
## lobby is the one floor that does, because floor 1 is where a player finds out
## what a heal even is, and from floor 2 up the supply is Ivan, who brings it to
## you (DESIGN.md, build step 4). A floor that wants one says `"heart": true`.
static func has_heart(level: String) -> bool:
	return BIOMES[level].get("heart", false)


## Whether this floor stands a colonnade at all. A biome hands in an empty
## `columns` layout to get none - DESIGN.md's gym is a tight arena with nothing
## in it to hide behind - and a floor that places no pillar does not carry the
## scene for one either. An absent `columns` key still means the generator's
## own six-by-two, which is what every floor built before this one relies on.
static func has_columns(level: String) -> bool:
	var layout: Dictionary = BIOMES[level].get("columns", {})
	return not layout.get("rows", [0]).is_empty() \
		and not layout.get("xs", [0]).is_empty()


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
