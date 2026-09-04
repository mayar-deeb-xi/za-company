extends RefCounted
## Floor 9: the executive floor, DESIGN.md's mix/exam room - dark wood, glass
## walls, and the awards cabinet.
##
## Data only, read by tools/biomes.gd; the key reference lives there.

const BIOME := {
	"node": "ExecutiveFloor",
	"title": "THE EXECUTIVE FLOOR",
	# Mahogany. The one thing every floor below this has in common is that it
	# was furnished from a catalogue; this one was furnished from an auction,
	# and the palette is the whole argument - a red-brown wood ramp, where the
	# bullpen's brown is the yellow of worn laminate and hellfire's is heat.
	# Nothing in the building is this dark AND this warm at once.
	"ramp": ["120c0a", "2b1a15", "4e3125", "7d5540", "a8825c", "dcc3a0"],
	# Brass: the inlay, the picture frames, the trolley, the door furniture.
	# Deeper and oranger than the marble hall's pale gold and less yellow than
	# the bullpen's amber, which is what keeps three warm floors apart.
	"accent": "d4a13c",
	# Above 1.0 sinks the mid-tones and leaves the highlights hot, which is
	# what polish IS: a dark room with bright edges. The lobby's 0.80 is the
	# opposite end of the same dial and the two rooms are meant to be read
	# against each other - floor 1 is over-lit and cheap, floor 9 is under-lit
	# and expensive.
	"floor_band": Vector2(0.34, 0.74),
	"gamma": 1.12,
	# A brass-tinted carpet down the corridor band, which on this floor is the
	# strip immediately south of the glass wall - the one stretch of floor the
	# whole room walks along.
	"runner": 0.24,
	# Fluted stone, and the ONLY office floor that uses it. The classical
	# column is what made the lobby read as a temple, which is exactly the
	# joke here: the executive floor is an office pretending to be a palace,
	# and it is the one floor in the building entitled to the pretence.
	#
	# Four of them, both rows in the SOUTHERN half (rows 10 and 15, feet at
	# y 176 and 256), so the colonnade frames the gallery you arrive into and
	# leaves the boardroom half to the glass.
	"column": "classical",
	"columns": {"rows": [10, 15], "xs": [4, 29]},
	# The floor polisher, and this is the floor it was always for. The lobby
	# dropped it because a tutorial room must not hurt you by standing still;
	# nine floors up, on the only floor in the building whose wood is actually
	# polished, a machine left running across the corridor is both the hazard
	# and the joke. Its stand is fixed at (120, 152), in the corridor band.
	"hazard": "polisher",
	# THE ROOM IS TWO ROOMS. A run of glass partitioning crosses the whole
	# floor at y 128 with a single 64 px gap on the door line (x 240-304), so
	# everything north of it - the boardroom and the trophy wall - is reached
	# through one opening in the middle of the room. That is DESIGN.md's centre
	# chokepoint, drawn rather than described, and it is why the awards are
	# behind the glass: "every prize requires stepping into a radius on
	# purpose" only means anything if getting to the prize is a decision.
	#
	# Two things to know before placing anybody on this floor. Enemies slide
	# off what they hit and have no pathfinding, so an enemy on the far side
	# of the glass from the player grinds along it instead of coming round -
	# whoever guards the north half belongs IN the north half, and whoever
	# meets you at the chokepoint belongs at its mouth. And the gap is on the
	# door line, so the straight walk between the two doors is still a straight
	# walk; nothing solid goes in x 246-300 at any y.
	"props": [
		# ---- The glass wall: seven bays west, seven east, 32 px apart -------
		{"type": "partition", "at": Vector2(32, 128)},
		{"type": "partition", "at": Vector2(64, 128)},
		{"type": "partition", "at": Vector2(96, 128)},
		{"type": "partition", "at": Vector2(128, 128)},
		{"type": "partition", "at": Vector2(160, 128)},
		{"type": "partition", "at": Vector2(192, 128)},
		{"type": "partition", "at": Vector2(224, 128)},
		{"type": "partition", "at": Vector2(320, 128)},
		{"type": "partition", "at": Vector2(352, 128)},
		{"type": "partition", "at": Vector2(384, 128)},
		{"type": "partition", "at": Vector2(416, 128)},
		{"type": "partition", "at": Vector2(448, 128)},
		{"type": "partition", "at": Vector2(480, 128)},
		{"type": "partition", "at": Vector2(512, 128)},
		# ---- North-west, behind the glass: the boardroom --------------------
		# The founder on the west wall, clear of the chairs so the plaque under
		# him is never covered by a chair back.
		{"type": "portrait", "at": Vector2(26, 18)},
		{"type": "boardroom_table", "at": Vector2(128, 104)},
		{"type": "chair", "at": Vector2(92, 74)},
		{"type": "chair", "at": Vector2(128, 74)},
		{"type": "chair", "at": Vector2(164, 74)},
		{"type": "chair", "at": Vector2(92, 116)},
		{"type": "chair", "at": Vector2(128, 116)},
		{"type": "chair", "at": Vector2(164, 116)},
		{"type": "bar_cart", "at": Vector2(210, 112)},
		{"type": "plant", "at": Vector2(36, 116)},
		# A fourth cabinet, west of the door line and inside the boardroom -
		# the overflow, and what fills the stretch of wall between the table
		# and the opening without narrowing the opening.
		{"type": "awards_cabinet", "at": Vector2(214, 66)},
		# ---- North-east, behind the glass: the trophy wall -----------------
		# Three of them in a row along the north wall. One would be an object;
		# three are an institution.
		{"type": "awards_cabinet", "at": Vector2(344, 66)},
		{"type": "awards_cabinet", "at": Vector2(392, 66)},
		{"type": "awards_cabinet", "at": Vector2(440, 66)},
		{"type": "plant", "at": Vector2(496, 70)},
		# Somewhere to sit and look at them, which is what makes the trophy
		# wall a room rather than a corridor.
		{"type": "sofa", "at": Vector2(450, 116)},
		# ---- South: the gallery you arrive into ----------------------------
		# The rug centres on the room (164 + 108 = 272) and blocks nothing -
		# you walk in from the south door straight onto it.
		{"type": "rug", "at": Vector2(164, 182)},
		{"type": "sofa", "at": Vector2(200, 258)},
		{"type": "sofa", "at": Vector2(344, 258)},
		# Palms either side of the rug, off both its edges (x 164 and 380).
		{"type": "plant", "at": Vector2(152, 200)},
		{"type": "plant", "at": Vector2(392, 200)},
		# One more at the east end of the corridor band, where the walk along
		# the glass would otherwise run 150 px with nothing in it.
		{"type": "plant", "at": Vector2(410, 168)},
		# The desk that decides whether you get through the gap at all, facing
		# the arrival. Kept off the colonnade's x 64-80, where a column's 48 px
		# of art would stand in front of it.
		{"type": "desk", "at": Vector2(120, 216)},
		{"type": "chair", "at": Vector2(120, 230)},
		{"type": "cooler", "at": Vector2(36, 168)},
		{"type": "table", "at": Vector2(440, 200)},
		{"type": "chair", "at": Vector2(440, 214)},
		{"type": "sofa", "at": Vector2(452, 276)},
		# The one thing on this floor nobody has kept up, and it is the same
		# joke every floor in the building tells - it just costs more here.
		{"type": "dead_plant", "at": Vector2(504, 216)},
	],
	# Empty, like every floor since the reskins were deferred. DESIGN.md wants
	# three office boys, two social_media and one call_center at the chokepoint;
	# they are placed by hand.
	"enemies": [],
	# No debris anywhere, and that is a choice rather than an omission. Every
	# floor below this has litter on it because every floor below this is used;
	# the executive floor is cleaned nightly, and the absence is the loudest
	# thing the room says about who works on it.
}
