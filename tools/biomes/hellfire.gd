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
	#
	# Within those bands they stand in two MOBS rather than along two walls.
	# The floor where the masks come off is the wrong one to fight a body at a
	# time, so each side is built around a knot the player cannot enter without
	# waking four things at once - guards to trade with, a wraith draining while
	# they do, and on the west a warden taking their speed away in the middle of
	# it. This is the room the heavy exists for.
	"enemies": [
		# The west mob, knotted around (85, 100), with the warden anchoring it
		# and a drain holding the corner behind.
		{"type": "regular", "at": Vector2(44, 48)},
		{"type": "regular", "at": Vector2(130, 48)},
		{"type": "regular", "at": Vector2(100, 108)},
		{"type": "warden", "at": Vector2(64, 152)},
		{"type": "wraith", "at": Vector2(60, 220)},
		# The east mob, and the drain in the far corner that outlives it.
		{"type": "regular", "at": Vector2(410, 48)},
		{"type": "regular", "at": Vector2(496, 48)},
		{"type": "wraith", "at": Vector2(452, 96)},
		{"type": "regular", "at": Vector2(452, 160)},
		{"type": "wraith", "at": Vector2(440, 272)},
	],
	# THREE beats, which no floor below this gets, and the count is the point:
	# hellfire is the second-to-last ordinary room in the building and the one
	# that has to stop feeling like a room you clear. Each lands from the door
	# the one before it did not.
	#
	# The first comes in by the NORTH door - like the marble hall's, and here it
	# means something the marble hall's does not. This is the floor where the
	# reskins stop and the originals start, so a beat coming DOWN the stairs is
	# the building saying the thing above you is worse than the thing you just
	# cleared.
	#
	# The second brings back, from behind, the warden the west mob already
	# spent; the third comes down the north stairs again once the player is
	# nearly out. No beat carries two wardens: 36 HP is six hits spent standing
	# still, and two at once stops being pressure and starts being a room that
	# cannot be left.
	"reinforcements": [
		{"after_kills": 3, "from": "returned",
			"enemies": ["regular", "regular", "wraith"],
			"per_head": ["regular"]},
		{"after_kills": 7, "from": "start",
			"enemies": ["regular", "warden"],
			"per_head": ["regular"]},
		{"after_kills": 11, "from": "returned",
			"enemies": ["wraith", "regular"],
			"per_head": ["regular"]},
	],
}
