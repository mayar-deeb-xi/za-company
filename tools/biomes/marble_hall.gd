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
	# Demo biome, and now the one with no hazard either: the torch went with
	# the lobby's polisher, and the floors that still have one are the two
	# office floors and hellfire.
	"hazard": "none",
	# Four guards, one to a corner rather than a line across the top, so they
	# can be picked off one at a time instead of arriving as a wall.
	#
	# `office_boy`, not `regular`, and the same four positions: the reskin IS
	# the guard - 24 HP, the same cycle, the same numbers - so this is a change
	# of costume and nothing else. It is the rule the whole building follows,
	# and this floor was the last one breaking it: the reskins are the company's
	# staff and hold floors 1-9, and the originals appear only from hellfire up,
	# where the building stops pretending to be an office.
	"enemies": [
		{"type": "office_boy", "at": Vector2(64, 48)},
		{"type": "office_boy", "at": Vector2(480, 48)},
		{"type": "office_boy", "at": Vector2(150, 264)},
		{"type": "office_boy", "at": Vector2(400, 264)},
	],
	# In by the NORTH door, which is the one thing this beat does that the
	# others do not: it arrives from the way OUT. Half the room is dead, the
	# stairs are in sight, and two more come down them - so the floor's own
	# lesson (they arrive one at a time, not as a wall) is restated from the
	# direction the player has stopped watching.
	"reinforcements": [
		{"after_kills": 2, "from": "returned",
			"enemies": ["office_boy", "office_boy"],
			"per_head": ["office_boy"]},
	],
}
