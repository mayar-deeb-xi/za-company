extends RefCounted
## The bosses. One entry per boss: id, its own sheet, where its baked
## SpriteFrames go, the painter that SEEDS the sheet, and the pose data the
## painter, the frames and the live effects all read.
##
## **Nothing is shared between bosses.** Each has its own `src` PNG (hand-owned
## from the moment tools/build_bosses.gd writes it), its own poses under
## game/bosses/<id>/, its own painter under tools/bosses/, and its own cell
## size. The three bosses are heading three different places - an axe, a pair
## of gloves, a man adjusting his cuffs - and a shared body would mean every
## one of them carrying the others' frames.
##
## A boss draws only the side profile; the game flips it for left. Its layout
## is therefore one direction with one row per animation, in `ORDER`, and its
## timing lives in the poses: each frame's `dur` becomes a per-frame duration
## in the SpriteFrames, so the sheet plays the attack at the speed the boss
## script runs it.
##
## Stats (health, damage, speed, reach) are @exports on the boss scripts, set
## per scene, like every enemy.

const BOSSES := [
	{
		"id": "ahmed",
		"src": "res://game/bosses/ahmed/src/ahmed.png",
		"frames": "res://game/bosses/ahmed/ahmed_frames.tres",
		"painter": "res://tools/bosses/ahmed.gd",
		"poses": preload("res://game/bosses/ahmed/poses.gd"),
		"cell": 64,
	},
	{
		"id": "mostafa",
		"src": "res://game/bosses/mostafa/src/mostafa.png",
		"frames": "res://game/bosses/mostafa/mostafa_frames.tres",
		"painter": "res://tools/bosses/mostafa.gd",
		"poses": preload("res://game/bosses/mostafa/poses.gd"),
		# Twice Ahmed's, because Mostafa is drawn at 2x DENSITY - 70 source rows
		# across the same 35 world px, where Ahmed spends 35. His scene halves
		# it back with scale 0.5, so the two bosses stand the same height in the
		# room and only Mostafa's pixels are finer. The entry is per boss for
		# exactly this reason: nothing about the art is shared.
		"cell": 128,
	},
]


## {"side": {anim: row}} - one row per animation, in the poses' sheet order.
static func layout_of(entry: Dictionary) -> Dictionary:
	var poses: GDScript = entry["poses"]
	var rows := {}
	var order: Array = poses.ORDER
	for i in order.size():
		rows[order[i]] = i
	return {"side": rows}


## Per-animation frame counts, speed, looping and per-frame durations, all
## read off the poses so the sheet and the script cannot disagree.
static func specs_of(entry: Dictionary) -> Dictionary:
	var poses: GDScript = entry["poses"]
	var specs := {}
	for anim in poses.ORDER:
		var frames: Array = poses.ANIMS[anim]
		var durations: Array = []
		for f in frames:
			durations.append(f["dur"] * poses.FPS)
		specs[anim] = {
			"frames": frames.size(),
			"fps": poses.FPS,
			"loop": poses.LOOPS.get(anim, false),
			"durations": durations,
		}
	return specs
