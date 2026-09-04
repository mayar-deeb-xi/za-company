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
	# Empty: this floor's people are being placed by hand. What the design
	# wants is 2 call_center at the chokepoints the dividers make and 3 office
	# boys between them - and see the note on `columns` before choosing any
	# position, because eighteen dividers is eighteen ways to hide one.
	"enemies": [],
}
