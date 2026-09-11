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
	# TWO GANGS, not four corners. The old arrangement stood one guard in each
	# corner, which reads as an arrangement and plays as four separate duels:
	# no spot on this floor was inside two sight radii at once, so the player
	# fought 24 HP, walked, fought 24 HP, and never once had to choose which
	# one to answer. Four knots of one is not a crowd, it is a queue.
	#
	# So they pair off into a west gang and an east gang of four, each standing
	# close enough that their 80 px looks overlap - anywhere in the middle of
	# either knot wakes all four. The room still has a safe middle and the
	# straight walk between the doors is still clear; what it no longer has is
	# a way to take them one at a time by default.
	#
	# `office_boy`, not `regular`: the reskin IS the guard - 24 HP, the same
	# cycle, the same numbers - so this is a change of costume and nothing else.
	# The reskins are the company's staff and hold floors 1-9, and the originals
	# appear only from hellfire up, where the building stops pretending to be an
	# office.
	"enemies": [
		# The west gang, knotted around (95, 100).
		{"type": "office_boy", "at": Vector2(56, 64)},
		{"type": "office_boy", "at": Vector2(128, 72)},
		{"type": "office_boy", "at": Vector2(64, 132)},
		{"type": "office_boy", "at": Vector2(132, 136)},
		# The east gang, the same shape mirrored about (440, 200).
		{"type": "office_boy", "at": Vector2(404, 160)},
		{"type": "office_boy", "at": Vector2(472, 168)},
		{"type": "office_boy", "at": Vector2(408, 236)},
		{"type": "office_boy", "at": Vector2(476, 240)},
		# And one `security` standing in the hole the east gang was already
		# mirrored about - the FOURTH archetype's first appearance in the game.
		#
		# The two gangs were the fix for a floor that played as a queue of
		# duels, and they worked; what they could not fix is that both gangs are
		# the same gang. Twelve `office_boy` and nothing else was the most
		# repeated single enemy on any floor in the building, so the west knot
		# stays exactly as it is and the east one gets an anchor: the player
		# meets a plain crowd, learns it, and then meets the same crowd with
		# something in it that the answer to a crowd does not work on.
		#
		# It goes in the EAST knot rather than the west because the west is met
		# first and should stay the plain one, and it goes in the MIDDLE of it
		# because a slam is an area - out on the edge it is a big man swinging
		# at nobody, and at the centre its ring overlaps the ground all four
		# boys are standing on, which is the whole argument for mixing kinds of
		# threat rather than adding more of one.
		#
		# (440, 200) is legal on the one placement rule that binds here: his
		# sight is 90, the door lane is x 246-300, and 440 - 90 = 350, clear of
		# the lane's east edge by 50 px. The straight walk between the doors is
		# still safe, which is what the flow suite checks.
		{"type": "security", "at": Vector2(440, 200)},
	],
	# Two beats rather than one, and they arrive from opposite doors. The first
	# is the old one: in by the NORTH door, the way OUT, so half the room is
	# dead, the stairs are in sight, and two more come down them - the floor
	# answered from the direction the player has stopped watching.
	#
	# The second comes by the SOUTH door, the way IN, once the second gang is
	# broken. A floor with one beat has one surprise in it and the player walks
	# the rest of the room; two from two doors means it is not over until the
	# room says so.
	"reinforcements": [
		{"after_kills": 3, "from": "returned",
			"enemies": ["office_boy", "office_boy"],
			"per_head": ["office_boy"]},
		{"after_kills": 6, "from": "start",
			"enemies": ["office_boy", "office_boy"],
			"per_head": ["office_boy"]},
	],
}
