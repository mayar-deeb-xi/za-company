extends RefCounted
## Floor 5 of THE NEW HIRE - where the content gets made.
##
## Data only, read by tools/biomes.gd; the key reference lives there.

const BIOME := {
	"node": "ContentStudio",
	"title": "THE CONTENT STUDIO",
	# DESIGN.md asks for a dark room and neon, and this is the first floor in
	# the game that is genuinely DARK: the ramp never reaches white, it tops out
	# at a muted blue-grey, so the brightest things in the room are the lights
	# standing in it and the sign on the wall. Everywhere else the palette is
	# the room; here the palette gets out of the way of the fixtures.
	"ramp": ["07080e", "141827", "252c44", "3e4668", "5f6b98", "8f9ccc"],
	# Neon violet - the media team's magenta pushed to the end of the tube.
	# The shared floor downstairs is where that colour is introduced as
	# something the team brought with them; this is where they own the room.
	"accent": "a64dff",
	# Above 1.0 pushes mid-tones down and leaves the highlights hot, which is
	# exactly a room lit by a handful of very bright point sources.
	"gamma": 1.10,
	# The floor is the one thing that must NOT go as dark as the room wants.
	# The band starts high on a low ramp on purpose: the cast is dark-haired
	# and dark-suited, and a floor that reached this ramp's bottom would be a
	# floor you cannot see anybody standing on. The room reads dark because the
	# WALLS are near-black - they come off the ramp's low end, outside the band.
	"floor_band": Vector2(0.32, 0.68),
	# The most accent of any floor: the central band is the lit part of the
	# room, so the carpet under it takes the neon.
	"runner": 0.22,
	# Four glazed pillars rather than a colonnade of twelve, and for the same
	# reason the lobby has four: the floor a full colonnade takes up is the
	# floor this room needs. It needs it more than the lobby does - the fight
	# this floor is designed around is routing between overlapping drain
	# fields, and a column is a sight-line breaker, which is the one thing that
	# would undo the lesson.
	"column": "pillar",
	"columns": {"rows": [5, 13], "xs": [4, 29]},
	# DESIGN.md's hazard: a ring light knocked over, still at full output.
	# Its standing twin is `ring_light` in the props below - the same object,
	# once as the furniture that makes this a studio and once as the thing on
	# the floor that hurts.
	"hazard": "fallen_light",
	# The kit. Two rules shape where it goes, and they are the same two every
	# floor keeps: the door line (x 246-300) stays clear top to bottom, and the
	# central band (y 128-176) stays clear left to right - the fallen light
	# stands in it at (120, 152), and it is the lane the routing fight will use.
	#
	# The middle of the room is deliberately the emptiest part of this floor,
	# more so than anywhere else in the game. Three drain fields that overlap
	# need floor to overlap ON, and whoever places them needs somewhere to put
	# them: everything here is pushed into the four quadrants and against the
	# walls.
	"props": [
		# ---- The set: what actually gets filmed ------------------------------
		# A paper sweep against the north wall with the interview couch in
		# front of it, the plant that is in every shot, a light either side and
		# a camera looking at the lot of it.
		{"type": "backdrop", "at": Vector2(140, 60)},
		{"type": "sofa", "at": Vector2(140, 92)},
		{"type": "plant", "at": Vector2(188, 92)},
		{"type": "ring_light", "at": Vector2(94, 104)},
		{"type": "ring_light", "at": Vector2(208, 112)},
		{"type": "camera_rig", "at": Vector2(156, 124)},
		# The sign, on the stretch of north wall the backdrop leaves free and
		# directly above the set - which is where a studio hangs the thing it
		# wants in frame behind the presenter.
		{"type": "neon", "at": Vector2(196, 20)},
		# ---- The station: where it gets cut and streamed --------------------
		{"type": "edit_desk", "at": Vector2(404, 60)},
		{"type": "chair", "at": Vector2(404, 74)},
		{"type": "pc_tower", "at": Vector2(356, 60)},
		{"type": "ring_light", "at": Vector2(336, 100)},
		{"type": "cable_spool", "at": Vector2(496, 104)},
		{"type": "debris", "at": Vector2(450, 112)},
		# ---- Off camera: the half of a studio nobody posts ------------------
		{"type": "ring_light", "at": Vector2(52, 262)},
		{"type": "table", "at": Vector2(120, 250)},
		{"type": "camera_rig", "at": Vector2(172, 258)},
		{"type": "cable_spool", "at": Vector2(96, 214)},
		{"type": "dead_plant", "at": Vector2(216, 240)},
		{"type": "debris", "at": Vector2(44, 204)},
		{"type": "debris", "at": Vector2(150, 208)},
		{"type": "debris", "at": Vector2(204, 268)},
		# The green room, which is a couch and a table in the dark corner.
		{"type": "ring_light", "at": Vector2(350, 258)},
		{"type": "sofa", "at": Vector2(452, 262)},
		{"type": "table", "at": Vector2(452, 282)},
		{"type": "plant", "at": Vector2(500, 250)},
		{"type": "cable_spool", "at": Vector2(330, 200)},
		{"type": "debris", "at": Vector2(400, 240)},
	],
	# Empty, and this one is empty because it was ASKED to be: the floor's
	# people are being placed by hand. What the design wants when they land is
	# 3 social_media whose sight radii overlap across the middle of the room,
	# and 1 office boy by the north door so that one fight has to happen inside
	# the field. The four quadrants are dressed and the middle is not, which is
	# the room those placements need.
	"enemies": [],
}
