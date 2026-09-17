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
##   of clearance for its sight alone. So it is deliberately empty of placed
##   bodies: what happens in it is the north BEAT, two boys coming down
##   the stairs the player is climbing. An arrival is the only legal way to put
##   anybody on a walk, and the room's own shape is what makes that arrival land.
## - **But it is FURNISHED, because it is not a corridor.** It is 256 px wide
##   and 272 deep - a quarter of the floor - and calling it a corridor is what
##   left a quarter of the floor with three things in it. So it is what an annex
##   on a call floor actually is: the overflow room, a second bank of stations
##   down its east side facing the lane, and the junk that ends up in the half
##   of a room nobody is seated in down its west side. Everything up there is
##   placed against two lines that are not walls - the lane, and the two runs of
##   trunking at x 392 and x 600, which a prop standing on would hide.
## - **The maze stays in the hall.** Twenty-four dividers, in the hall only,
##   because a route is not a maze and dressing one as a maze is how a route
##   becomes a chore. The arm is furnished, never obstructed: the difference is
##   that its furniture stands along the walls and leaves the climb straight.
##
## The cut is one rectangle - cols 0-21, rows 0-16 - and tools/plan.gd grows the
## walls around whatever is left, which is why nothing here says where a wall is.

const BIOME := {
	"node": "CallCenter",
	"title": "THE CALL CENTER",
	# 40 x 37 tiles against every other floor's 34 x 19, with the north-west
	# corner taken out of it. The doors are not in line with each other any
	# more: the way back is the middle of the south wall as always, and the way
	# up is at the top of the arm, six tile columns east of it.
	#
	# The cut is three rows DEEPER than the hall was first drawn against, and
	# that one number is the whole of what lengthens the arm: the corridor grows
	# at its MOUTH and the hall is pushed 48 px south entire, so every position
	# in the body of the room moved with it and nothing in the arm moved at all.
	"shape": {
		"cols": 40, "rows": 37,
		"cut": [Rect2i(0, 0, 22, 17)],
		"doors": {"out": 29, "back": 16},
	},
	# The walk, in three legs, meeting at two corners. Up the middle of the hall
	# from the south door, east along the hall's north wall, then up the arm.
	# The turn hugs the wall on purpose: it leaves the whole body of the hall
	# for the fight instead of cutting it in half, and it means the player's
	# route and the room's furniture want opposite parts of the floor.
	"lane": [
		Rect2(246, 342, 54, 234),    # the climb from the south door
		Rect2(246, 288, 262, 54),    # the run east under the north wall
		Rect2(454, 16, 54, 326),     # up the arm to the way out
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
	# DESIGN.md's "densest columns" - twenty-four dividers in four ranks, twice
	# asset recovery's full colonnade, which is what makes this a maze rather
	# than an open plan. All twenty-four are in the HALL: the ranks sit at
	# y 352 / 432 / 512 / 560, which is the body of the room, and the arm is
	# left to its own furniture.
	#
	# The fourth rank is what the hall's south quarter was missing. Three ranks
	# stopped at y 512 and left the last four tile rows of the room as open
	# floor with a bank of desks on it, which is the one part of a maze nobody
	# has to solve. It sits WITH the south desks rather than between them -
	# a foot at 560 against theirs at 552 - because that is what a cubicle farm
	# is: a panel beside every seat, not a wall in the gangway.
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
	"columns": {"rows": [21, 26, 31, 34], "xs": [4, 9, 14, 19, 24, 34]},
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
	"hazard_at": Vector2(208, 334),
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
	# - **Every run stops clear of the walk.** The hall's aisle at y 368 is cut
	#   in two at the lane - the west half ends at 232 and the east half starts
	#   at 312 - exactly as it always was. Splitting an aisle is not a
	#   compromise: it is what DOUBLED the number of runs, and it is most of
	#   what makes the room feel busy.
	# - **The arm's two runs are VERTICAL, and they are the first in the game.**
	#   A corridor's trunking goes along the corridor, and what a player is
	#   doing in the arm is climbing rather than crossing - so these do not cut
	#   the route, they punish drifting off it. They sit 60 px either side of
	#   the lane, at x 392 and x 600, and they run the corridor's whole length:
	#   a climb that got longer with an unwired stretch at the bottom of it is
	#   somewhere to stand and wait, which is the one thing a corridor on this
	#   floor must never be.
	# - **`after` is the only per-run number that is not geometry**, and the
	#   four are spread across the cycle so no two neighbours fire in sequence.
	#   The hall's pair are half a cycle apart, so crossing the hall and
	#   climbing the arm never sound like one machine.
	"surge": {
		"speed": 260.0, "period": 2.4, "charge": 0.5, "damage": 8,
		"runs": [
			{"from": Vector2(24, 368), "to": Vector2(232, 368), "after": 0.0},
			{"from": Vector2(392, 256), "to": Vector2(392, 40), "after": 0.6},
			{"from": Vector2(616, 368), "to": Vector2(312, 368), "after": 1.2},
			{"from": Vector2(600, 40), "to": Vector2(600, 256), "after": 1.8},
		],
	},
	# The stations. Thirteen of them in the pockets the dividers leave, in two
	# ranks across the hall and a third bank up the arm - so the room reads as
	# a grid of identical seats wherever the player is standing, which is the
	# whole of what a call floor looks like and the whole of the joke.
	#
	# Every station is 40 px east of a divider's x, which is half a seat: the
	# panel stands BESIDE the desk rather than behind it, and no body and no
	# desk is ever drawn into a divider it shares a column with.
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
		# The hall, rank by rank. Six seats under the wiring and five along the
		# south wall, where the sofa takes the corner the sixth would have had.
		{"type": "call_desk", "at": Vector2(112, 400)},
		{"type": "chair", "at": Vector2(112, 414)},
		{"type": "call_desk", "at": Vector2(192, 400)},
		{"type": "chair", "at": Vector2(192, 414)},
		{"type": "call_desk", "at": Vector2(352, 400)},
		{"type": "chair", "at": Vector2(352, 414)},
		{"type": "call_desk", "at": Vector2(432, 400)},
		{"type": "chair", "at": Vector2(432, 414)},
		{"type": "call_desk", "at": Vector2(512, 400)},
		{"type": "chair", "at": Vector2(512, 414)},
		{"type": "call_desk", "at": Vector2(592, 400)},
		{"type": "chair", "at": Vector2(592, 414)},
		{"type": "call_desk", "at": Vector2(112, 552)},
		{"type": "chair", "at": Vector2(112, 566)},
		{"type": "call_desk", "at": Vector2(192, 552)},
		{"type": "chair", "at": Vector2(192, 566)},
		{"type": "call_desk", "at": Vector2(352, 552)},
		{"type": "chair", "at": Vector2(352, 566)},
		{"type": "call_desk", "at": Vector2(432, 552)},
		{"type": "chair", "at": Vector2(432, 566)},
		{"type": "call_desk", "at": Vector2(512, 552)},
		{"type": "chair", "at": Vector2(512, 566)},
		# The board, in the stretch of the hall's north wall the player walks
		# the whole length of on the way to the arm, where the floor can see it
		# all day.
		{"type": "wallboard", "at": Vector2(92, 290)},
		# And the other thing this company communicates by: a sheet of A4. One
		# at the turn, one at the top of the arm - the last thing anybody reads
		# before the stairs - and one over the arm's own bank.
		{"type": "notice", "at": Vector2(176, 292)},
		{"type": "notice", "at": Vector2(400, 18)},
		{"type": "notice", "at": Vector2(540, 18)},
		# The north-east pocket, where the hall opens into the arm. It is 116 px
		# wide with a divider standing in it, so it takes what the north strip
		# takes - the thin things - and the arm's own bank supplies the seats
		# 56 px above it.
		{"type": "printer", "at": Vector2(604, 312)},
		{"type": "dead_plant", "at": Vector2(612, 344)},
		{"type": "cooler", "at": Vector2(40, 312)},
		# The corners the ranks do not reach.
		{"type": "table", "at": Vector2(40, 552)},
		{"type": "sofa", "at": Vector2(596, 552)},
		{"type": "plant", "at": Vector2(32, 480)},
		{"type": "plant", "at": Vector2(612, 500)},
		# THE ARM, and it is the reason this list grew. It is not a corridor -
		# it is 272 px square, a quarter of the floor, and dressed as a corridor
		# it was a quarter of the floor with three things in it. So it is what
		# an annex on a call floor actually is: the overflow room. Two more
		# stations down its east side, facing the lane, with the aisle the east
		# run of wiring burns along behind them - and the junk that ends up in
		# the half of a room nobody is seated in down the west side.
		#
		# Everything here is placed against two lines that are not walls: the
		# lane at x 454-508, and the two runs of trunking at x 392 and x 600.
		# A prop standing on a run would hide the conduit under it, and the
		# conduit is the only warning that run gives.
		{"type": "call_desk", "at": Vector2(560, 176)},
		{"type": "chair", "at": Vector2(560, 190)},
		{"type": "call_desk", "at": Vector2(560, 256)},
		{"type": "chair", "at": Vector2(560, 270)},
		{"type": "pc_tower", "at": Vector2(614, 88)},
		{"type": "toolbox", "at": Vector2(612, 152)},
		{"type": "cooler", "at": Vector2(376, 120)},
		{"type": "toolbox", "at": Vector2(378, 232)},
		{"type": "scrap_pile", "at": Vector2(430, 80)},
		{"type": "cable_spool", "at": Vector2(428, 160)},
		{"type": "debris", "at": Vector2(430, 240)},
		# And the litter of the hall, in the gaps the ranks leave.
		{"type": "debris", "at": Vector2(32, 392)},
		{"type": "debris", "at": Vector2(208, 470)},
		{"type": "scrap_pile", "at": Vector2(344, 470)},
		{"type": "crt_stack", "at": Vector2(472, 440)},
		{"type": "debris", "at": Vector2(496, 520)},
		{"type": "toolbox", "at": Vector2(168, 520)},
		{"type": "debris", "at": Vector2(368, 500)},
	],
	# Two slowers in the pockets the dividers make, and seven boys around them.
	# Every one of the nine is either off the divider xs (72 / 152 / 232 / 312 /
	# 392 / 552) or clear of the 48 px a panel covers above its foot, which is
	# the mistake this floor offers twenty-four chances to make.
	#
	# This is the floor where being slowed near a guard is the lesson, so the
	# pair is the point and must not be trimmed: DESIGN.md's escape hatch for
	# this room's weight is one office boy, never a call_center.
	#
	# **They are spread over the room rather than knotted in the middle of it.**
	# Nine bodies in two tight clumps left the hall's north and south thirds
	# empty, and an empty third of a room is a third of a room the player walks
	# through deciding nothing. Each slower still has boys inside its own reach,
	# so the floor's sentence - slowed, and then swung at - happens without the
	# player getting to pick the order; what moved is everything else, out to
	# the corners the ranks were already dressed into.
	#
	# Where they can BE is arithmetic, not taste. A body clears the walk by its
	# own sight, and this floor's walk is three legs: west of the hall that is
	# x <= 166 for a boy and x <= 116 for a slower, at any depth - so the
	# north-west pocket is legal and was simply never used. East of it the leg
	# along the north wall costs a body 80 px of depth as well, which is why
	# nobody stands east of the lane above y 422 except at x >= 588, where the
	# room is past the end of that leg. They also keep off the hall's surge
	# aisle at y 368: a hazard that clears the room for you is a hazard doing
	# the player's job.
	"enemies": [
		# The north-west, which the player sees first and reaches last - the
		# corner the old arrangement left empty all the way to the ceiling.
		{"type": "office_boy", "at": Vector2(44, 300)},
		{"type": "office_boy", "at": Vector2(124, 316)},
		# The west knot, in the body of the hall - the half the player walks
		# INTO, and the one the turn puts behind them.
		{"type": "call_center", "at": Vector2(100, 448)},
		{"type": "office_boy", "at": Vector2(40, 452)},
		{"type": "office_boy", "at": Vector2(120, 504)},
		# The east knot, under the mouth of the arm, so the climb is made with
		# this one still standing.
		{"type": "call_center", "at": Vector2(472, 496)},
		{"type": "office_boy", "at": Vector2(516, 470)},
		{"type": "office_boy", "at": Vector2(440, 540)},
		# And the one at the turn's own shoulder, east of the lane and past the
		# end of the leg that runs along the north wall.
		{"type": "office_boy", "at": Vector2(592, 320)},
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
	"relief": {"npc": "ivan", "from": "start", "at": Vector2(208, 448),
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
