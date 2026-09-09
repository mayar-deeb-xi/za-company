extends RefCounted
## Floor 4 of THE NEW HIRE - Ahmed's corner office, and the first boss room.
##
## Data only, read by tools/biomes.gd; the key reference lives there.

const BIOME := {
	"node": "AhmedOffice",
	"title": "AHMED'S CORNER OFFICE",
	# The marble hall's room, taken down out of the white. Same stone, same
	# classical colonnade - this floor is where the building stops pretending
	# to be an office and starts being somebody's idea of a palace - but every
	# stop on the ramp is pulled down, so it reads as the same marble under
	# half the lighting. A corner office with the blinds shut.
	"ramp": ["16181f", "343843", "5f6472", "8d939f", "b7bcc7", "dfe3ea"],
	# The hall's gold, gone brassier. Still the only warm thing in the room.
	"accent": "d4a94f",
	# Up from the hall's 0.85: above 1.0 pushes the mid-tones down instead of
	# lifting them, which is most of what takes the shine off the stone.
	"gamma": 1.05,
	# The hall's floor runs to 1.00 - the ramp's pure white - and that is the
	# single number that makes it a bright room. Stopping at 0.70 is what the
	# floor being darker actually means.
	"floor_band": Vector2(0.22, 0.70),
	# Nothing in here hurts you but Ahmed. A boss room with a torch in it hands
	# the player a second thing to read during the one fight the floor is for,
	# and the fight is the whole point of the room.
	"hazard": "none",
	# NO ADDS AT REST, and the empty list is the load-bearing half of this
	# floor's population - the beat below is the other half. Ahmed is the
	# fight: he stands north of centre between the two colonnade rows, and his
	# sight (110 px) reaches the south spawn where the player arrives -
	# deliberately. This is an arena, not a corridor: the walk to the north
	# door goes through him, and the door is shut until he concedes.
	#
	# Anything placed here would be standing in that arena from the first
	# frame, which is the one thing a boss floor cannot afford - one fight is
	# enough to read at a time. So this floor's bodies arrive at thresholds
	# instead, where they are a phase of his fight rather than furniture in it.
	"enemies": [],
	"boss": {"type": "ahmed", "at": Vector2(272, 140)},
	# DESIGN.md's "SECURITY!" - one office boy at each third of his 96 HP, in
	# by the south door, which on this floor is the only door that opens. Cued
	# by his health rather than by kills because `after_kills` cannot reach any
	# number but zero on a boss floor (see reinforcements.gd's `_due`).
	#
	# One at a time and never two: the pair would be a crowd fight happening
	# during a duel, and the floor after next is where crowds are taught.
	"reinforcements": [
		{"at_boss_health": 64, "from": "start", "enemies": ["office_boy"]},
		{"at_boss_health": 32, "from": "start", "enemies": ["office_boy"]},
	],
}
