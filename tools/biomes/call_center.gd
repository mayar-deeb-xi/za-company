extends RefCounted
## The call floor - DESIGN.md's denial level, and the densest room in the game.
##
## Data only, read by tools/biomes.gd; the key reference lives there.

const BIOME := {
	"node": "CallCenter",
	"title": "THE CALL CENTER",
	# Fluorescent green-grey: the colour a room gets painted when nobody who
	# works in it was asked. No other floor is green, which is the point - it
	# lands between the content studio's near-black and Ahmed's dark marble, so
	# walking in here is walking into the lights being ON.
	"ramp": ["10130f", "222a20", "3e4a3c", "687563", "97a48f", "cdd7c4"],
	# Cold cyan, and it is the "on hold" colour: DESIGN.md gives the call_center
	# enemy a charge ring that reads as a spreading on-hold circle, so the floor
	# is lit in the colour of being asked to wait.
	"accent": "3fc9e8",
	# Below 1.0 lifts the mid-tones, the same as the lobby: this room is
	# over-lit rather than under-lit, and flatly, by tubes nobody turns off.
	"gamma": 0.88,
	"floor_band": Vector2(0.30, 0.82),
	# Barely any: worn carpet tile, not carpet.
	"runner": 0.10,
	# DESIGN.md's "densest columns" - eighteen dividers in three rows, half
	# again as many as asset recovery's full colonnade, which is what makes this a
	# maze rather than an open plan. The xs are the generator's own, and they
	# are what keeps the room legal: the nearest divider to the door line sits
	# at x 232 and the next at 312, so the straight walk between the doors
	# stays clear even at this density.
	#
	# Two things follow from three rows, and the second one bites when this
	# floor gets its people. A divider's panel is waist height with the room
	# carrying on above it, so it hides less than its 48 px of art suggests -
	# but an enemy parked ON a divider's x and above its foot is invisible, and
	# on this floor there are eighteen chances to make that mistake instead of
	# six. The divider xs are 72 / 152 / 232 / 312 / 392 / 472; keep every
	# enemy off them.
	"column": "divider",
	"columns": {"rows": [4, 9, 14], "xs": [4, 9, 14, 19, 24, 29]},
	# DESIGN.md's hazard: the photocopier, jammed, lid up, fuser still going.
	# Not the `printer` in the catalogue - that one is a machine nobody can
	# use, this is a machine nobody should touch.
	"hazard": "copier",
	# THE WIRING, and it is what makes this floor move. Four runs of cable
	# trunking down the aisles, each one dull until it flares end to end and
	# then puts something very fast down its length. Something in the room is
	# going off roughly every six tenths of a second, and two of the four are
	# usually in flight at once.
	#
	# It is on this floor rather than any other because of what it asks. The
	# studio's dolly is one slow rig and what it wants is patience; this is the
	# DENIAL floor, where two slowers take your movement away, and the honest
	# threat for a room like that is one that punishes being slow rather than
	# one that rewards waiting. A surge is a tax on crossing at the wrong
	# moment - the head passes a standing player in a tenth of a second, well
	# inside one grace window, so a run costs exactly one blow however it
	# catches you and can never be a lane you are trapped in. That is what
	# makes four of them fair, and why 8 sits under the copier's 10: the copier
	# is one place you chose to stand in, these are four lanes you have to
	# cross.
	#
	# Three things about the geometry, and the first is the rule:
	#
	# - **Every run stops clear of the door lane.** x 246-300 stays walkable top
	#   to bottom on every floor, so the aisles are cut in two at the lane
	#   rather than run across it: the west halves end at 232 and the east
	#   halves start at 312. Splitting them is not a compromise - it DOUBLED
	#   the number of runs, which is most of what makes the room feel busy.
	# - **y 128 and y 224 are the aisles**, between the divider rows whose feet
	#   are at 80 / 160 / 240. The northern pair sits on the top edge of the
	#   central band rather than through it, so the 48 px of band the routing
	#   fight needs is still there - it now has a metronome along one side.
	#   Both clear Ivan at (208, 168) and Dominique at (340, 144), which matters
	#   more than it looks: a conversation takes the player's hands, and being
	#   zapped while somebody is talking to you is the one version of this that
	#   would read as the game cheating.
	# - **`after` is the only per-run number that is not geometry**, and the
	#   four are spread across the cycle so no two neighbours fire in sequence -
	#   the sparks appear to jump around the room rather than sweep it. Two of
	#   the four run east-to-west for the same reason.
	"surge": {
		"speed": 260.0, "period": 2.4, "charge": 0.5, "damage": 8,
		"runs": [
			{"from": Vector2(24, 128), "to": Vector2(232, 128), "after": 0.0},
			{"from": Vector2(520, 224), "to": Vector2(312, 224), "after": 0.6},
			{"from": Vector2(312, 128), "to": Vector2(520, 128), "after": 1.2},
			{"from": Vector2(232, 224), "to": Vector2(24, 224), "after": 1.8},
		],
	},
	# The stations. Three ranks of them in the pockets the dividers leave, at
	# x 112 / 192 / 352 / 432 with the two outer walls taking one each, so the
	# room reads as a grid of identical seats - which is the whole of what a
	# call floor looks like and the whole of the joke.
	#
	# The middle rank is deliberately the thin one. This floor's lesson is that
	# a slow near guards is lethal, and being slowed is only a lesson in a room
	# you were trying to cross: the band at y 128-176 keeps the floor a routing
	# fight needs, with the jammed copier standing in it at (120, 152).
	"props": [
		{"type": "call_desk", "at": Vector2(112, 104)},
		{"type": "chair", "at": Vector2(112, 118)},
		{"type": "call_desk", "at": Vector2(192, 104)},
		{"type": "chair", "at": Vector2(192, 118)},
		{"type": "call_desk", "at": Vector2(352, 104)},
		{"type": "chair", "at": Vector2(352, 118)},
		{"type": "call_desk", "at": Vector2(432, 104)},
		{"type": "chair", "at": Vector2(432, 118)},
		{"type": "call_desk", "at": Vector2(40, 184)},
		{"type": "chair", "at": Vector2(40, 198)},
		{"type": "call_desk", "at": Vector2(504, 184)},
		{"type": "chair", "at": Vector2(504, 198)},
		{"type": "call_desk", "at": Vector2(112, 264)},
		{"type": "chair", "at": Vector2(112, 278)},
		{"type": "call_desk", "at": Vector2(192, 264)},
		{"type": "chair", "at": Vector2(192, 278)},
		{"type": "call_desk", "at": Vector2(352, 264)},
		{"type": "chair", "at": Vector2(352, 278)},
		{"type": "call_desk", "at": Vector2(432, 264)},
		{"type": "chair", "at": Vector2(432, 278)},
		# The board, in the stretch of north wall between the first two
		# dividers, where the whole floor can see it all day.
		{"type": "wallboard", "at": Vector2(92, 18)},
		# And the other thing this company communicates by: a sheet of A4.
		{"type": "notice", "at": Vector2(176, 20)},
		{"type": "printer", "at": Vector2(492, 104)},
		{"type": "cooler", "at": Vector2(40, 60)},
		{"type": "dead_plant", "at": Vector2(500, 60)},
		{"type": "table", "at": Vector2(40, 264)},
		{"type": "sofa", "at": Vector2(496, 264)},
		{"type": "cable_spool", "at": Vector2(352, 224)},
		{"type": "debris", "at": Vector2(208, 140)},
		{"type": "debris", "at": Vector2(368, 216)},
		{"type": "debris", "at": Vector2(96, 224)},
		{"type": "debris", "at": Vector2(448, 148)},
		{"type": "debris", "at": Vector2(192, 224)},
	],
	# Two slowers in the pockets the dividers make, and seven boys knotted around
	# them. Every one of the nine is either off the divider xs (72 / 152 / 232 /
	# 312 / 392 / 472) or SOUTH of a divider's foot, where Y-sorting draws it in
	# front of the panel rather than behind it - which is the mistake this floor
	# offers eighteen chances to make.
	#
	# This is the floor where being slowed near a guard is the lesson, so the
	# pair is the point and must not be trimmed: DESIGN.md's escape hatch for
	# this room's weight is one office boy, never a call_center.
	#
	# What changed is the SPACING, not the pair. The five used to stand far
	# enough apart that a slow could be walked off before the next body was
	# reached, which is the lesson cancelling itself out. Now each slower sits
	# inside a knot of boys, so the floor's whole sentence - slowed, and then
	# swung at - happens without the player getting to pick the order. They also
	# keep off the surge lanes at y 128 and y 224: a hazard that clears the room
	# for you is a hazard doing the player's job.
	"enemies": [
		# The west knot, around (100, 170).
		{"type": "call_center", "at": Vector2(96, 192)},
		{"type": "office_boy", "at": Vector2(96, 136)},
		{"type": "office_boy", "at": Vector2(152, 200)},    # south of the foot
		{"type": "office_boy", "at": Vector2(56, 168)},
		{"type": "office_boy", "at": Vector2(124, 150)},
		# The east knot, around (445, 170).
		{"type": "call_center", "at": Vector2(456, 168)},
		{"type": "office_boy", "at": Vector2(424, 216)},
		{"type": "office_boy", "at": Vector2(440, 120)},
		{"type": "office_boy", "at": Vector2(400, 180)},
	],
	# Boys only, and still no third slower: this room already holds two, and a
	# third arriving would stop being pressure and start being a room the player
	# cannot move in. What a beat adds is bodies to be slowed AMONG.
	#
	# Two of them now, from opposite doors. The first lands while the west knot
	# is being answered; the second comes down the north stairs once the player
	# has crossed to the east one, which is the trick the room's own geometry
	# already plays - there is always a knot behind you.
	"reinforcements": [
		{"after_kills": 3, "from": "start",
			"enemies": ["office_boy", "office_boy"],
			"per_head": ["office_boy"]},
		{"after_kills": 7, "from": "returned",
			"enemies": ["office_boy", "office_boy"],
			"per_head": ["office_boy"]},
	],
	# THE FIRST TIME ANYBODY IN THIS BUILDING IS KIND TO YOU. Floor 3 is where a
	# slow near two guards stops being a lesson and starts being a death, and it
	# is the last floor before Ahmed - so it is where the game has to admit that
	# healing exists at all, the lobby's free heart being two floors behind.
	# He comes in by the south door and stands east of the copier, in the gap
	# between the middle desks: clear of the hazard at (120, 152), clear of the
	# door line, and on the side of the room the fight tends to end on.
	"relief": {"npc": "ivan", "from": "start", "at": Vector2(208, 168),
		"say": "res://game/npcs/ivan/after_call_center.gd"},
	# The FOURTH beat, and this is the first floor to carry one: Dominique comes
	# DOWN the north stairs - the ones the player is about to go up - to say what
	# is waiting at the top. `from: "returned"` is the whole reason she is
	# legible here: Ivan arrives on the same cue through the south door, and two
	# people walking in at one threshold is two bodies shoving each other across
	# the same sixteen pixels. Opposite doors also say the two things they are
	# for - he has come from where you have been, she from where you are going.
	#
	# She stands east of the third divider rank, off the divider xs
	# (72 / 152 / 232 / 312 / 392 / 472) and off the door line on the enemies'
	# exact terms, in the pocket between the desk at (352, 104) and the one at
	# (352, 264) - which is on the way to the north door rather than beside it,
	# so walking past her is a decision rather than an accident.
	"briefing": {"npc": "dominique", "from": "returned", "at": Vector2(340, 144),
		"say": "res://game/npcs/dominique/before_ahmed.gd"},
}
