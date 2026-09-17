extends RefCounted
## Demo biome, still on the chain until the office floors replace it.
##
## Data only, read by tools/biomes.gd; the key reference lives there.
##
## ## THE NAVE
##
## It is the second floor in the building that is not the 34 x 19 room, and it
## is shaped the other way from the call floor: 26 x 40, half again as long as
## any other floor and two thirds as wide. The doors face each other down its
## length, so the walk is one straight leg 608 px long and the whole floor is
## the thing either side of it.
##
## Three things fall out of that and each one is load-bearing:
##
## - **The colonnade is what makes it a hall rather than a corridor.** Nine
##   ranks of two, every four tiles from y 80 to 592, at x 136 and x 280 - which
##   is 46 px off the walk on one side and 44 on the other. That is close enough
##   to read as flanking the route, and far enough that a pillar never stands ON
##   it. Everything else on this floor is placed in the aisles the colonnade
##   makes.
## - **A body stands OUTSIDE the colonnade, and that is arithmetic rather than
##   taste.** The walk is x 182-236 and a guard clears it by its own 80 px of
##   sight, which leaves x <= 102 and x >= 316 - the outer half of each aisle,
##   against the wall. The pillars at 136 and 280 are 34 px past the nearest
##   legal spot, so no body on this floor can ever be parked behind one: the
##   occlusion rule that costs the call floor eighteen checks costs this one
##   nothing at all.
## - **The carpet had to learn which way the room runs.** `floor_tile` laid its
##   alt band across the middle ROWS, which on a hall 40 rows deep is a rug
##   across a corridor. The shape says `"runner": "cols"` and gets the band
##   between its own two doors instead - see tools/plan.gd. Nothing changed for
##   the ten floors that are walked across rather than down.
const BIOME := {
	"node": "MarbleHall",
	"title": "THE MARBLE HALL",
	# 26 x 40 against every other rectangular floor's 34 x 19: 416 x 640 px and
	# 912 floor tiles, which is 1.7 rooms. Both doors are at col 12, in line
	# with each other down the length - the opposite of the call floor, where
	# the shape exists to put them out of line.
	"shape": {
		"cols": 26, "rows": 40,
		"doors": {"out": 12, "back": 12},
		"runner": "cols",
	},
	# One leg, because both doors are in the same column. It is authored rather
	# than defaulted only because the default band is written for a door at
	# col 16 and this one is at col 12.
	"lane": [Rect2(182, 16, 54, 608)],
	"ramp": ["2f323c", "6e7382", "a9aebb", "d5d9e2", "f0f2f6", "ffffff"],
	"accent": "e8c56a",
	"gamma": 0.85,
	"floor_band": Vector2(0.30, 1.00),
	# Eighteen columns in nine ranks, flanking the walk the whole way up. The
	# xs are the two that matter: 136 and 280 sit just off the lane, so the
	# colonnade divides the room into a processional way and two aisles rather
	# than standing about in the middle of it.
	"columns": {"rows": [4, 8, 12, 16, 20, 24, 28, 32, 36], "xs": [8, 17]},
	# Demo biome, and now the one with no hazard either: the torch went with
	# the lobby's polisher, and the floors that still have one are the two
	# office floors and hellfire.
	"hazard": "none",
	# The dressing, and the shape decided all of it.
	#
	# **Everything hung is on the north wall, because it is the only wall this
	# room turns a FACE to.** A sign is drawn downwards from just under a wall
	# row, and a hall this shape has 384 px of north wall and two side walls
	# seen edge-on - so the gallery's pictures all live at the head of it, and
	# the aisles get what stands on a floor. Nothing stands within 90 px of that
	# wall either: a portrait hangs 50 px into the room and a cabinet's art
	# rises 44 px off its foot, so the two would overlap in the one place the
	# player is looking when they arrive.
	#
	# The rest is paired down the aisles on the colonnade's own rhythm, and
	# every piece is OUTSIDE the walk and INSIDE the strip a body cannot stand
	# in, or in a bay the bodies are not in. Furniture a body is standing on is
	# a body that gets pushed out of position on the first frame.
	"props": [
		# The head of the hall. Two portraits, the company motto and a banner,
		# spread either side of the way out. A sign pins its TOP-LEFT rather
		# than its foot, so these are measured rightwards from the x given -
		# the banner at 232 put its own left edge four pixels inside the walk.
		{"type": "motto", "at": Vector2(24, 18)},
		{"type": "portrait", "at": Vector2(116, 18)},
		{"type": "banner", "at": Vector2(240, 18)},
		{"type": "portrait", "at": Vector2(316, 18)},
		# And the carpet under them. It blocks nothing and pins its top-left, so
		# it lies across the walk the way the executive floor's does - what is
		# forbidden on a walk is something to collide with, not something to
		# stand on.
		{"type": "rug", "at": Vector2(100, 80)},
		# The west aisle, north to south. The gap at y 456-520 is the south
		# gang's ground.
		{"type": "plant", "at": Vector2(40, 136)},
		{"type": "sofa", "at": Vector2(52, 200)},
		{"type": "plant", "at": Vector2(40, 264)},
		{"type": "awards_cabinet", "at": Vector2(44, 328)},
		{"type": "dead_plant", "at": Vector2(40, 392)},
		{"type": "table", "at": Vector2(116, 456)},
		{"type": "bar_cart", "at": Vector2(44, 552)},
		{"type": "plant", "at": Vector2(60, 608)},
		# The east aisle, north to south. The gap at y 184-268 is the north
		# gang's, and the two at x 300 stand in the strip between the colonnade
		# and the nearest legal body - 26 px nothing else can use.
		{"type": "plant", "at": Vector2(376, 136)},
		{"type": "coffee", "at": Vector2(300, 216)},
		{"type": "plant", "at": Vector2(376, 328)},
		{"type": "sofa", "at": Vector2(364, 392)},
		{"type": "dead_plant", "at": Vector2(376, 456)},
		{"type": "awards_cabinet", "at": Vector2(372, 520)},
		{"type": "table", "at": Vector2(300, 552)},
		{"type": "plant", "at": Vector2(356, 608)},
	],
	# TWO GANGS, not four corners. The old arrangement stood one guard in each
	# corner, which reads as an arrangement and plays as four separate duels:
	# no spot on this floor was inside two sight radii at once, so the player
	# fought 24 HP, walked, fought 24 HP, and never once had to choose which
	# one to answer. Four knots of one is not a crowd, it is a queue.
	#
	# So they pair off into two gangs of four, each standing close enough that
	# their 80 px looks overlap - anywhere in the middle of either knot wakes
	# all four. The room still has a safe middle and the straight walk between
	# the doors is still clear; what it no longer has is a way to take them one
	# at a time by default.
	#
	# **What the nave changed is that the two gangs are no longer side by side.**
	# A hall 608 px long with both gangs at the same depth is a room with a
	# populated middle and two empty ends; stacked, it is fought in two acts on
	# the way up, each in its own aisle, with the colonnade between them and the
	# ends held by the two beats. The south one is met first and stays the plain
	# one; the north one keeps the anchor.
	#
	# `office_boy`, not `regular`: the reskin IS the guard - 24 HP, the same
	# cycle, the same numbers - so this is a change of costume and nothing else.
	# The reskins are the company's staff and hold floors 1-9, and the originals
	# appear only from hellfire up, where the building stops pretending to be an
	# office.
	"enemies": [
		# The south gang, in the west aisle, knotted around (66, 478) - the
		# first thing standing between the player and the length of the hall.
		{"type": "office_boy", "at": Vector2(44, 432)},
		{"type": "office_boy", "at": Vector2(92, 460)},
		{"type": "office_boy", "at": Vector2(40, 500)},
		{"type": "office_boy", "at": Vector2(88, 520)},
		# The north gang, in the east aisle and half a hall further on, knotted
		# around (374, 230) - so the two are fought one after the other and
		# from opposite sides of the colonnade.
		{"type": "office_boy", "at": Vector2(356, 184)},
		{"type": "office_boy", "at": Vector2(392, 216)},
		{"type": "office_boy", "at": Vector2(352, 252)},
		{"type": "office_boy", "at": Vector2(396, 268)},
		# And one `security` standing in the hole the north gang is knotted
		# around - the FOURTH archetype's first appearance in the game.
		#
		# The two gangs were the fix for a floor that played as a queue of
		# duels, and they worked; what they could not fix is that both gangs are
		# the same gang. Twelve `office_boy` and nothing else was the most
		# repeated single enemy on any floor in the building, so the first knot
		# stays exactly as it is and the second one gets an anchor: the player
		# meets a plain crowd, learns it, and then meets the same crowd with
		# something in it that the answer to a crowd does not work on.
		#
		# It goes in the NORTH knot rather than the south because the south is
		# met first and should stay the plain one, and it goes in the MIDDLE of
		# it because a slam is an area - out on the edge it is a big man swinging
		# at nobody, and at the centre its ring overlaps the ground all four
		# boys are standing on, which is the whole argument for mixing kinds of
		# threat rather than adding more of one.
		#
		# (372, 224) is legal on the one placement rule that binds here: his
		# sight is 90, the walk is x 182-236, and 372 - 236 = 136, clear of the
		# lane's east edge by 46 px more than he needs. The straight walk
		# between the doors is still safe, which is what the flow suite checks.
		{"type": "security", "at": Vector2(372, 224)},
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
	#
	# On a hall this long they also do the work a third gang would have done
	# badly: the two placed knots sit in the middle two thirds of it, and the
	# beats are what put bodies at the ends - one at the head of the hall the
	# player is walking towards, one behind them at the door they came in by.
	"reinforcements": [
		{"after_kills": 3, "from": "returned",
			"enemies": ["office_boy", "office_boy"],
			"per_head": ["office_boy"]},
		{"after_kills": 6, "from": "start",
			"enemies": ["office_boy", "office_boy"],
			"per_head": ["office_boy"]},
	],
}
