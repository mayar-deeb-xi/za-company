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

const CHAIN := ["lobby", "marble_hall", "hellfire"]

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
		# Deliberately empty. The design gives floor 1 two office boys, but that
		# type does not exist yet (build order step 2, with the other reskins);
		# placing `regular` here would dress the lobby with dungeon guards and then
		# need undoing. An empty room is the honest intermediate state.
		"enemies": [],
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


## The level one step further along the chain, or "" at the end of it.
static func next_of(level: String) -> String:
	var i := CHAIN.find(level)
	return CHAIN[i + 1] if i >= 0 and i + 1 < CHAIN.size() else ""


## The level one step back along the chain, or "" at the start of it.
static func previous_of(level: String) -> String:
	var i := CHAIN.find(level)
	return CHAIN[i - 1] if i > 0 else ""
