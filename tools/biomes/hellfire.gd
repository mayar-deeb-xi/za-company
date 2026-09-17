extends RefCounted
## Demo biome, still on the chain until the office floors replace it.
##
## Data only, read by tools/biomes.gd; the key reference lives there.
##
## ## THE UPSIDE-DOWN T
##
## The third floor in the building that is not the 34 x 19 room, and the third
## way of not being one: the call floor is a rectangle with a corner taken out,
## the marble hall is a rectangle stood on its end, and this is a wide room with
## a chute rising out of the middle of it. 30 x 36 with the two top corners cut
## away - a base 480 px across and a stem 320 px wide climbing 352 px to the way
## out.
##
## Three things fall out of that and each one is load-bearing:
##
## - **The stem holds guards and nothing else, and that is arithmetic.** The
##   walk is x 214-268 and a body clears it by its own sight, so inside the
##   stem's 288 px of floor there is room for an 80 px look (x 96-134 and
##   x 348-384) and no room at all for a 120 or a 130. The drains and the slow
##   are in the base by construction rather than by choice, which is the right
##   answer anyway: the climb should be something you fight THROUGH, not
##   somewhere you can be held.
## - **The base is where the room still is.** Both mobs are down there, one per
##   arm, with 448 px of width to knot in - and the walk passes between them,
##   so the floor is still entered by walking into the gap between two crowds.
##   The base was 640 px across and came back 25% to 480, which cost each arm
##   80 px: the crowds are the same crowds, standing closer to their own wall
##   and closer to the walk, and the room reads as a chute with shoulders
##   rather than a hall with a chimney.
## - **No carpet.** The shape says `"runner": "none"`, which is the third answer
##   plan.gd gives: a carpet is a thing somebody laid, and this is the floor
##   where the building stops pretending anybody works here. The default band
##   of middle rows would have laid one across the stem, which is the marble
##   hall's problem arriving on a room shaped the other way.
const BIOME := {
	"node": "Hellfire",
	"title": "HELLFIRE",
	# 30 x 36 with the top corners gone. The stem is cols 5-24 and the base is
	# the full width below row 22, so both doors sit at col 14 - in line with
	# each other, straight up the middle of the stem, which is also the middle
	# of the room.
	"shape": {
		"cols": 30, "rows": 36,
		"cut": [Rect2i(0, 0, 5, 22), Rect2i(25, 0, 5, 22)],
		"doors": {"out": 14, "back": 14},
		"runner": "none",
	},
	# One leg: the doors face each other and the stem is centred on them. It is
	# authored rather than defaulted only because the default band is written
	# for a door at col 16 and both of these are at col 14.
	"lane": [Rect2(214, 16, 54, 544)],
	"ramp": ["120309", "3a0b12", "71160f", "b8300d", "f0761a", "ffd45e"],
	"accent": "ffd45e",
	"gamma": 2.1,
	"floor_band": Vector2(0.02, 0.42),
	# Eighteen columns, and the shape sorts them out on its own: the cross
	# product puts four xs on every rank, and at the five stem rows the outer
	# two land in the masonry either side of the chute and are skipped. So the
	# stem gets two files flanking the walk and the base gets full ranks, out of
	# one rhythm and no special case. The narrower base is why there are four
	# rather than six: at 448 px of floor a fifth would have had to stand either
	# against a wall or on the walk.
	"columns": {"rows": [3, 7, 11, 15, 19, 25, 30], "xs": [2, 10, 19, 27]},
	# The one fire that is a hazard rather than a colour, in the base's west
	# arm. It has to be authored now: the default position is (120, 152), which
	# on this shape is inside the corner that was cut away.
	"hazard_at": Vector2(128, 392),
	# Hellfire has TWO doors now. It used to be the end of the chain, so these
	# enemies could line the far wall from the one spawn you ever arrived on
	# and nobody walked past them; sitting between asset recovery and the
	# executive floor, the walk from door to door goes straight up the middle
	# of the room, and every sight radius in here has to clear the lane the way
	# every office floor's does.
	#
	# That lane costs each type a different width, and on this floor it is
	# x 214-268 rather than the building's usual x 246-300: a guard's 80 px
	# means x < 134 or x > 348, a wraith's 120 means x < 94 or x > 388, and the
	# warden's 130 - the longest look in the game - means x < 84 or x > 398.
	# They are also kept off the colonnade's own x, which is asset recovery's
	# lesson: an enemy parked behind 48 px of column cannot be seen at all.
	#
	# Within those bands they stand in two MOBS rather than along two walls.
	# The floor where the masks come off is the wrong one to fight a body at a
	# time, so each side is built around a knot the player cannot enter without
	# waking four things at once - guards to trade with, a wraith draining while
	# they do, and on the west a warden taking their speed away in the middle of
	# it. This is the room the heavy exists for.
	#
	# **What the shape changed is that the mobs went DOWN into the base and two
	# guards went up the stem.** Both knots used to sit in the top half of a
	# rectangle; on this floor the top half is a 288 px chute where nothing with
	# a 120 px look can legally stand, so the crowds are in the two arms where
	# there is room to be a crowd, and the climb is lined instead of packed.
	"enemies": [
		# The west mob, in the base's west arm, knotted around (74, 466) - the
		# warden anchoring it and a drain holding the corner behind.
		{"type": "regular", "at": Vector2(44, 424)},
		{"type": "regular", "at": Vector2(120, 440)},
		{"type": "warden", "at": Vector2(72, 470)},
		{"type": "wraith", "at": Vector2(60, 528)},
		# The east mob, the same shape mirrored about (405, 470), and the drain
		# in the far corner that outlives it.
		{"type": "regular", "at": Vector2(364, 432)},
		{"type": "regular", "at": Vector2(448, 512)},
		{"type": "wraith", "at": Vector2(400, 416)},
		{"type": "wraith", "at": Vector2(412, 540)},
		# And the chute. Two guards, one against each wall of it, which is all
		# the stem can legally hold - so the climb costs the player something
		# without ever being a place they can be cornered in.
		{"type": "regular", "at": Vector2(116, 168)},
		{"type": "regular", "at": Vector2(364, 264)},
	],
	# The wreckage, and there is nothing in it that is not already somewhere
	# else in the building: this floor is the office floors after the masks come
	# off, so it is dressed out of their furniture rather than out of anything
	# of its own. Desks nobody sits at, towers nobody switched off, and the rest
	# of it in pieces.
	#
	# Everything is off the walk and off the colonnade's xs, and nothing stands
	# where a body does - a prop under an enemy is an enemy shoved out of
	# position on the first frame.
	"props": [
		# The stem, west of the walk: the climb is lined with what fell over on
		# the way out.
		{"type": "debris", "at": Vector2(136, 48)},
		{"type": "scrap_pile", "at": Vector2(192, 96)},
		{"type": "dead_plant", "at": Vector2(128, 112)},
		{"type": "crt_stack", "at": Vector2(192, 176)},
		{"type": "debris", "at": Vector2(136, 232)},
		{"type": "server_rack", "at": Vector2(120, 296)},
		{"type": "cable_spool", "at": Vector2(192, 320)},
		# And east of it.
		{"type": "crt_stack", "at": Vector2(344, 48)},
		{"type": "debris", "at": Vector2(288, 64)},
		{"type": "pc_tower", "at": Vector2(344, 104)},
		{"type": "scrap_pile", "at": Vector2(360, 160)},
		{"type": "debris", "at": Vector2(288, 208)},
		{"type": "dead_plant", "at": Vector2(288, 288)},
		{"type": "toolbox", "at": Vector2(348, 320)},
		# The base's west arm, around the mob.
		{"type": "debris", "at": Vector2(32, 392)},
		{"type": "desk", "at": Vector2(100, 392)},
		{"type": "chair", "at": Vector2(100, 404)},
		{"type": "scrap_pile", "at": Vector2(196, 400)},
		{"type": "debris", "at": Vector2(192, 448)},
		{"type": "dead_plant", "at": Vector2(104, 480)},
		{"type": "table", "at": Vector2(196, 496)},
		{"type": "server_rack", "at": Vector2(188, 536)},
		{"type": "crt_stack", "at": Vector2(144, 544)},
		{"type": "debris", "at": Vector2(104, 552)},
		# And its east arm.
		{"type": "desk", "at": Vector2(352, 392)},
		{"type": "chair", "at": Vector2(352, 404)},
		{"type": "cable_spool", "at": Vector2(388, 392)},
		{"type": "dead_plant", "at": Vector2(412, 384)},
		{"type": "scrap_pile", "at": Vector2(288, 480)},
		{"type": "debris", "at": Vector2(448, 440)},
		{"type": "toolbox", "at": Vector2(288, 552)},
		{"type": "crt_stack", "at": Vector2(352, 552)},
		{"type": "table", "at": Vector2(440, 552)},
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
	# cleared. On this shape it also means they come down the CHUTE, into the
	# one part of the floor nothing can be placed in.
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
