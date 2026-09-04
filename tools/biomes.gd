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
## `enemies` is what build_levels.gd dresses a fresh level with: a type (a folder
## under game/enemies/) and a position in level pixels. It lives here rather than
## as one constant in the generator because composition is most of what makes one
## room feel unlike the next - the marble hall is two guards you can walk past,
## and hellfire is where something starts following you. Positions are chosen so
## no enemy's sight reaches the door line, the spawns or the torch and heart
## stands: the straight walk between the two doors stays safe in every biome.

const CHAIN := ["marble_hall", "hellfire"]

const BIOMES := {
	"marble_hall": {
		"node": "MarbleHall",
		"ramp": ["2f323c", "6e7382", "a9aebb", "d5d9e2", "f0f2f6", "ffffff"],
		"accent": "e8c56a",
		"gamma": 0.85,
		"floor_band": Vector2(0.30, 1.00),
		"enemies": [
			{"type": "regular", "at": Vector2(64, 48)},
			{"type": "regular", "at": Vector2(480, 48)},
		],
	},
	"hellfire": {
		"node": "Hellfire",
		"ramp": ["120309", "3a0b12", "71160f", "b8300d", "f0761a", "ffd45e"],
		"accent": "ffd45e",
		"gamma": 2.1,
		"floor_band": Vector2(0.02, 0.42),
		# The escalation: the same two guards, plus the wraith between them. Its
		# sight is the widest in the game, so it sits on the far wall from the
		# spawn you arrive on.
		"enemies": [
			{"type": "regular", "at": Vector2(64, 48)},
			{"type": "regular", "at": Vector2(480, 48)},
			{"type": "wraith", "at": Vector2(272, 48)},
		],
	},
}


static func dir(level: String) -> String:
	return "res://game/levels/%s" % level


## The level one step further along the chain, or "" at the end of it.
static func next_of(level: String) -> String:
	var i := CHAIN.find(level)
	return CHAIN[i + 1] if i >= 0 and i + 1 < CHAIN.size() else ""


## The level one step back along the chain, or "" at the start of it.
static func previous_of(level: String) -> String:
	var i := CHAIN.find(level)
	return CHAIN[i - 1] if i > 0 else ""
