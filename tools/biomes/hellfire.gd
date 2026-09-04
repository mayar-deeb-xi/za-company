extends RefCounted
## Demo biome, still on the chain until the office floors replace it.
##
## Data only, read by tools/biomes.gd; the key reference lives there.

const BIOME := {
	"node": "Hellfire",
	"title": "HELLFIRE",
	"ramp": ["120309", "3a0b12", "71160f", "b8300d", "f0761a", "ffd45e"],
	"accent": "ffd45e",
	"gamma": 2.1,
	"floor_band": Vector2(0.02, 0.42),
	# Hellfire has TWO doors now. It used to be the end of the chain, so these
	# enemies could line the far wall from the one spawn you ever arrived on
	# and nobody walked past them; sitting between asset recovery and the
	# executive floor, the walk from door to door goes straight up the middle
	# of the room, and every sight radius in here has to clear the lane at
	# x 246-300 the way every office floor's does.
	#
	# That lane costs each type a different width: a guard's 80 px means
	# x < 166 or x > 380, a wraith's 120 means x < 126 or x > 420, and the
	# warden's 130 - the longest look in the game - means x < 116 or x > 430.
	# They are also kept off the colonnade's own x (64-80, 144-160, 384-400,
	# 464-480 at the row they stand in), which is asset recovery's lesson: an
	# enemy parked behind 48 px of column cannot be seen at all.
	"enemies": [
		{"type": "regular", "at": Vector2(44, 48)},
		{"type": "regular", "at": Vector2(130, 48)},
		{"type": "regular", "at": Vector2(410, 48)},
		{"type": "regular", "at": Vector2(496, 48)},
		{"type": "wraith", "at": Vector2(452, 96)},
		{"type": "wraith", "at": Vector2(440, 272)},
		{"type": "warden", "at": Vector2(64, 152)},
	],
}
