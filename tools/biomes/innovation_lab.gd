extends RefCounted
## The floor where the software gets written - and the brightest room in the
## building after the lobby.
##
## Data only, read by tools/biomes.gd; the key reference lives there.

const BIOME := {
	"node": "InnovationLab",
	"title": "THE INNOVATION LAB",
	# Light, and light on purpose: this is the floor the company spent the
	# refurbishment budget on. Warm off-white walls and pale wood, which is
	# what every office built for engineers in the last ten years looks like -
	# and it is the exact opposite of the content studio two floors down, where
	# the ramp never reaches white at all.
	#
	# The contrast is doing work rather than just being pretty. Nothing else in
	# the building is this bright, so the screens on these desks are the
	# DARKEST things in the room instead of the lightest, which is how a floor
	# full of monitors reads as a floor full of monitors.
	"ramp": ["24211c", "4a463d", "7d7768", "aaa495", "d5d0c2", "faf7f0"],
	# The blue every editor's syntax highlighting is set to. No other floor is
	# blue - the call centre's cyan is the nearest and it is colder and
	# greener - so the accent alone says which team this is.
	"accent": "3f6fe0",
	# Below 1.0 lifts the mid-tones, the same as the lobby: a bright room under
	# too many downlights rather than a dim one.
	"gamma": 0.78,
	# High, but stopping short of the ramp's near-white top, which is the
	# lobby's lesson: a floor at the hot end takes the pale half of the cast
	# with it. Checked with three of them standing on it.
	"floor_band": Vector2(0.40, 0.88),
	# A carpet runner down the middle with a little of the blue in it.
	"runner": 0.14,
	# Glazed steel pillars, four of them, and NOT cubicle dividers - the point
	# of an engineering floor is that it is open plan, and the point of four
	# rather than twelve is the floor a full colonnade would eat.
	#
	# The rows are 6 and 12 rather than the usual 5 and 13, and that is a
	# placement fix rather than a style choice: a pillar's art is 48 px tall
	# above its foot, so rows 5 and 13 put it across y 48-96, which is exactly
	# where north-wall furniture stands. Moved down two tiles, the whole north
	# wall is free for the whiteboard and the first pod.
	"column": "pillar",
	"columns": {"rows": [6, 12], "xs": [4, 29]},
	# The same overloaded strip as the floors below, and it needs no excuse
	# here: seven workstations, each with a laptop, two monitors and a machine
	# under the desk, all fed from whatever was already plugged in.
	"hazard": "power_strip",
	# Two pods on the west side, the service wall and the breakout on the east,
	# and the two lanes every floor keeps clear: the door line (x 246-300) and
	# the central band (y 128-176), where the power strip stands at (120, 152).
	#
	# Everything here also stays off the pillar columns at x 64-80 and 464-480
	# in the rows the pillars occupy - a prop parked behind one is a prop drawn
	# behind 48 px of glazed steel.
	"props": [
		# ---- North: the whiteboard and the first pod ------------------------
		# The board comes first because it is the biggest thing on the wall and
		# everything else on this wall is placed around it.
		{"type": "diagram", "at": Vector2(22, 18)},
		{"type": "dev_desk", "at": Vector2(128, 58)},
		{"type": "chair", "at": Vector2(128, 72)},
		{"type": "dev_desk", "at": Vector2(204, 58)},
		{"type": "chair", "at": Vector2(204, 72)},
		# ---- North-east: what the floor watches and what it runs on --------
		{"type": "build_board", "at": Vector2(330, 18)},
		{"type": "cooler", "at": Vector2(316, 58)},
		{"type": "server_rack", "at": Vector2(410, 56)},
		{"type": "server_rack", "at": Vector2(436, 56)},
		{"type": "pc_tower", "at": Vector2(462, 52)},
		{"type": "coffee", "at": Vector2(500, 58)},
		{"type": "dev_desk", "at": Vector2(400, 100)},
		{"type": "chair", "at": Vector2(400, 114)},
		# ---- South-west: the second pod, three across ----------------------
		{"type": "dev_desk", "at": Vector2(52, 252)},
		{"type": "chair", "at": Vector2(52, 266)},
		{"type": "dev_desk", "at": Vector2(128, 252)},
		{"type": "chair", "at": Vector2(128, 266)},
		{"type": "dev_desk", "at": Vector2(204, 252)},
		{"type": "chair", "at": Vector2(204, 266)},
		{"type": "cable_spool", "at": Vector2(36, 200)},
		{"type": "debris", "at": Vector2(100, 208)},
		{"type": "debris", "at": Vector2(172, 196)},
		# The printer nobody on this floor has used since they were hired.
		{"type": "printer", "at": Vector2(120, 196)},
		# ---- The middle and the south-east: a plant, one more desk, and
		# somewhere to stand up ---------------------------------------------
		{"type": "plant", "at": Vector2(330, 120)},
		{"type": "debris", "at": Vector2(340, 230)},
		{"type": "dev_desk", "at": Vector2(400, 210)},
		{"type": "chair", "at": Vector2(400, 224)},
		{"type": "sofa", "at": Vector2(360, 262)},
		{"type": "table", "at": Vector2(360, 282)},
		{"type": "plant", "at": Vector2(420, 258)},
		# The plant nobody on this floor has watered, which is every dev
		# floor's second plant.
		{"type": "dead_plant", "at": Vector2(500, 250)},
		{"type": "debris", "at": Vector2(470, 196)},
	],
	# Empty, like every floor built since the reskins were deferred: whoever
	# this floor fights is placed by hand.
	"enemies": [],
}
