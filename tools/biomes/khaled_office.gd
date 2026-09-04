extends RefCounted
## Floor 10: the penthouse, and the last room in DESIGN.md's building - the
## city window, one desk, one face-down sticky note, and floor to fight on.
##
## Data only, read by tools/biomes.gd; the key reference lives there.

const BIOME := {
	"node": "KhaledOffice",
	"title": "KHALED'S OFFICE",
	# Cold, and the only ramp in the game with no warmth anywhere in it. Every
	# floor below has a temperature - asset recovery's worn brown, the executive
	# floor's mahogany, the innovation lab's pale wood - and this one is charcoal
	# and glass going up to a blue-white, so the room reads as a place that was
	# specified rather than furnished.
	"ramp": ["0a0b0f", "1b1e26", "343946", "5c6373", "9aa2b2", "e8ecf3"],
	# Platinum, which is not a colour so much as the absence of one: this is
	# the one room in the building whose accent adds no hue at all. It is the
	# gym's argument made the opposite way - the gym is grey so its red paint
	# is the only warm thing in it, and this room is grey so the CITY is.
	# Everything with a colour in here is on the other side of the glass.
	"accent": "bccadd",
	"gamma": 1.05,
	# Dark, and the darkest floor in the game after the content studio. A
	# penthouse at night is lit by what is outside it; a bright floor here
	# would be an office with the strip lights on, which is the one thing this
	# room must not look like. Checked with the cast standing on it - the
	# ramp's top is a blue-white, so the floor stops well short of it and the
	# pale characters still read.
	"floor_band": Vector2(0.20, 0.58),
	# Barely there. The band across the middle is a shade of stone rather than
	# a carpet, because the thing on this floor is the rug and a second band
	# under it would be competing with it - the gym's lesson.
	"runner": 0.12,
	# NO COLONNADE. DESIGN.md asks for a wide open arena and this is the second
	# floor to hand in an empty layout, after the gym: the last fight in the
	# game is three phases long and two of them are about distance, so there is
	# nothing in this room to break a line of sight or a charge.
	"columns": {"rows": [], "xs": []},
	# And no hazard, for the third time and the same reason - Ahmed's office,
	# the gym, and now here. A boss room that also burns you is a boss room
	# where the death was the floor's fault.
	"hazard": "none",
	# EVERYTHING IS AGAINST A WALL. The middle of this room is the arena and
	# the only thing in it is the rug, which blocks nothing: no prop here has a
	# collision box anywhere inside x 150-400, y 150-280.
	#
	# There is ONE door in this room. The penthouse is the end of the chain, so
	# nothing is cut through its north wall - which is why the window runs
	# 480 px unbroken, and why the only lane to keep clear runs from the south
	# door up to the desk rather than the whole height of the room.
	"props": [
		# ---- The north wall, which is not a wall ---------------------------
		# The room, in one prop, wall to wall.
		{"type": "city_window", "at": Vector2(32, 18)},
		# ---- The one desk, with its back to the city -----------------------
		# West of the middle rather than on it, because the arena wants the
		# floor and because a desk dead ahead of the door is a desk you walk
		# into. The chair is listed first so it reads behind the desk;
		# Y-sorting does the rest.
		{"type": "chair", "at": Vector2(150, 100)},
		{"type": "exec_desk", "at": Vector2(150, 136)},
		# Two pixels south of the desk's foot, which is what puts it ON the
		# desk - see sticky_note.gd, where the whole trick is explained.
		{"type": "sticky_note", "at": Vector2(174, 138)},
		{"type": "plant", "at": Vector2(36, 104)},
		{"type": "plant", "at": Vector2(508, 104)},
		# The console under the east glass, and the only other flat surface in
		# the room.
		{"type": "table", "at": Vector2(430, 108)},
		# ---- The arena ----------------------------------------------------
		# The same rug the floor below has, which is the catalogue working as
		# intended: one painter, this room's palette, and in a room with no
		# hue in it the pattern comes out platinum on slate. It centres on the
		# room and it blocks nothing, so it marks the floor the last fight
		# happens on without standing in it.
		{"type": "rug", "at": Vector2(164, 170)},
		# ---- The corner he asks you to sit down in -------------------------
		{"type": "plant", "at": Vector2(36, 210)},
		{"type": "sofa", "at": Vector2(60, 250)},
		{"type": "table", "at": Vector2(60, 270)},
		# And the corner he pours from. The trolley is the executive floor's,
		# one storey up.
		{"type": "bar_cart", "at": Vector2(496, 214)},
		{"type": "sofa", "at": Vector2(486, 262)},
	],
	# Empty. Khaled is build step 6 and does not exist yet, and DESIGN.md gives
	# this floor nobody else - the last fight is one fight, and the south door
	# sealing behind you is a `can_travel()` override on this level's own
	# script when the boss lands.
	"enemies": [],
}
