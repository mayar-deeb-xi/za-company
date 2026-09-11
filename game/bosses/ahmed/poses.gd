extends RefCounted
## Ahmed's body and every pose he strikes, as data. Read by two things that
## must agree pixel for pixel: tools/bosses/ahmed.gd, which PAINTS the sheet
## from it (the body, the arm, the axe), and axe_fire.gd, which draws the fire
## live in the game from the same hand positions, so the flame is always on
## the blade the sheet actually drew.
##
## Coordinates are BODY coordinates: column 0..13 across, row 0..34 down, row
## 34 the soles of his shoes. Anything the fire needs in world terms goes
## through `local()`, which puts the origin between his feet.
##
## Each animation is a list of frames. A frame carries:
##   dur     seconds it holds
##   phase   "w" wind-up / "s" strike / "r" recover / "i" neither - the boss
##           script derives windup_seconds and recover_seconds from these, so
##           the telegraph and the animation cannot drift apart
##   impact  true on the one frame the blow lands
##   legs    which LEGS variant (see below - its ROW COUNT is the drop)
##   dx/dy   dx slides him; dy lowers the BODY onto its legs, which stay on
##           the floor. dy must equal 7 - the leg variant's rows, or he
##           splits at the hips.
##   lift    both feet off the ground - moves body AND legs together
##   arms    [{sh: "front"|"back", hand: Vector2i, bend, behind}]
##   axe     {hand: Vector2i, ang: degrees, len, blade: 1|-1, behind}
##   glow    how big the fire on the blade is (0 = out)
##   fx      fire drawn in the air, over the body   } descriptors, read by
##   floor   fire drawn on the floor, under the body } axe_fire.gd

const PAL := {
	"#": "0d0b0d", "H": "1c181c", "h": "342d36", "G": "cfcbd4", "b": "26202a",
	"s": "efd9c4", "t": "d2b399", "e": "1a1216",
	"W": "f5f5f3", "w": "c7c8cf", "P": "2b2b33", "p": "191920", "K": "111114",
	"O": "8a5a2e", "o": "5a381c", "A": "c3cbd3", "a": "7a848e", "X": "f2f6f8",
	# The fire ramp, core to tip, and the scorch it leaves.
	"1": "fff3b0", "2": "ffb63a", "3": "ff6a2a", "4": "c8301c", "5": "5a1a14",
}

## Rows 0-27: head, beard, torso. The legs are separate so the walk can swap
## them. Side view, facing right; the game flips it for left.
const TOP := [
	".....######.....",
	"...##HHGHHH##...",
	"..#HGHHHHHHhH#..",
	".#HHHHHHHHHHH#..",
	".#HGHHHHHHHHH#..",
	"..#HHhHHHHHHH#..",
	"..#HHGHHHsssss#.",
	".#HHHHHHssssss#.",
	".#HGHHHHsssees#.",
	"..#HHHHHsssees#.",
	".#HHGHHHssssss#.",
	".#HHHHHHssssstt#",
	"..#HGHHHssssss#.",
	".#HHHHHHbssbbb#.",
	".#HGHHHHbbbbbb#.",
	"..#HHHHHbbbbbb#.",
	".#HHGHHH#bbbbb#.",
	"..#HHHHH#bbbb#..",
	"..#WHHHH#bbb#...",
	"..#WwHHH#bb#....",
	"..#WwHHWb#......",
	"..#WwHHWW#......",
	"..#WwWWWW#......",
	"..#WwWWWW#......",
	"..#WwWWWW#......",
	"..#WwWWWW#......",
	"..#WwWWWW#......",
	"..#WwWWWW#......",
]

## A variant's last row is ALWAYS row 34, the floor - the painter anchors it
## there and `dy` never moves it. So a block's row count is the body drop it
## pairs with: 7 rows standing (dy 0), 3 rows kneeling (dy 4), and in general
## dy = 7 - rows. Pair them wrong and the torso floats off the legs, which is
## exactly what the shipped kneel did before the anchor was fixed.
const LEGS := {
	"stand": [
		"..#PPPPPP#....",
		"..#PPPPPP#....",
		"..#pPP#PP#....",
		"..#pPP#PP#....",
		"..#pPP#PP#....",
		"..#KKK#KKKK#..",
		"..#####.####..",
	],
	"stride_a": [
		"..#PPPPPP#....",
		".#PPPPPPP#....",
		".#pP#.#PPP#...",
		"#pP#...#PP#...",
		"#pP#....#PP#..",
		"#KKK#...#KKKK#",
		"#####...######",
	],
	"stride_b": [
		"..#PPPPPP#....",
		".#PPPPPPP#....",
		".#PP#.#ppP#...",
		"#PP#...#pp#...",
		"#PP#....#pp#..",
		"#KKK#...#KKKK#",
		"#####...######",
	],
	"brace": [
		"..#PPPPPP#....",
		".#PPPPPPPP#...",
		".#pPP#.#PPP#..",
		"#pPP#...#PP#..",
		"#pP#.....#PPP#",
		"#KKK#....#KKKK#",
		"#####....######",
	],
	# 6 rows, dy 1: the stance widens as the legs start to go.
	"crouch": [
		"..#PPPPPP#....",
		".#pPPPPPPP#...",
		".#pPP#.#PPP#..",
		"#pPP#...#PPP#.",
		"#KKK#...#KKKK#",
		"#####...######",
	],
	# 5 rows, dy 2: down on one knee, the other foot still flat.
	"knee_one": [
		"..#PPPPPP#.....",
		".#pPPPPPPP#....",
		".#pPP#.#PPP#...",
		"#pPP#...#PPPP#.",
		"#KKK#....#KKK#.",
	],
	# 3 rows, dy 4: both knees.
	"kneel": [
		".#PPPPPPPPPP#..",
		"#pPPP#PPPPPPP#.",
		"#KK###KKK#####.",
	],
	# 2 rows, dy 5: the same kneel with the weight settled onto it - one pixel
	# lower, which is the whole of the breath in `beaten`.
	"kneel_low": [
		"#pPPPPPPPPPPP#.",
		"#KK###KKK#####.",
	],
}

const FRONT_SHOULDER := Vector2i(8, 19)
const BACK_SHOULDER := Vector2i(3, 19)

## Sheet order: one row per animation, in this order.
const ORDER := ["idle", "walk", "chop", "sweep", "slam", "wave", "concede", "beaten"]

const ANIMS := {
	"idle": [
		{"dur": 0.15, "arms": [{"sh": "front", "hand": Vector2i(11, 24), "bend": 2}],
			"axe": {"hand": Vector2i(11, 24), "ang": 55.0, "len": 8, "blade": -1}},
	],
	"walk": [
		{"dur": 0.1, "legs": "stride_a", "arms": [{"sh": "front", "hand": Vector2i(12, 24), "bend": 2}],
			"axe": {"hand": Vector2i(12, 24), "ang": 55.0, "len": 8, "blade": -1}},
		{"dur": 0.1, "lift": -1, "arms": [{"sh": "front", "hand": Vector2i(11, 23), "bend": 2}],
			"axe": {"hand": Vector2i(11, 23), "ang": 55.0, "len": 8, "blade": -1}},
		{"dur": 0.1, "legs": "stride_b", "arms": [{"sh": "front", "hand": Vector2i(10, 24), "bend": 2}],
			"axe": {"hand": Vector2i(10, 24), "ang": 55.0, "len": 8, "blade": -1}},
		{"dur": 0.1, "lift": -1, "arms": [{"sh": "front", "hand": Vector2i(11, 23), "bend": 2}],
			"axe": {"hand": Vector2i(11, 23), "ang": 55.0, "len": 8, "blade": -1}},
	],
	# Overhead. Sparks off the raised blade, fire down the haft, then a column
	# of fire out of the floor where it lands and a fissure running on ahead.
	"chop": [
		{"dur": 0.2, "phase": "w", "glow": 1.2, "arms": [{"sh": "front", "hand": Vector2i(9, 4), "bend": -3}],
			"axe": {"hand": Vector2i(9, 4), "ang": -115.0, "len": 12},
			"fx": [["sparks_edge", 4, 4, -3]]},
		{"dur": 0.2, "phase": "w", "glow": 1.6, "arms": [{"sh": "front", "hand": Vector2i(7, -2), "bend": -3}],
			"axe": {"hand": Vector2i(7, -2), "ang": -135.0, "len": 12},
			"fx": [["sparks_edge", 8, 6, -3], ["haft", 2]]},
		{"dur": 0.2, "phase": "w", "glow": 2.2, "dx": 1, "arms": [{"sh": "front", "hand": Vector2i(8, -2), "bend": -3}],
			"axe": {"hand": Vector2i(8, -2), "ang": -135.0, "len": 12},
			"fx": [["sparks_edge", 14, 8, -4], ["haft", 4]]},
		{"dur": 0.07, "phase": "s", "glow": 1.8, "arms": [{"sh": "front", "hand": Vector2i(13, 8), "bend": -3}],
			"axe": {"hand": Vector2i(13, 8), "ang": -35.0, "len": 12},
			"fx": [["trail", -140, -35], ["trail_len", 15, -110, -35], ["haft", 3]]},
		{"dur": 0.08, "phase": "s", "impact": true, "legs": "brace", "glow": 0.6,
			"arms": [{"sh": "front", "hand": Vector2i(14, 22), "bend": 2}],
			"axe": {"hand": Vector2i(14, 22), "ang": 52.0, "len": 12},
			"floor": [["ring", 17, 0, 6.0, 2.5, "flash", "flash_fill"]],
			"fx": [["trail", -35, 45], ["geyser", 17, 0, 18, 5], ["splash", 17, 0, 12], ["sparks", 17, -14, 10, 8]]},
		{"dur": 0.2, "phase": "r", "legs": "brace", "glow": 0.8,
			"arms": [{"sh": "front", "hand": Vector2i(14, 22), "bend": 2}],
			"axe": {"hand": Vector2i(14, 22), "ang": 52.0, "len": 12},
			"floor": [["ring", 17, 0, 11.0, 1.5, "orange", ""]],
			"fx": [["geyser", 17, 0, 11, 4], ["splash", 17, 0, 18], ["fissure", 21, 0, 16, true],
				["sparks", 17, -18, 8, 12], ["scorch", 17, 0, 9, 1.0]]},
		{"dur": 0.2, "phase": "r", "arms": [{"sh": "front", "hand": Vector2i(12, 24), "bend": 2}],
			"axe": {"hand": Vector2i(12, 24), "ang": 55.0, "len": 9, "blade": -1},
			"fx": [["patch", 17, 0, 8, 4], ["fissure", 21, 0, 20, true], ["embers", 25, -6, 6, 10]]},
	],
	# Horizontal. The low blade drags fire across the floor behind him, then
	# the swing throws a crescent of flame that widens and breaks apart.
	"sweep": [
		{"dur": 0.15, "phase": "w", "glow": 1.2, "arms": [{"sh": "front", "hand": Vector2i(3, 24), "bend": 3}],
			"axe": {"hand": Vector2i(3, 24), "ang": -160.0, "len": 12, "behind": true},
			"fx": [["drag", -19, -9, 2]]},
		{"dur": 0.15, "phase": "w", "glow": 1.6, "arms": [{"sh": "front", "hand": Vector2i(2, 23), "bend": 3}],
			"axe": {"hand": Vector2i(2, 23), "ang": -150.0, "len": 12, "behind": true},
			"fx": [["drag", -23, -9, 3], ["sparks", -17, -4, 5, 5]]},
		{"dur": 0.15, "phase": "w", "glow": 2.0, "dx": 1, "arms": [{"sh": "front", "hand": Vector2i(3, 23), "bend": 3}],
			"axe": {"hand": Vector2i(3, 23), "ang": -150.0, "len": 12, "behind": true},
			"fx": [["drag", -25, -9, 4], ["sparks", -17, -6, 9, 7]]},
		{"dur": 0.07, "phase": "s", "glow": 1.8, "arms": [{"sh": "front", "hand": Vector2i(10, 12), "bend": -3}],
			"axe": {"hand": Vector2i(10, 12), "ang": -70.0, "len": 12},
			"fx": [["trail", -160, -70], ["trail_len", 15, -130, -70], ["sparks", -1, -36, 6, 8], ["scorch", -17, 0, 8, 0.6]]},
		{"dur": 0.08, "phase": "s", "impact": true, "legs": "brace", "glow": 1.5,
			"arms": [{"sh": "front", "hand": Vector2i(16, 20), "bend": 2}],
			"axe": {"hand": Vector2i(16, 20), "ang": -5.0, "len": 12},
			"fx": [["trail", -100, -5], ["crescent", 10, -13, 14, 20, -95, 35, 0], ["sparks", 24, -23, 8, 6]]},
		{"dur": 0.15, "phase": "r", "legs": "brace", "arms": [{"sh": "front", "hand": Vector2i(15, 24), "bend": 2}],
			"axe": {"hand": Vector2i(15, 24), "ang": 35.0, "len": 12},
			"fx": [["crescent", 10, -13, 20, 28, -100, 45, 1], ["embers", 32, -19, 10, 10],
				["flame", 32, 0, 4, 3], ["flame", 37, 1, 3, 2], ["scorch", 34, 0, 6, 0.8]]},
		{"dur": 0.15, "phase": "r", "arms": [{"sh": "front", "hand": Vector2i(12, 24), "bend": 2}],
			"axe": {"hand": Vector2i(12, 24), "ang": 55.0, "len": 9, "blade": -1},
			"fx": [["crescent", 10, -13, 27, 35, -105, 50, 2], ["embers", 40, -17, 12, 12],
				["flame", 40, 0, 3, 2], ["scorch", 38, 0, 8, 0.6]]},
	],
	# The area attack. Both hands; a ring of embers creeps out to the full
	# radius over the wind-up and goes up as fire when the axe lands.
	"slam": [
		{"dur": 0.34, "phase": "w", "glow": 1.3,
			"arms": [{"sh": "back", "hand": Vector2i(10, 12), "bend": -3, "behind": true}, {"sh": "front", "hand": Vector2i(10, 12), "bend": -4}],
			"axe": {"hand": Vector2i(10, 12), "ang": -95.0, "len": 12},
			"floor": [["ring", 0, -1, 12.0, 1.2, "ember", "ember_fill"]]},
		{"dur": 0.33, "phase": "w", "glow": 1.6, "lift": -1,
			"arms": [{"sh": "back", "hand": Vector2i(9, 6), "bend": -3, "behind": true}, {"sh": "front", "hand": Vector2i(9, 6), "bend": -4}],
			"axe": {"hand": Vector2i(9, 6), "ang": -90.0, "len": 12},
			"floor": [["ring", 0, -1, 24.8, 1.2, "ember", "ember_fill"]],
			"fx": [["embers", 0, -1, 6, 22]]},
		{"dur": 0.33, "phase": "w", "glow": 2.0, "lift": -3, "dx": 1, "legs": "brace",
			"arms": [{"sh": "back", "hand": Vector2i(9, 2), "bend": -3, "behind": true}, {"sh": "front", "hand": Vector2i(9, 2), "bend": -4}],
			"axe": {"hand": Vector2i(9, 2), "ang": -88.0, "len": 12},
			"floor": [["ring", 0, -1, 38.0, 1.4, "hot", "ember_fill"]],
			"fx": [["embers", 0, -1, 10, 34]]},
		{"dur": 0.1, "phase": "s", "impact": true, "legs": "brace",
			"arms": [{"sh": "back", "hand": Vector2i(12, 22), "bend": 2, "behind": true}, {"sh": "front", "hand": Vector2i(12, 22), "bend": 3}],
			"axe": {"hand": Vector2i(12, 22), "ang": 72.0, "len": 9},
			"floor": [["ring", 0, -1, 7.0, 3.0, "flash", "flash_fill"]],
			"fx": [["burst", 10, -1, 1.2]]},
		{"dur": 0.1, "phase": "s", "legs": "brace",
			"arms": [{"sh": "back", "hand": Vector2i(12, 22), "bend": 2, "behind": true}, {"sh": "front", "hand": Vector2i(12, 22), "bend": 3}],
			"axe": {"hand": Vector2i(12, 22), "ang": 72.0, "len": 9},
			"floor": [["ring", 0, -1, 20.0, 2.5, "orange", "orange_fill"], ["cracks", 0, -1, 20.0, "crack_hot"]],
			"fx": [["pillars", 20, 7], ["burst", 10, -1, 0.8]]},
		{"dur": 0.18, "phase": "r", "legs": "brace",
			"arms": [{"sh": "back", "hand": Vector2i(12, 22), "bend": 2, "behind": true}, {"sh": "front", "hand": Vector2i(12, 22), "bend": 3}],
			"axe": {"hand": Vector2i(12, 22), "ang": 72.0, "len": 9},
			"floor": [["ring", 0, -1, 32.0, 2.0, "fire", "fire_fill"], ["cracks", 0, -1, 28.0, "crack_warm"]],
			"fx": [["pillars", 32, 9], ["embers", 0, -5, 12, 30]]},
		{"dur": 0.18, "phase": "r", "legs": "brace",
			"arms": [{"sh": "back", "hand": Vector2i(12, 22), "bend": 2, "behind": true}, {"sh": "front", "hand": Vector2i(12, 22), "bend": 3}],
			"axe": {"hand": Vector2i(12, 22), "ang": 72.0, "len": 9},
			"floor": [["ring", 0, -1, 40.0, 1.5, "fire_dim", ""], ["cracks", 0, -1, 28.0, "crack_dim"]],
			"fx": [["pillars", 40, 6], ["embers", 0, -7, 8, 36]]},
		{"dur": 0.17, "phase": "r", "legs": "brace", "arms": [{"sh": "front", "hand": Vector2i(13, 21), "bend": 2}],
			"axe": {"hand": Vector2i(13, 21), "ang": 60.0, "len": 10},
			"floor": [["ring", 0, -1, 40.0, 1.2, "dim", ""], ["cracks", 0, -1, 24.0, "crack_out"]],
			"fx": [["pillars", 40, 3]]},
		{"dur": 0.17, "phase": "r", "arms": [{"sh": "front", "hand": Vector2i(12, 24), "bend": 2}],
			"axe": {"hand": Vector2i(12, 24), "ang": 55.0, "len": 9, "blade": -1},
			"floor": [["ring", 0, -1, 40.0, 1.0, "scorch", ""]]},
	],
	# Ranged. The blade is charged over the wind-up, then brought down; the
	# fire keeps going as a wave along the floor.
	"wave": [
		{"dur": 0.23, "phase": "w", "glow": 1.4, "arms": [{"sh": "front", "hand": Vector2i(8, 6), "bend": -3}],
			"axe": {"hand": Vector2i(8, 6), "ang": -80.0, "len": 12}},
		{"dur": 0.23, "phase": "w", "glow": 2.0, "arms": [{"sh": "front", "hand": Vector2i(8, 4), "bend": -3}],
			"axe": {"hand": Vector2i(8, 4), "ang": -85.0, "len": 12},
			"fx": [["embers", 5, -38, 6, 6]]},
		{"dur": 0.24, "phase": "w", "glow": 2.6, "dx": 1, "arms": [{"sh": "front", "hand": Vector2i(9, 4), "bend": -3}],
			"axe": {"hand": Vector2i(9, 4), "ang": -85.0, "len": 12},
			"fx": [["embers", 6, -40, 10, 8]]},
		{"dur": 0.08, "phase": "s", "impact": true, "legs": "brace", "arms": [{"sh": "front", "hand": Vector2i(14, 22), "bend": 2}],
			"axe": {"hand": Vector2i(14, 22), "ang": 52.0, "len": 12},
			"fx": [["trail", -85, 45], ["burst", 13, 0, 1.3]]},
		{"dur": 0.07, "phase": "s", "legs": "brace", "arms": [{"sh": "front", "hand": Vector2i(14, 22), "bend": 2}],
			"axe": {"hand": Vector2i(14, 22), "ang": 52.0, "len": 12},
			"fx": [["wave", 13, 31]]},
		{"dur": 0.07, "phase": "s", "legs": "brace", "arms": [{"sh": "front", "hand": Vector2i(14, 22), "bend": 2}],
			"axe": {"hand": Vector2i(14, 22), "ang": 52.0, "len": 12},
			"fx": [["wave", 13, 49]]},
		{"dur": 0.08, "phase": "s", "legs": "brace", "arms": [{"sh": "front", "hand": Vector2i(14, 22), "bend": 2}],
			"axe": {"hand": Vector2i(14, 22), "ang": 52.0, "len": 12},
			"fx": [["wave", 13, 67]]},
		{"dur": 0.25, "phase": "r", "legs": "brace", "arms": [{"sh": "front", "hand": Vector2i(13, 21), "bend": 2}],
			"axe": {"hand": Vector2i(13, 21), "ang": 60.0, "len": 10},
			"fx": [["wave_scorch", 13, 60, 0.7], ["flame", 75, 0, 4, 3], ["flame", 43, 1, 3, 2]]},
		{"dur": 0.25, "phase": "r", "arms": [{"sh": "front", "hand": Vector2i(12, 24), "bend": 2}],
			"axe": {"hand": Vector2i(12, 24), "ang": 55.0, "len": 9, "blade": -1},
			"fx": [["wave_scorch", 13, 60, 0.4]]},
	],
	# Bosses concede rather than die, and Ahmed lets go of the axe to do it:
	# he straightens up one last time, his fingers open, the axe drops and
	# lands flat, and the fire goes out the moment it leaves his hand. The
	# axe is drawn wherever its descriptor says regardless of where the arm
	# is, so a dropped axe costs nothing - it is just a hand that stopped
	# following it. With nothing left to hold, the far arm comes into view
	# and both hands end up on his thighs.
	"concede": [
		{"dur": 0.16, "legs": "brace", "glow": 0.6, "arms": [{"sh": "front", "hand": Vector2i(11, 23), "bend": 2}],
			"axe": {"hand": Vector2i(11, 23), "ang": 55.0, "len": 9, "blade": -1}},
		{"dur": 0.1, "legs": "brace", "glow": 0.45, "arms": [{"sh": "front", "hand": Vector2i(11, 25), "bend": 1}],
			"axe": {"hand": Vector2i(11, 25), "ang": 35.0, "len": 9, "blade": -1},
			"fx": [["embers", 7, -9, 3, 3]]},
		{"dur": 0.08, "dy": 1, "legs": "crouch", "glow": 0.2, "arms": [{"sh": "front", "hand": Vector2i(10, 27), "bend": 0}],
			"axe": {"hand": Vector2i(13, 29), "ang": 10.0, "len": 9, "blade": -1},
			"fx": [["embers", 8, -6, 4, 4]]},
		{"dur": 0.08, "dy": 1, "legs": "crouch", "glow": 0.05, "arms": [{"sh": "front", "hand": Vector2i(10, 28), "bend": 0}],
			"axe": {"hand": Vector2i(15, 32), "ang": -4.0, "len": 9, "blade": -1},
			"fx": [["sparks", 11, -1, 6, 4]]},
		{"dur": 0.14, "dy": 2, "legs": "knee_one", "glow": 0.0, "arms": [{"sh": "front", "hand": Vector2i(10, 30), "bend": 1}],
			"axe": {"hand": Vector2i(16, 32), "ang": 0.0, "len": 9, "blade": -1},
			"fx": [["scorch", 16, 0, 5, 0.5], ["embers", 16, -2, 3, 3]]},
		{"dur": 0.16, "dy": 4, "legs": "kneel", "glow": 0.0, "arms": [{"sh": "front", "hand": Vector2i(9, 31), "bend": 2}],
			"axe": {"hand": Vector2i(16, 32), "ang": 0.0, "len": 9, "blade": -1},
			"fx": [["scorch", 16, 0, 5, 0.45]]},
		{"dur": 0.35, "dy": 4, "legs": "kneel", "glow": 0.0,
			"arms": [{"sh": "back", "hand": Vector2i(2, 32), "bend": 2}, {"sh": "front", "hand": Vector2i(9, 31), "bend": 2}],
			"axe": {"hand": Vector2i(16, 32), "ang": 0.0, "len": 9, "blade": -1},
			"fx": [["scorch", 16, 0, 5, 0.4], ["smoke", 19, -3]]},
	],
	# What he does for the rest of the run: breathe. One row cannot loop only
	# its last two frames, so the breath is a row of its own that ahmed.gd
	# plays when the concede finishes. One pixel of rise and fall - the whole
	# difference is kneel (dy 4) against kneel_low (dy 5).
	"beaten": [
		{"dur": 0.7, "dy": 4, "legs": "kneel", "glow": 0.0,
			"arms": [{"sh": "back", "hand": Vector2i(2, 32), "bend": 2}, {"sh": "front", "hand": Vector2i(9, 31), "bend": 2}],
			"axe": {"hand": Vector2i(16, 32), "ang": 0.0, "len": 9, "blade": -1},
			"fx": [["scorch", 16, 0, 5, 0.4], ["smoke", 19, -4]]},
		{"dur": 0.7, "dy": 5, "legs": "kneel_low", "glow": 0.0,
			"arms": [{"sh": "back", "hand": Vector2i(2, 33), "bend": 2}, {"sh": "front", "hand": Vector2i(9, 32), "bend": 2}],
			"axe": {"hand": Vector2i(16, 32), "ang": 0.0, "len": 9, "blade": -1},
			"fx": [["scorch", 16, 0, 5, 0.4], ["smoke", 20, -6]]},
	],
}

## Which animations loop. Every attack plays once and holds its last frame;
## so does the concede - but it hands off to `beaten`, which loops for good.
const LOOPS := {"idle": true, "walk": true, "beaten": true}

## Base speed the sheet is sliced at; each frame's `dur` becomes a duration
## multiplier on it, so the sheet carries the attack's own timing.
const FPS := 10.0


## Body column/row to the boss's local space: origin between the feet, one
## unit one game pixel.
static func local(c: float, r: float) -> Vector2:
	return Vector2(c - 7.0, r - 34.0)


## Seconds from the first frame to the blow: the wind-up the boss script runs.
static func windup_of(anim: String) -> float:
	var total := 0.0
	for frame in ANIMS[anim]:
		if frame.get("impact", false):
			return total
		total += frame["dur"]
	return total


## Everything after the blow: the recover the boss script runs.
static func recover_of(anim: String) -> float:
	return length_of(anim) - windup_of(anim)


## Seconds an animation still has fire on the blade: everything before the
## first frame whose `glow` is out. Derived here beside the wind-up and the
## recover, and for the same reason - the fire's sound fades over exactly the
## span the fire is drawn for, so retiming the concede takes both with it.
static func glow_out_of(anim: String) -> float:
	var total := 0.0
	for frame in ANIMS[anim]:
		if frame.get("glow", 0.0) <= 0.0:
			return total
		total += frame["dur"]
	return total


static func length_of(anim: String) -> float:
	var total := 0.0
	for frame in ANIMS[anim]:
		total += frame["dur"]
	return total


## The frame index playing `seconds` into an animation, for anything that has
## to know which picture is up without asking the sprite.
static func frame_at(anim: String, seconds: float) -> int:
	var acc := 0.0
	var frames: Array = ANIMS[anim]
	for i in frames.size():
		acc += frames[i]["dur"]
		if seconds < acc:
			return i
	return frames.size() - 1
