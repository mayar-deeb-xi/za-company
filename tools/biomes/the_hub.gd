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
	# THE MACHINES. Two floor scrubbers left running, one per half, wandering
	# on no authored route at all - they pick a heading, run until the room
	# stops them, stop, decide, and go again.
	#
	# It is the third moving hazard in the building and deliberately the third
	# SHAPE. The studio's dolly runs a rail and the call floor's surges run four
	# fixed lines, so both are learned as geometry: you find out where the
	# danger is and then you time it. A third fixed path would have been that
	# lesson a third time. This one cannot be learned at all, and what it asks
	# for instead is that you keep looking.
	#
	# This is also the only floor it belongs on, because nothing here decides
	# its route except the furniture - and this is the room with two completely
	# different interiors. The west machine spends its life ricocheting down
	# cubicle rows; the east one crosses open carpet and occasionally finds its
	# way through a 32 px office door. Same machine, two behaviours, and neither
	# of them authored.
	#
	# What it takes is your POSITION, not your health: a low 6 and a real shove
	# (game/player/CLAUDE.md's fourth way the world reaches the player). On a
	# floor whose two drain fields sit inside the glass offices and whose power
	# strip sits in the middle corridor, being moved three feet is worth more
	# than the six points. It is also a solid BODY rather than a trigger, which
	# is the other half of being an obstacle - it is in the way even when it is
	# standing still.
	#
	# `within` is the fence, and it does the job the other two hazards do by
	# being authored to stop short: the door lane (x 246-300) stays walkable
	# because neither pen reaches it. It is also what keeps the floor's two
	# halves two halves - a machine that could cross the middle would make the
	# call side and the media side the same place.
	"scrubbers": [
		{"at": Vector2(150, 230), "within": Rect2(32, 32, 200, 240)},
		{"at": Vector2(400, 160), "within": Rect2(312, 32, 200, 240)},
	],
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
	# The floor's split made literal: the call team holds the west, the media
	# team the east, and each is fought on its own side.
	#
	# Both drains are INSIDE the glass offices, which is what turns each office
	# from decoration into a decision - the only way in is through its one
	# 32 px gap, so entering means entering a radius on purpose. They are 158 px
	# apart against a 120 px reach, so their fields also meet in the corridor
	# between the two bays.
	"enemies": [
		{"type": "call_center", "at": Vector2(96, 168)},      # the call floor
		{"type": "social_media", "at": Vector2(504, 62)},     # north office
		{"type": "social_media", "at": Vector2(470, 240)},    # south office
	],
	# The breather floor, so the lightest ordinary beat: boys walking in behind
	# you while you are committed inside one of the offices.
	"reinforcements": [
		{"after_kills": 2, "from": "start",
			"enemies": ["office_boy", "office_boy"],
			"per_head": ["office_boy"]},
	],
}
