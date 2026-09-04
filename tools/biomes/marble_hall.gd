extends RefCounted
## Demo biome, still on the chain until the office floors replace it.
##
## Data only, read by tools/biomes.gd; the key reference lives there.

const BIOME := {
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
}
