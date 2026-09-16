extends RefCounted
## The call floor - DESIGN.md's denial level, and the densest room in the game.
##
## Data only, read by tools/biomes.gd; the key reference lives there.
##
## ## THE DOGLEG
##
## It is the one floor in the building that is not a rectangle, and the shape
## is the point rather than a decoration on it. A wide hall runs along the
## bottom of the plan and the way out is up an ARM in the north-east corner, so
## this is the only room in the game where you cannot see the exit from the
## entrance, and the only one where crossing the floor is the ROUTE rather than
## a choice. On the floor whose whole subject is your movement being taken away,
## being made to cross it is the sentence the room was already trying to say.
##
## Three things fall out of that and each one is load-bearing:
##
## - **The walk has two turns in it, and it is authored** (`lane`, below). Every
##   other floor keeps one straight band clear - x 246-300 at every y - and the
##   rule that band exists for is the oldest one in the project: no enemy's
##   sight, no hazard and no prop on the walk between the doors. Here it is
##   three legs meeting at two corners, so the floor carries its own and
##   game/levels/level.gd hands it to whoever asks.
## - **The arm holds nobody.** It is 256 px wide with a 54 px lane up the middle
##   of it, which leaves 100 px either side - and a `call_center` needs 130 px
##   of clearance for its sight alone. So the corridor is deliberately empty of
##   placed bodies: what happens in it is the north BEAT, two boys coming down
##   the stairs the player is climbing. An arrival is the only legal way to put
##   anybody on a walk, and the room's own shape is what makes that arrival land.
## - **The maze stays in the hall.** Eighteen dividers, in the hall only, because
##   a corridor is not a maze and dressing one as a maze is how a route becomes
##   a chore. The arm gets trunking and litter and nothing to walk round.
##
## The cut is one rectangle - cols 0-21, rows 0-13 - and tools/plan.gd grows the
## walls around whatever is left, which is why nothing here says where a wall is.

const BIOME := {
	"node": "CallCenter",
	"title": "THE CALL CENTER",
	# 40 x 34 tiles against every other floor's 34 x 19, with the north-west
	# quarter taken out of it. The doors are not in line with each other any
	# more: the way back is the middle of the south wall as always, and the way
	# up is at the top of the arm, six tile columns east of it.
	"shape": {
		"cols": 40, "rows": 34,
		"cut": [Rect2i(0, 0, 22, 14)],
		"doors": {"out": 29, "back": 16},
	},
	# The walk, in three legs, meeting at two corners. Up the middle of the hall
	# from the south door, east along the hall's north wall, then up the arm.
	# The turn hugs the wall on purpose: it leaves the whole body of the hall
	# for the fight instead of cutting it in half, and it means the player's
	# route and the room's furniture want opposite parts of the floor.
	"lane": [
		Rect2(246, 294, 54, 234),    # the climb from the south door
		Rect2(246, 240, 262, 54),    # the run east under the north wall
		Rect2(454, 16, 54, 278),     # up the arm to the way out
	],
	# Fluorescent green-grey: the colour a room gets painted when nobody who
	# works in it was asked. No other floor is green, which is the point - it
	# lands between the content studio's near-black and Ahmed's dark marble, so
	# walking in here is walking into the lights being ON.
	"ramp": ["10130f", "222a20", "3e4a3c", "687563", "97a48f", "cdd7c4"],
	# Cold cyan, and it is the "on hold" colour: DESIGN.md gives the call_center
	# enemy a charge ring that reads as a spreading on-hold circle, so the floor
	# is lit in the colour of being asked to wait.
	"accent": "3fc9e8",
	# Below 1.0 lifts the mid-tones, the same as the lobby: this room is
	# over-lit rather than under-lit, and flatly, by tubes nobody turns off.
	"gamma": 0.88,
	"floor_band": Vector2(0.30, 0.82),
	# Barely any: worn carpet tile, not carpet.
	"runner": 0.10,
	# DESIGN.md's "densest columns" - eighteen dividers in three ranks, half
	# again as many as asset recovery's full colonnade, which is what makes this
	# a maze rather than an open plan. All eighteen are in the HALL: the ranks
	# sit at y 304 / 384 / 464, which is the body of the room, and the arm is
	# left bare.
	#
	# Two things follow from three ranks, and the second one bites when this
	# floor gets its people. A divider's panel is waist height with the room
	# carrying on above it, so it hides less than its 48 px of art suggests -
	# but an enemy parked ON a divider's x and above its foot is invisible, and
	# on this floor there are eighteen chances to make that mistake instead of
	# six. The divider xs are 72 / 152 / 232 / 312 / 392 / 552; keep every
	# enemy off them, or south of a foot where Y-sorting draws it in front.
	#
	# The gap where a seventh column would be - x 472 - is the mouth of the arm,
	# and it is empty on purpose: a panel drawn across the corner is a panel the
	# player turns behind.
	"column": "divider",
	"columns": {"rows": [18, 23, 28], "xs": [4, 9, 14, 19, 24, 34]},
	# DESIGN.md's hazard: the photocopier, jammed, lid up, fuser still going.
	# Not the `printer` in the catalogue - that one is a machine nobody can
	# use, this is a machine nobody should touch.
	#
	# It stands at the INSIDE of the turn, a body's width west of the lane's
	# corner, so cutting that corner tight is the thing it taxes. Nothing else
	# on this floor asks anything of a player who is walking rather than
	# fighting.
	#
	# South of the north strip rather than in it: a sheet of A4 taped to the wall
	# above a hazard covers the top half of the hazard, and the one thing on this
	# floor that must be legible before it is touched is this. And OFF the divider
	# xs, which is the enemies' rule applying to a machine for the same reason -
	# x 232 put it four pixels north of a divider's foot, where Y-sorting drew
	# the panel over the hazard and left a burn nobody could see coming.
	"hazard": "copier",
	"hazard_at": Vector2(208, 286),
	# THE WIRING, and it is what makes this floor move. Four runs of cable
	# trunking, each one dull until it flares end to end and then puts something
	# very fast down its length. Something in the room is going off roughly
	# every six tenths of a second, and two of the four are usually in flight.
	#
	# It is on this floor rather than any other because of what it asks. The
	# studio's dolly is one slow rig and what it wants is patience; this is the
	# DENIAL floor, where two slowers take your movement away, and the honest
	# threat for a room like that is one that punishes being slow rather than
	# one that rewards waiting. A surge is a tax on crossing at the wrong
	# moment - the head passes a standing player in a tenth of a second, well
	# inside one grace window, so a run costs exactly one blow however it
	# catches you and can never be a lane you are trapped in. That is what
	# makes four of them fair, and why 8 sits under the copier's 10: the copier
	# is one place you chose to stand in, these are four lanes you have to
	# cross.
	#
	# Three things about the geometry, and the first is the rule:
	#
	# - **Every run stops clear of the walk.** The hall's aisle at y 320 is cut
	#   in two at the lane - the west half ends at 232 and the east half starts
	#   at 312 - exactly as it always was. Splitting an aisle is not a
	#   compromise: it is what DOUBLED the number of runs, and it is most of
	#   what makes the room feel busy.
	# - **The arm's two runs are VERTICAL, and they are the first in the game.**
	#   A corridor's trunking goes along the corridor, and what a player is
	#   doing in the arm is climbing rather than crossing - so these do not cut
	#   the route, they punish drifting off it. They sit 60 px either side of
	#   the lane, at x 392 and x 600.
	# - **`after` is the only per-run number that is not geometry**, and the
	#   four are spread across the cycle so no two neighbours fire in sequence.
	#   The hall's pair are half a cycle apart, so crossing the hall and
	#   climbing the arm never sound like one machine.
	"surge": {
		"speed": 260.0, "period": 2.4, "charge": 0.5, "damage": 8,
		"runs": [
			{"from": Vector2(24, 320), "to": Vector2(232, 320), "after": 0.0},
			{"from": Vector2(392, 208), "to": Vector2(392, 40), "after": 0.6},
			{"from": Vector2(616, 320), "to": Vector2(312, 320), "after": 1.2},
			{"from": Vector2(600, 40), "to": Vector2(600, 208), "after": 1.8},
		],
	},
	# The stations. Ten of them in the pockets the dividers leave - one under the
	# hall's north wall and the rest in the two bands the wiring crosses - so the
	# room still reads as a grid of identical seats, which is the whole of what a
	# call floor looks like and the whole of the joke.
	#
	# **The north strip holds almost nothing, and that is the shape deciding it.**
	# The walk runs east along that wall, which leaves a band barely fifty pixels
	# deep either side of it - and everything in this game is drawn upwards from
	# its foot, so a desk standing in that band reaches up into whatever is hung
	# on the wall above it. Two desks under the wallboard read as one object with
	# monitors growing out of a scoreboard. What lives up there now is what hangs
	# (the board, the notice) or what is thin (the cooler, the printer); the
	# seats live in the body of the room.
	"props": [
		{"type": "call_desk", "at": Vector2(576, 264)},
		{"type": "chair", "at": Vector2(576, 278)},
		{"type": "call_desk", "at": Vector2(112, 352)},
		{"type": "chair", "at": Vector2(112, 366)},
		{"type": "call_desk", "at": Vector2(192, 352)},
		{"type": "chair", "at": Vector2(192, 366)},
		{"type": "call_desk", "at": Vector2(352, 352)},
		{"type": "chair", "at": Vector2(352, 366)},
		{"type": "call_desk", "at": Vector2(432, 352)},
		{"type": "chair", "at": Vector2(432, 366)},
		{"type": "call_desk", "at": Vector2(512, 352)},
		{"type": "chair", "at": Vector2(512, 366)},
		{"type": "call_desk", "at": Vector2(112, 504)},
		{"type": "chair", "at": Vector2(112, 518)},
		{"type": "call_desk", "at": Vector2(192, 504)},
		{"type": "chair", "at": Vector2(192, 518)},
		{"type": "call_desk", "at": Vector2(352, 504)},
		{"type": "chair", "at": Vector2(352, 518)},
		{"type": "call_desk", "at": Vector2(432, 504)},
		{"type": "chair", "at": Vector2(432, 518)},
		# The board, in the stretch of the hall's north wall the player walks
		# the whole length of on the way to the arm, where the floor can see it
		# all day.
		{"type": "wallboard", "at": Vector2(92, 242)},
		# And the other thing this company communicates by: a sheet of A4. One
		# at the turn and one at the top of the arm, which is the last thing
		# anybody reads before the stairs.
		{"type": "notice", "at": Vector2(176, 244)},
		{"type": "notice", "at": Vector2(400, 18)},
		{"type": "printer", "at": Vector2(604, 264)},
		{"type": "cooler", "at": Vector2(40, 264)},
		{"type": "dead_plant", "at": Vector2(608, 320)},
		{"type": "table", "at": Vector2(40, 504)},
		{"type": "sofa", "at": Vector2(600, 504)},
		# The arm, dressed as a corridor: what is stored in one rather than what
		# is worked at in one.
		{"type": "cable_spool", "at": Vector2(432, 176)},
		{"type": "debris", "at": Vector2(560, 160)},
		{"type": "debris", "at": Vector2(392, 96)},
		{"type": "debris", "at": Vector2(208, 360)},
		{"type": "debris", "at": Vector2(368, 416)},
		{"type": "debris", "at": Vector2(96, 344)},
		{"type": "debris", "at": Vector2(448, 472)},
	],
	# Two slowers in the pockets the dividers make, and seven boys knotted around
	# them. Every one of the nine is either off the divider xs (72 / 152 / 232 /
	# 312 / 392 / 552) or SOUTH of a divider's foot, where Y-sorting draws it in
	# front of the panel rather than behind it - which is the mistake this floor
	# offers eighteen chances to make.
	#
	# This is the floor where being slowed near a guard is the lesson, so the
	# pair is the point and must not be trimmed: DESIGN.md's escape hatch for
	# this room's weight is one office boy, never a call_center.
	#
	# What the dogleg changed is WHERE they can be. All nine are in the hall and
	# all nine are south of the walk, because the three legs of it take the
	# room's whole northern edge and the middle of the arm - and clearing a leg
	# by a body's own sight is the rule, which puts a 130 px slower 130 px off
	# it. Each slower still sits inside a knot of boys, so the floor's sentence -
	# slowed, and then swung at - happens without the player getting to pick the
	# order. They also keep off the hall's surge aisle at y 320: a hazard that
	# clears the room for you is a hazard doing the player's job.
	"enemies": [
		# The west knot, around (110, 430) - the half of the hall the player
		# walks INTO, and the one the turn puts behind them.
		{"type": "call_center", "at": Vector2(108, 424)},
		{"type": "office_boy", "at": Vector2(44, 400)},
		{"type": "office_boy", "at": Vector2(136, 408)},
		{"type": "office_boy", "at": Vector2(64, 464)},
		{"type": "office_boy", "at": Vector2(164, 472)},    # south of the foot
		# The east knot, under the mouth of the arm, so the climb is made with
		# this one still standing.
		{"type": "call_center", "at": Vector2(584, 432)},
		{"type": "office_boy", "at": Vector2(488, 440)},
		{"type": "office_boy", "at": Vector2(600, 400)},
		{"type": "office_boy", "at": Vector2(520, 480)},
	],
	# Boys only, and still no third slower: this room already holds two, and a
	# third arriving would stop being pressure and start being a room the player
	# cannot move in. What a beat adds is bodies to be slowed AMONG.
	#
	# Two of them, from opposite doors, and the shape is what makes the second
	# one land. The first arrives behind the player while the west knot is being
	# answered. The second comes down the NORTH stairs once the room has been
	# worked through - which on this floor means down the arm, into a corridor
	# the player is about to climb, from a door they cannot see the room from.
	# It is the only place in the game where a beat arrives head-on.
	"reinforcements": [
		{"after_kills": 3, "from": "start",
			"enemies": ["office_boy", "office_boy"],
			"per_head": ["office_boy"]},
		{"after_kills": 7, "from": "returned",
			"enemies": ["office_boy", "office_boy"],
			"per_head": ["office_boy"]},
	],
	# THE FIRST TIME ANYBODY IN THIS BUILDING IS KIND TO YOU. Floor 3 is where a
	# slow near two guards stops being a lesson and starts being a death, and it
	# is the last floor before Ahmed - so it is where the game has to admit that
	# healing exists at all, the lobby's free heart being two floors behind.
	# He comes in by the south door and stands in the hall, in the pocket
	# between the second and third ranks of dividers: clear of the copier at the
	# turn, clear of the walk, and on the side of the room the fight starts on
	# rather than the side it ends on - so he is behind the player by the time
	# the room is quiet, which is a reason to look back at it.
	"relief": {"npc": "ivan", "from": "start", "at": Vector2(208, 400),
		"say": "res://game/npcs/ivan/after_call_center.gd"},
	# The FOURTH beat, and this is the first floor to carry one: Dominique comes
	# DOWN the north stairs - the ones the player is about to go up - to say what
	# is waiting at the top. `from: "returned"` is the whole reason she is
	# legible here: Ivan arrives on the same cue through the south door, and two
	# people walking in at one threshold is two bodies shoving each other across
	# the same sixteen pixels. Opposite doors also say the two things they are
	# for - he has come from where you have been, she from where you are going.
	#
	# She waits in the ARM, off the lane by sixty pixels, which is the one thing
	# this floor's shape makes easy: there is a corridor between the player and
	# the stairs, and somebody standing in it cannot be walked past by accident.
	"briefing": {"npc": "dominique", "from": "returned", "at": Vector2(568, 128),
		"say": "res://game/npcs/dominique/before_ahmed.gd"},
}
