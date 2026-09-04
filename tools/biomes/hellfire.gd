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
}
