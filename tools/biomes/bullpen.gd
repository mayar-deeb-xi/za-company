extends RefCounted
## Floor 2 of THE NEW HIRE - the office boys' own repair floor.
##
## Data only, read by tools/biomes.gd; the key reference lives there.

const BIOME := {
	"node": "Bullpen",
	"title": "THE BULLPEN",
	# Floor 2: the office boys' own floor, and the first real fight. Where
	# the lobby is over-lit glass and polished stone, this is the back of
	# house - dim, warm, worn, lit by whatever tubes still work. The ramp is
	# brown-grey rather than blue-grey so walking out of the lobby reads as
	# leaving the part of the building visitors see.
	"ramp": ["17130f", "302a22", "544a3c", "857a66", "b8ad96", "e4dcc8"],
	# Amber: warning lights, hazard tape, the colour of something being
	# worked on. Deliberately not the lobby's company teal - that teal is
	# now on the office boys' polos instead, so the uniform reads against
	# the room rather than into it.
	"accent": "e8a33a",
	# Above the lobby's 0.80: this floor is not over-lit, it is under-lit.
	"gamma": 0.95,
	# Dimmer than the lobby's floor and further from the ramp's top - a
	# working floor, not a polished one. Still bright enough in the middle
	# that the dark-haired half of the cast reads against it.
	"floor_band": Vector2(0.28, 0.78),
	# Scuffed carpet tiles down the middle rather than the lobby's clean
	# runner: the same band, less of the accent in it.
	"runner": 0.18,
	# DESIGN.md's "dividers as columns". Six of them in two rows, the full
	# colonnade, because on this floor the dividers ARE the open plan - and
	# they break the sight lines that let four office boys be pulled one at
	# a time instead of arriving together.
	"column": "divider",
	"hazard": "power_strip",
	# The junk. The brief for this room is that the office boys are the
	# people who fix things in this company and they are behind, so the
	# floor is their workshop: server racks along the top wall, e-waste
	# heaped down both sides, hardware in bits on every surface, and a
	# printer nobody has been able to use for weeks.
	#
	# It is dressed heavily but NOT in the middle. Two things need open
	# floor: a four-on-one fight, and the heavy attack this floor teaches -
	# an AoE is worthless in a room where you cannot gather anybody. So the
	# junk is a thick perimeter around a clear arena (about x 200-350,
	# y 110-200), which is also what makes the corners feel like somewhere
	# you go to pick a fight rather than somewhere you get cornered.
	#
	# Everything solid also has to leave the enemies room to leave their own
	# corners: they walk straight at the player and slide off what they hit,
	# with no pathfinding to recover from being wedged.
	"props": [
		# The server bank along the top wall, and the machine with the sign.
		{"type": "server_rack", "at": Vector2(150, 56)},
		{"type": "server_rack", "at": Vector2(176, 56)},
		{"type": "server_rack", "at": Vector2(202, 56)},
		{"type": "scrap_pile", "at": Vector2(228, 64)},
		{"type": "printer", "at": Vector2(340, 56)},
		{"type": "notice", "at": Vector2(372, 22), "turn": -0.09},
		{"type": "cooler", "at": Vector2(452, 48)},
		{"type": "dead_plant", "at": Vector2(492, 96)},
		# E-waste heaped down both side walls.
		{"type": "crt_stack", "at": Vector2(44, 128)},
		{"type": "scrap_pile", "at": Vector2(44, 176)},
		{"type": "pc_tower", "at": Vector2(44, 208)},
		{"type": "cable_spool", "at": Vector2(492, 130)},
		{"type": "scrap_pile", "at": Vector2(492, 178)},
		{"type": "toolbox", "at": Vector2(490, 212)},
		# Work in progress on the way into the arena.
		{"type": "toolbox", "at": Vector2(196, 96)},
		{"type": "pc_tower", "at": Vector2(330, 96)},
		{"type": "toolbox", "at": Vector2(452, 108)},
		{"type": "scrap_pile", "at": Vector2(76, 108)},
		# Junk narrowing the two approaches into the arena, without being in
		# it. Each of these was checked against the straight line its nearest
		# office boy walks to the middle: they walk at the player and slide
		# off what they hit, so a prop parked on that line is a prop one of
		# them grinds along on its way to the fight.
		{"type": "scrap_pile", "at": Vector2(168, 128)},
		{"type": "crt_stack", "at": Vector2(392, 128)},
		{"type": "pc_tower", "at": Vector2(176, 188)},
		{"type": "cable_spool", "at": Vector2(400, 190)},
		# Litter, which is the only thing that goes IN the arena: it blocks
		# nothing, so the floor can look worked-on without the fight or the
		# heavy losing the room they need.
		{"type": "debris", "at": Vector2(250, 140)},
		{"type": "debris", "at": Vector2(322, 124)},
		{"type": "debris", "at": Vector2(296, 178)},
		{"type": "debris", "at": Vector2(218, 192)},
		{"type": "debris", "at": Vector2(272, 210)},
		{"type": "debris", "at": Vector2(92, 200)},
		{"type": "debris", "at": Vector2(462, 166)},
		# The open plan itself: three desks nobody has tidied.
		{"type": "desk", "at": Vector2(72, 268)},
		{"type": "chair", "at": Vector2(72, 282)},
		{"type": "desk", "at": Vector2(196, 268)},
		{"type": "chair", "at": Vector2(196, 282)},
		{"type": "desk", "at": Vector2(348, 268)},
		{"type": "chair", "at": Vector2(348, 282)},
		{"type": "toolbox", "at": Vector2(160, 236)},
		{"type": "crt_stack", "at": Vector2(232, 240)},
		{"type": "cable_spool", "at": Vector2(352, 236)},
		{"type": "printer", "at": Vector2(470, 272)},
	],
	# Four office boys, one to a quadrant rather than a line, so the room is
	# fought a corner at a time - and so the heavy has something to be the
	# right answer to once two of them are following you.
	#
	# Every one of them is clear of the door line, both spawns and both
	# stands by more than its 80 px sight: the closest call is 89-96 px to
	# the hazard and the heart, which is deliberate - the pickups on this
	# floor are nearly, but not quite, watched.
	#
	# None of them stands on a divider's x either, and that one is easy to
	# get wrong: the colonnade sits at x 72/152/232/312/392/472 with its art
	# 48 px tall, so an enemy parked at one of those x values and a lower y
	# than the divider's foot is drawn BEHIND it and simply cannot be seen
	# until it walks out. Two of these were at x 72 and 472 and were
	# invisible in the room.
	"enemies": [
		{"type": "office_boy", "at": Vector2(104, 60)},
		{"type": "office_boy", "at": Vector2(436, 64)},
		{"type": "office_boy", "at": Vector2(120, 248)},
		{"type": "office_boy", "at": Vector2(424, 248)},
	],
}
