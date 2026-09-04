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
	# Empty for now. Ahmed is build order step 6 and does not exist yet, and
	# the design gives this floor no adds at rest - so there is nothing to put
	# in it that would not be a dungeon guard standing in a corner office.
	"enemies": [],
}
