extends RefCounted
## Floor 1 of THE NEW HIRE. One floor, one file: open the floor you are
## designing and everything about it - palette, furniture, enemies, and the
## lanes that must stay clear - is on one screen.
##
## Data only, read by tools/biomes.gd; the key reference lives there.

const BIOME := {
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
	# No hazard at all. Floor 1 is where a new player learns to walk, and a
	# tutorial room must not have a way to lose health by walking into the
	# scenery - the sparking floor polisher was that, and it is gone. The
	# polisher art stays in hazard.gd for a floor that wants it.
	"hazard": "none",
	# The one floor in the game that puts a heart on the floor. Floor 1 is where
	# a player finds out what a heal is; everywhere above it, healing is Ivan.
	"heart": true,
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
}
