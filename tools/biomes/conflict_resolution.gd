extends RefCounted
## The company gym, and the second boss room - DESIGN.md's Conflict Resolution.
##
## Data only, read by tools/biomes.gd; the key reference lives there.

const BIOME := {
	"node": "ConflictResolution",
	"title": "CONFLICT RESOLUTION",
	# The only room in the game with no colour in it at all. Every other floor
	# has a cast - the lobby blue, the bullpen brown, the call floor green -
	# and this one is plain concrete and rubber, so the single warm thing in it
	# is the paint on the floor. That is the whole look: grey room, red ring.
	"ramp": ["121212", "272727", "474747", "757575", "a5a5a5", "dcdcdc"],
	# Boxing red: gloves, ring paint, and the only accent in the game that is
	# not a company colour but a sport's.
	"accent": "e0503c",
	# Flat. A gym is lit evenly and badly and has no mood to speak of.
	"gamma": 1.00,
	# Dark rubber matting, kept off the ramp's bottom so the cast still reads
	# on it - the same check the content studio needed.
	"floor_band": Vector2(0.26, 0.66),
	# No runner. The ring painted across the middle of this floor is the floor
	# decoration, and a carpet band under it would be a second one competing.
	#
	# NO COLONNADE either, which DESIGN.md asks for outright: a tight arena
	# with nothing in it to hide behind. An empty `columns` layout is how a
	# biome says that, and this floor is the first to say it - so it also has
	# no column scene in its folder at all.
	"columns": {"rows": [], "xs": []},
	# And no hazard, for the same reason Ahmed's office has none: one fight is
	# enough to read at a time, and a boss room that also burns you is a boss
	# room where the death was the floor's fault.
	"hazard": "none",
	# The kit is ALL against the walls. This is a boss arena before it is a
	# gym: the ring takes the middle 232x148 of the floor and nothing solid
	# stands inside it, so a rhythm fight that steps in and out of range - and
	# DESIGN.md's corner rush, which needs corners to rush into - has the floor
	# it needs. Everything below hugs the west, east and south walls or sits
	# above the ring on the north one.
	"props": [
		# The ring itself: paint, not a thing. It blocks nothing and it pins its
		# top-left corner, which is what puts it UNDER everybody standing on it.
		# Centred on the room: 232x148 from (156, 78) puts its middle on
		# (272, 152), which is the middle of the floor.
		{"type": "boxing_ring", "at": Vector2(156, 78)},
		# The correction on the wall, west of the door line so it cannot cover
		# the arch: TALK IT OUT struck through, GLOVE IT OUT under it.
		{"type": "motto", "at": Vector2(150, 20)},
		# Bags down the west wall, clear of the ring's left edge at x 156.
		{"type": "heavy_bag", "at": Vector2(48, 100)},
		{"type": "heavy_bag", "at": Vector2(48, 168)},
		{"type": "heavy_bag", "at": Vector2(48, 236)},
		{"type": "heavy_bag", "at": Vector2(496, 168)},
		# Weights in the corners, clear of the ring's right edge at x 388.
		{"type": "weight_rack", "at": Vector2(450, 100)},
		{"type": "heavy_bag", "at": Vector2(496, 100)},
		{"type": "table", "at": Vector2(450, 204)},
		{"type": "weight_rack", "at": Vector2(450, 268)},
		{"type": "weight_rack", "at": Vector2(100, 268)},
		{"type": "cooler", "at": Vector2(28, 56)},
		{"type": "plant", "at": Vector2(100, 60)},
		{"type": "plant", "at": Vector2(352, 60)},
		{"type": "dead_plant", "at": Vector2(500, 60)},
		{"type": "table", "at": Vector2(200, 272)},
		# The one couch, ringside, and upholstered in the accent like every
		# other couch in the building - which on this floor makes it red.
		{"type": "sofa", "at": Vector2(380, 276)},
		{"type": "debris", "at": Vector2(420, 200)},
		{"type": "debris", "at": Vector2(330, 260)},
		{"type": "debris", "at": Vector2(120, 208)},
		{"type": "debris", "at": Vector2(470, 244)},
	],
	# Empty: Mostafa is build step 6 and does not exist yet, and the design
	# gives this floor nothing else - a rhythm fight is one fight.
	"enemies": [],
}
