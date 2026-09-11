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
	# DESIGN.md's "SECURITY!", in by the south door - the only door on this
	# floor that opens. Cued by his health rather than by kills because
	# `after_kills` cannot reach any number but zero on a boss floor (see
	# reinforcements.gd's `_due`).
	#
	# QUARTERS, and the pair is chosen to be ANNOYING rather than dangerous,
	# which is a different job from a crowd floor's. What makes a boss fight
	# hard is reading one telegraph; these two attack the reading:
	#
	#   social_media  has NO wind-up to interrupt - its harm is proximity - so
	#                 it cannot be answered with the timing the boss is
	#                 teaching. It just bleeds you while you watch him.
	#   call_center   takes the DODGE away. Ahmed's fire wave is a sidestep and
	#                 nothing else; slowed, it stops being dodgeable.
	#
	# So the shape is drain, then the slow at the halfway point, then drain
	# again - the slower arriving as one distinct event rather than a state the
	# player lives in. ONE of him, ever, and he is in no `per_head` list: two
	# do not stack a slow, they refresh it, and permanent slow through a
	# telegraph is the one thing here that reads unfair instead of hard.
	"reinforcements": [
		{"at_boss_health": 72, "from": "start",
			"enemies": ["social_media", "office_boy"],
			"per_head": ["social_media"]},
		{"at_boss_health": 48, "from": "start",
			"enemies": ["call_center"],
			"per_head": ["office_boy"]},
		{"at_boss_health": 24, "from": "start",
			"enemies": ["social_media", "social_media"],
			"per_head": ["social_media"]},
	],
	# After Ahmed concedes, and not a moment before it - the cue skips a boss
	# who has given up, which is the one thing that lets a boss floor reach it
	# at all (he is in the `enemies` group and is never freed). He walks the
	# length of the arena you just won it in and stands west of centre, between
	# the two colonnade rows, well off the walk to the north door - which has
	# just unlocked and is the only reason anybody is still standing here.
	"relief": {"npc": "ivan", "from": "start", "at": Vector2(180, 160),
		"say": "res://game/npcs/ivan/after_ahmed_office.gd"},
}
