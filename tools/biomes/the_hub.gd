extends RefCounted
## Floor 5 of THE NEW HIRE - the floor the call team and the media team share,
## and neither of them asked to. THE HUB is what the floor plan calls that.
##
## Data only, read by tools/biomes.gd; the key reference lives there.

const BIOME := {
	"node": "TheHub",
	"title": "THE HUB",
	# One room, two halves, and the whole floor is built on the fact that the
	# generator already splits it into a cross: the door line runs top to
	# bottom down the middle (x 246-300) and the runner band runs left to right
	# across it (y 128-176). That cross is a pair of office corridors for free,
	# so the dressing goes in the four quadrants:
	#
	#   WEST  x 16-246   the call floor - identical stations in rows, cubicle
	#                    dividers between them, a phone on every desk.
	#   EAST  x 300-528  the media team's offices - two glass-walled bays you
	#                    walk into, big lit screens, cable, a camera left up.
	#
	# Both corridors stay clear of furniture. The vertical one is the rule
	# every floor keeps (the straight walk between the two doors is safe); the
	# horizontal one is where this floor's two fixtures stand - the power strip
	# at (120, 152) on the call side, the heart at (424, 152) on the media side
	# - and it is the lane a fight will use when this floor gets its enemies.
	#
	# Grey-violet rather than the lobby's blue-grey or asset recovery's brown: a
	# floor lit by ceiling tubes and by everybody's screens, and the first room
	# in the game that is neither polished nor broken - just occupied.
	"ramp": ["15141b", "2c2b36", "4d4b5c", "7e7b90", "afabbe", "e6e3ee"],
	# The magenta the media team put on everything, and which the call floor
	# inherited when the two teams were moved in together: cubicle fabric,
	# carpet tiles, screen glow, the marker on the wallboard.
	"accent": "d9569d",
	# Just above 1.0, so mid-tones sit down: dimmer than asset recovery, and the
	# screens get to be the bright thing in the room.
	"gamma": 1.05,
	# A duller, tighter band than either floor below - office carpet tile, and
	# it never reaches the ramp's top, so a lit screen always out-reads it.
	"floor_band": Vector2(0.26, 0.72),
	"runner": 0.12,
	# Cubicle dividers, and only four of them, all on the CALL side: the
	# generator's colonnade is a cross product of rows and columns, so a layout
	# confined to xs 5 and 10 is confined to the west half. The media half gets
	# walls instead - see `partition` in the props below - because the two
	# halves of this floor have to read as two different kinds of workplace,
	# and that difference is architectural before it is furniture.
	"column": "divider",
	"columns": {"rows": [3, 16], "xs": [5, 10]},
	# The same overloaded strip as the floor below, and deliberately: it is the
	# office boys' hazard, and a row of cubicles with a charger at every seat is
	# exactly where their work follows them upstairs.
	"hazard": "power_strip",
	"props": [
		# ---- WEST: the call floor -------------------------------------------
		# Two rows of stations, three bays each, separated by the dividers. The
		# desks are identical on purpose: the joke of a call floor is that every
		# seat is the same seat, and the phone is the one thing you can see from
		# across the room.
		{"type": "call_desk", "at": Vector2(56, 56)},
		{"type": "chair", "at": Vector2(56, 70)},
		{"type": "call_desk", "at": Vector2(128, 56)},
		{"type": "chair", "at": Vector2(128, 70)},
		# The wallboard, in the stretch of north wall the top row leaves free -
		# which is why that row is two desks and the bottom row is three.
		{"type": "whiteboard", "at": Vector2(178, 18)},
		{"type": "printer", "at": Vector2(216, 104)},
		{"type": "cooler", "at": Vector2(36, 112)},
		{"type": "plant", "at": Vector2(60, 112)},
		{"type": "debris", "at": Vector2(96, 108)},
		{"type": "debris", "at": Vector2(160, 116)},
		{"type": "call_desk", "at": Vector2(56, 268)},
		{"type": "chair", "at": Vector2(56, 282)},
		{"type": "call_desk", "at": Vector2(128, 268)},
		{"type": "chair", "at": Vector2(128, 282)},
		{"type": "call_desk", "at": Vector2(200, 268)},
		{"type": "chair", "at": Vector2(200, 282)},
		# The break corner, against the west wall: two seats and a low table,
		# which is the whole of what a floor this shared gets instead of a break
		# room of its own.
		{"type": "sofa", "at": Vector2(46, 196)},
		{"type": "table", "at": Vector2(46, 222)},
		{"type": "dead_plant", "at": Vector2(228, 208)},
		{"type": "debris", "at": Vector2(104, 232)},
		{"type": "debris", "at": Vector2(176, 204)},
		# ---- EAST: the media team's offices ---------------------------------
		# Each bay is a RUN of partition segments 32 px apart, with one segment
		# left out where the door is: the art and the collision box are both a
		# full 32 wide, so a list of positions is a wall and a gap in the list
		# is a doorway. The glazing is translucent, which is what lets an office
		# be somewhere you can be seen standing.
		#
		# North bay's wall, y 104, door at x 400-432.
		{"type": "partition", "at": Vector2(320, 104)},
		{"type": "partition", "at": Vector2(352, 104)},
		{"type": "partition", "at": Vector2(384, 104)},
		{"type": "partition", "at": Vector2(448, 104)},
		{"type": "partition", "at": Vector2(480, 104)},
		{"type": "partition", "at": Vector2(512, 104)},
		# Inside it: two edit bays facing the glass, and nothing standing in
		# the line between the door and the back wall.
		{"type": "edit_desk", "at": Vector2(352, 60)},
		{"type": "chair", "at": Vector2(352, 74)},
		{"type": "edit_desk", "at": Vector2(472, 60)},
		{"type": "chair", "at": Vector2(472, 74)},
		{"type": "poster", "at": Vector2(392, 18)},
		{"type": "pc_tower", "at": Vector2(330, 96)},
		{"type": "cable_spool", "at": Vector2(500, 92)},
		{"type": "debris", "at": Vector2(415, 92)},
		# South bay's wall, y 216, door at x 368-400 - offset from the north
		# bay's so the two do not read as one template used twice.
		{"type": "partition", "at": Vector2(320, 216)},
		{"type": "partition", "at": Vector2(352, 216)},
		{"type": "partition", "at": Vector2(416, 216)},
		{"type": "partition", "at": Vector2(448, 216)},
		{"type": "partition", "at": Vector2(480, 216)},
		{"type": "partition", "at": Vector2(512, 216)},
		# Inside it: the edit bay is pushed left of the door so the way in
		# stays open, and the shoot kit is parked in the far corner.
		{"type": "edit_desk", "at": Vector2(340, 268)},
		{"type": "chair", "at": Vector2(340, 282)},
		{"type": "camera_rig", "at": Vector2(450, 264)},
		{"type": "cable_spool", "at": Vector2(496, 270)},
		{"type": "pc_tower", "at": Vector2(410, 250)},
		{"type": "debris", "at": Vector2(388, 240)},
	],
	# Empty, and not as an oversight: this floor is the room, built before
	# anybody is put in it. The call team's own reskin (`call_center`) is build
	# order step 2 and the media team's (`social_media`) is with it, so a
	# placement here now would be dungeon guards standing in an office.
	"enemies": [],
}
