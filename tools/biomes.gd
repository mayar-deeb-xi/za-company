extends RefCounted
## Shared biome data for the tools/ generators. Editor-side only - nothing under
## res://game or res://tests loads this.
##
## Adding a biome is one edit here, then a run of build_biomes.gd followed by
## build_levels.gd. CHAIN is the order you walk the levels in: each level gets a
## door north to the next and a door south to the one before, and the two ends
## of the chain simply have one door instead of two.
##
## Value ramps run darkest first. Source pixels from the shared dungeon sheet are
## mapped onto a ramp by luminance; `gamma` bends that mapping (above 1.0 pushes
## mid-tones down while leaving highlights hot) and `floor_band` then confines
## floors to a slice of the ramp, because a floor that reaches the hot end of
## the hellfire ramp turns into gold flooring the player cannot be seen against.
##
## `title` is the name the room announces itself by on arrival, written into the
## level scene as an export. It is authored rather than derived from `node`,
## because "THE MARBLE HALL" is not a transformation of "MarbleHall" that any
## rule gets right for every room ("HELLFIRE" takes no article).
##
## `enemies` is what build_levels.gd dresses a fresh level with: a type (a folder
## under game/enemies/) and a position in level pixels. It lives here rather than
## as one constant in the generator because composition is most of what makes one
## room feel unlike the next - the marble hall is two guards you can walk past,
## and hellfire is where something starts following you. Positions are chosen so
## no enemy's sight reaches the door line, the spawns or the torch and heart
## stands: the straight walk between the two doors stays safe in every biome.
##
## `props` is the same idea for furniture - a type from tools/props.gd and a
## position - and it is what dresses a room as somewhere rather than as a
## rectangle. Keys that go with it, all optional and all defaulted so the two
## demo biomes need none of them:
##
##   props    furniture: [{type, at, turn}]. `turn` rotates the instance about
##            its pin, which is how the banner hangs crooked.
##   column   which architecture the level's pillar is - "classical" (the
##            fluted stone default) or "pillar" (glazed steel).
##   columns  {rows, xs} overriding the generator's colonnade, because a
##            furnished room needs the floor a full colonnade takes up.
##   hazard   which hazard art the level gets - "torch" or "polisher".
##   runner   how far the central floor band is tinted towards the accent, i.e.
##            whether that band is carpet or just more of the same stone.

## Floor order. The office floors are being built in front of the two demo
## biomes, which stay on the end until they are replaced.
const CHAIN := ["lobby", "bullpen", "marble_hall", "hellfire"]

const BIOMES := {
	"lobby": {
		"node": "Lobby",
		"title": "THE LOBBY",
		# Floor 1 of THE NEW HIRE: glass-and-steel corporate reception, cool and
		# over-lit, deliberately the least threatening room in the game. Blue-grey
		# marble rather than the marble hall's neutral white, and a green accent
		# rather than gold, so the two read apart while both are still stone.
		"ramp": ["141a24", "2f3a4a", "56637a", "8c99ad", "c6cfdb", "f2f5f9"],
		"accent": "45c98a",
		# Below 1.0 lifts the mid-tones: polished stone under too many downlights.
		"gamma": 0.80,
		# Bright band, but stopping short of the ramp's pure white - a floor at the
		# hot end takes the pale characters (bald, white-haired) with it.
		"floor_band": Vector2(0.35, 0.95),
		# The central band is carpet, not more marble: it is the widest stretch
		# of floor the furniture is kept off (the combat lane, see `props`), so
		# it is also the emptiest, and a runner is what a lobby puts there.
		"runner": 0.30,
		# Glass-and-steel pillars rather than fluted stone, and four of them
		# instead of twelve: the colonnade is what made this room read as a
		# temple, and the floor it leaves clear is where the furniture goes.
		"column": "pillar",
		"columns": {"rows": [5, 13], "xs": [4, 29]},
		# The torch reskinned, per DESIGN.md: a floor polisher left running.
		"hazard": "polisher",
		# The furniture. Reception faces the way you came in with the dead plant
		# at the end of the counter, the cooler and a living plant are on the far
		# wall, the waiting area is the bottom-right corner, and two sign-in
		# workstations fill the bottom-left.
		#
		# Every position here is picked around what has to stay walkable, and in
		# this room that is not only the door line: the lobby is floor 1 and
		# empty, so tests/test_combat.gd uses it as its arena and fights across
		# the middle of it. Two lanes are kept clear on purpose - the vertical
		# strip on the door line (x 246-300, all the way down to the start
		# marker) and the whole central band (y 122-200, x 86-352, the runner the
		# colonnade already flanks). Furniture lives above, below and outside
		# those, which is also where a real lobby puts it.
		"props": [
			{"type": "reception", "at": Vector2(168, 92)},
			{"type": "dead_plant", "at": Vector2(232, 88)},
			{"type": "cooler", "at": Vector2(436, 78)},
			{"type": "plant", "at": Vector2(404, 74)},
			{"type": "plant", "at": Vector2(40, 66)},
			# Hung by one corner and tilted about that corner, so it reads as
			# something nobody came back to straighten.
			{"type": "banner", "at": Vector2(318, 20), "turn": 0.14},
			{"type": "sofa", "at": Vector2(430, 244)},
			{"type": "table", "at": Vector2(430, 272)},
			{"type": "desk", "at": Vector2(108, 250)},
			{"type": "chair", "at": Vector2(108, 262)},
			{"type": "desk", "at": Vector2(180, 250)},
			{"type": "chair", "at": Vector2(180, 262)},
		],
		# Deliberately empty. The design gives floor 1 two office boys, but that
		# type does not exist yet (build order step 2, with the other reskins);
		# placing `regular` here would dress the lobby with dungeon guards and then
		# need undoing. An empty room is the honest intermediate state.
		"enemies": [],
	},
	"bullpen": {
		"node": "Bullpen",
		"title": "THE BULLPEN",
		# Floor 2: the office boys' own floor, and the first real fight. Where
		# the lobby is over-lit glass and polished stone, this is the back of
		# house - dim, warm, worn, lit by whatever tubes still work. The ramp is
		# brown-grey rather than blue-grey so walking out of the lobby reads as
		# leaving the part of the building visitors see.
		"ramp": ["17130f", "302a22", "544a3c", "857a66", "b8ad96", "e4dcc8"],
		# Amber: warning lights, hazard tape, the colour of something being
		# worked on. Deliberately not the lobby's company teal - that teal is
		# now on the office boys' polos instead, so the uniform reads against
		# the room rather than into it.
		"accent": "e8a33a",
		# Above the lobby's 0.80: this floor is not over-lit, it is under-lit.
		"gamma": 0.95,
		# Dimmer than the lobby's floor and further from the ramp's top - a
		# working floor, not a polished one. Still bright enough in the middle
		# that the dark-haired half of the cast reads against it.
		"floor_band": Vector2(0.28, 0.78),
		# Scuffed carpet tiles down the middle rather than the lobby's clean
		# runner: the same band, less of the accent in it.
		"runner": 0.18,
		# DESIGN.md's "dividers as columns". Six of them in two rows, the full
		# colonnade, because on this floor the dividers ARE the open plan - and
		# they break the sight lines that let four office boys be pulled one at
		# a time instead of arriving together.
		"column": "divider",
		"hazard": "power_strip",
		# The junk. The brief for this room is that the office boys are the
		# people who fix things in this company and they are behind, so the
		# floor is their workshop: server racks along the top wall, e-waste
		# heaped down both sides, hardware in bits on every surface, and a
		# printer nobody has been able to use for weeks.
		#
		# It is dressed heavily but NOT in the middle. Two things need open
		# floor: a four-on-one fight, and the heavy attack this floor teaches -
		# an AoE is worthless in a room where you cannot gather anybody. So the
		# junk is a thick perimeter around a clear arena (about x 200-350,
		# y 110-200), which is also what makes the corners feel like somewhere
		# you go to pick a fight rather than somewhere you get cornered.
		#
		# Everything solid also has to leave the enemies room to leave their own
		# corners: they walk straight at the player and slide off what they hit,
		# with no pathfinding to recover from being wedged.
		"props": [
			# The server bank along the top wall, and the machine with the sign.
			{"type": "server_rack", "at": Vector2(150, 56)},
			{"type": "server_rack", "at": Vector2(176, 56)},
			{"type": "server_rack", "at": Vector2(202, 56)},
			{"type": "scrap_pile", "at": Vector2(228, 64)},
			{"type": "printer", "at": Vector2(340, 56)},
			{"type": "notice", "at": Vector2(372, 22), "turn": -0.09},
			{"type": "cooler", "at": Vector2(452, 48)},
			{"type": "dead_plant", "at": Vector2(492, 96)},
			# E-waste heaped down both side walls.
			{"type": "crt_stack", "at": Vector2(44, 128)},
			{"type": "scrap_pile", "at": Vector2(44, 176)},
			{"type": "pc_tower", "at": Vector2(44, 208)},
			{"type": "cable_spool", "at": Vector2(492, 130)},
			{"type": "scrap_pile", "at": Vector2(492, 178)},
			{"type": "toolbox", "at": Vector2(490, 212)},
			# Work in progress on the way into the arena.
			{"type": "toolbox", "at": Vector2(196, 96)},
			{"type": "pc_tower", "at": Vector2(330, 96)},
			{"type": "toolbox", "at": Vector2(452, 108)},
			{"type": "scrap_pile", "at": Vector2(76, 108)},
			# Junk narrowing the two approaches into the arena, without being in
			# it. Each of these was checked against the straight line its nearest
			# office boy walks to the middle: they walk at the player and slide
			# off what they hit, so a prop parked on that line is a prop one of
			# them grinds along on its way to the fight.
			{"type": "scrap_pile", "at": Vector2(168, 128)},
			{"type": "crt_stack", "at": Vector2(392, 128)},
			{"type": "pc_tower", "at": Vector2(176, 188)},
			{"type": "cable_spool", "at": Vector2(400, 190)},
			# Litter, which is the only thing that goes IN the arena: it blocks
			# nothing, so the floor can look worked-on without the fight or the
			# heavy losing the room they need.
			{"type": "debris", "at": Vector2(250, 140)},
			{"type": "debris", "at": Vector2(322, 124)},
			{"type": "debris", "at": Vector2(296, 178)},
			{"type": "debris", "at": Vector2(218, 192)},
			{"type": "debris", "at": Vector2(272, 210)},
			{"type": "debris", "at": Vector2(92, 200)},
			{"type": "debris", "at": Vector2(462, 166)},
			# The open plan itself: three desks nobody has tidied.
			{"type": "desk", "at": Vector2(72, 268)},
			{"type": "chair", "at": Vector2(72, 282)},
			{"type": "desk", "at": Vector2(196, 268)},
			{"type": "chair", "at": Vector2(196, 282)},
			{"type": "desk", "at": Vector2(348, 268)},
			{"type": "chair", "at": Vector2(348, 282)},
			{"type": "toolbox", "at": Vector2(160, 236)},
			{"type": "crt_stack", "at": Vector2(232, 240)},
			{"type": "cable_spool", "at": Vector2(352, 236)},
			{"type": "printer", "at": Vector2(470, 272)},
		],
		# Four office boys, one to a quadrant rather than a line, so the room is
		# fought a corner at a time - and so the heavy has something to be the
		# right answer to once two of them are following you.
		#
		# Every one of them is clear of the door line, both spawns and both
		# stands by more than its 80 px sight: the closest call is 89-96 px to
		# the hazard and the heart, which is deliberate - the pickups on this
		# floor are nearly, but not quite, watched.
		#
		# None of them stands on a divider's x either, and that one is easy to
		# get wrong: the colonnade sits at x 72/152/232/312/392/472 with its art
		# 48 px tall, so an enemy parked at one of those x values and a lower y
		# than the divider's foot is drawn BEHIND it and simply cannot be seen
		# until it walks out. Two of these were at x 72 and 472 and were
		# invisible in the room.
		"enemies": [
			{"type": "office_boy", "at": Vector2(104, 60)},
			{"type": "office_boy", "at": Vector2(436, 64)},
			{"type": "office_boy", "at": Vector2(120, 248)},
			{"type": "office_boy", "at": Vector2(424, 248)},
		],
	},
	"marble_hall": {
		"node": "MarbleHall",
		"title": "THE MARBLE HALL",
		"ramp": ["2f323c", "6e7382", "a9aebb", "d5d9e2", "f0f2f6", "ffffff"],
		"accent": "e8c56a",
		"gamma": 0.85,
		"floor_band": Vector2(0.30, 1.00),
		# Four guards, one to a corner rather than a line across the top, so they
		# can be picked off one at a time instead of arriving as a wall.
		"enemies": [
			{"type": "regular", "at": Vector2(64, 48)},
			{"type": "regular", "at": Vector2(480, 48)},
			{"type": "regular", "at": Vector2(150, 264)},
			{"type": "regular", "at": Vector2(400, 264)},
		],
	},
	"hellfire": {
		"node": "Hellfire",
		"title": "HELLFIRE",
		"ramp": ["120309", "3a0b12", "71160f", "b8300d", "f0761a", "ffd45e"],
		"accent": "ffd45e",
		"gamma": 2.1,
		"floor_band": Vector2(0.02, 0.42),
		# The escalation: the same two guards, plus the two that do something
		# other than damage. Both have wide sight, so they sit along the far
		# wall from the spawn you arrive on - the warden especially, since its
		# 130 px is the longest look in the game and every walkable line in the
		# marble hall falls inside it, which is why that room has none.
		"enemies": [
			{"type": "regular", "at": Vector2(64, 48)},
			{"type": "regular", "at": Vector2(170, 48)},
			{"type": "regular", "at": Vector2(374, 48)},
			{"type": "regular", "at": Vector2(480, 48)},
			{"type": "wraith", "at": Vector2(272, 48)},
			{"type": "wraith", "at": Vector2(424, 280)},
			{"type": "warden", "at": Vector2(64, 152)},
		],
	},
}


static func dir(level: String) -> String:
	return "res://game/levels/%s" % level


## Where a level keeps the scenes for the things standing in it. Split out from
## the level's own folder because those two groups behave completely
## differently: the room is a handful of files that never grow (the level scene,
## its tileset, its door and one doorway per neighbour), while this holds one
## scene per prop the biome uses and grows every time a floor wants a new piece
## of furniture. The bullpen wanted sixteen, which buried the five files that
## actually say what the level IS.
static func props_dir(level: String) -> String:
	return "%s/props" % dir(level)


## The distinct prop types a biome places, in the order it first places them.
## Derived rather than declared: build_biomes.gd paints exactly this list and
## build_levels.gd writes a scene for exactly this list, so a floor can neither
## place furniture it has no art for nor carry art for furniture it never puts
## down.
static func prop_types(level: String) -> Array:
	var types: Array = []
	for entry in BIOMES[level].get("props", []):
		var type: String = entry["type"]
		if not types.has(type):
			types.append(type)
	return types


## Reads a biome's own ramp at `t` (0 = darkest stop, 1 = brightest), bent by
## that biome's gamma. The one place a shade is resolved: build_biomes.gd paints
## tiles and architecture through it and props.gd paints furniture through it,
## so a desk and the floor it stands on are lit by the same curve.
static func shade(spec: Dictionary, t: float) -> Color:
	return ramp(spec["ramp"], t, spec["gamma"])


static func ramp(stops: Array, t: float, gamma: float) -> Color:
	var scaled := pow(clampf(t, 0.0, 1.0), gamma) * float(stops.size() - 1)
	var i := int(floor(scaled))
	if i >= stops.size() - 1:
		return Color(stops[stops.size() - 1])
	return Color(stops[i]).lerp(Color(stops[i + 1]), scaled - float(i))


## The level one step further along the chain, or "" at the end of it.
static func next_of(level: String) -> String:
	var i := CHAIN.find(level)
	return CHAIN[i + 1] if i >= 0 and i + 1 < CHAIN.size() else ""


## The level one step back along the chain, or "" at the start of it.
static func previous_of(level: String) -> String:
	var i := CHAIN.find(level)
	return CHAIN[i - 1] if i > 0 else ""
