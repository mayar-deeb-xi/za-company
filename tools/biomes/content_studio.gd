extends RefCounted
## Floor 2 of THE NEW HIRE - where the content gets made.
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
	# The hub downstairs is where that colour is introduced as
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
	# the floor that hurts. From here up it is both: the standing five go hot
	# on the clock below, so the room says "these things burn" five times and
	# means it every time.
	"hazard": "fallen_light",
	# THE CLOCK, and it is what this floor is now built around. A take rolls,
	# the lights go hot, the dolly runs; between takes the room is the room it
	# always was. One number drives all three (game/levels/studio.gd), so the
	# player learns one rhythm and then knows what the whole floor is about to
	# do.
	#
	# The three numbers are tuned against the player's 90 px/s. `lead` is 1.5 s
	# of warning, which is 135 px - most of the way across the west half, the
	# half this floor is fought in. `rest` is 5 s, comfortably longer than the
	# 2.2 s the dolly needs to get back to its mark, so every take starts from
	# the same end and the room is readable rather than merely busy. `take` is
	# deliberately the SHORTEST of the three: the floor's own lesson is routing,
	# and a room that is hot more than it is cold stops being a route and starts
	# being a wait.
	"studio": {"take": 4.5, "rest": 5.0, "lead": 1.5},
	# The one hazard in the game that moves, and the rail it moves on. Two
	# entries because they are two things - behaviour and paint - and they are
	# written touching because nothing checks that they agree: `from` and `to`
	# are the rig's ends, and the `rail` prop below is the track drawn under
	# exactly that span.
	#
	# It runs the WEST HALF ONLY, and that is the deliberate answer to the one
	# question a moving hazard raises. Every floor keeps x 246-300 walkable top
	# to bottom so the straight walk between the doors is safe in every biome;
	# a rig crossing the room would be the first thing ever to threaten that
	# lane without being placed in it. Tracking across the SET instead is both
	# the legal answer and the better one - a dolly belongs in front of the
	# thing being filmed - and it charges the exact ground this floor already
	# makes expensive: the two overlapping drain fields and the fallen light
	# sitting between them.
	#
	# 78 px/s is under the player's 90 on purpose. Being hit by it has to be a
	# consequence of standing still, never of being run down from behind.
	"dolly": {"from": Vector2(48, 168), "to": Vector2(220, 168),
		"speed": 78.0, "damage": 14},
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
		# The dolly track, under the set and across both western drain fields.
		# Pinned by its top-left like every marking, so this is where the band
		# STARTS: 188 px of it, ending at x 228 and leaving the door lane
		# untouched. Its y brackets the rig's wheels at 168 - see `dolly`.
		{"type": "rail", "at": Vector2(40, 162)},
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
	# Four drain fields and the two fights that have to happen inside one.
	#
	# The three on the west overlap into one pocket: their 120 px reaches meet
	# across the west end of the central band - which is exactly where the
	# fallen ring light stands at (120, 152), and where the dolly runs its rail.
	# Crossing the west side costs drain AND burn, and that is the routing
	# lesson this floor is built to teach. It used to be two fields meeting; a
	# third turns the pocket from a place you clip into a place you commit to.
	#
	# The boy standing in among them is why the pocket has to be answered rather
	# than waited out: a drain you can walk away from is a tax, and a drain with
	# a sword standing in it is a decision.
	#
	# East, the same shape smaller - the green room drain, the boy inside her
	# field, and a second linking the two. The design asked for one "by the
	# north door", which is not legal: an 80 px sight anywhere near x 272 owns
	# the door lane, so east of the exit is the nearest honest reading of it.
	"enemies": [
		# The west pocket: three fields over one another, the boy inside them.
		{"type": "social_media", "at": Vector2(104, 76)},    # the set
		{"type": "social_media", "at": Vector2(48, 108)},
		{"type": "social_media", "at": Vector2(76, 238)},    # off camera
		{"type": "office_boy", "at": Vector2(92, 196)},
		# The green room.
		{"type": "social_media", "at": Vector2(440, 244)},
		{"type": "office_boy", "at": Vector2(416, 168)},     # inside her field
		{"type": "office_boy", "at": Vector2(458, 200)},
	],
	# Two beats. The first is the old one - two dead and two more walk on,
	# drains rather than guards, because the floor's lesson is that standing
	# still in the wrong place costs you, and a second pair of overlapping
	# fields restates it in a room the player has already half-solved.
	#
	# The second comes down the NORTH stairs once the room is nearly answered,
	# and it brings a sword: the west pocket is usually what is still standing
	# by then, and a guard arriving behind a player who is busy being drained is
	# this floor's two halves put together.
	"reinforcements": [
		{"after_kills": 2, "from": "start",
			"enemies": ["social_media", "social_media"],
			"per_head": ["social_media"]},
		{"after_kills": 5, "from": "returned",
			"enemies": ["office_boy", "social_media"],
			"per_head": ["social_media"]},
	],
}
