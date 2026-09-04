extends SceneTree
## Generates SpriteFrames for the playable cast - one <id>_frames.tres per
## roster recipe, all restyled from the one pristine CC0 sheet in
## game/player/src/.
##
## The cast sharing a sheet is deliberate and permanent: every character plays
## the same game with the same moves, so they will always want the same
## animation set, and a new move drawn once lands on all seven at no cost.
## Enemies are the opposite case and have their own generator - see
## tools/build_enemies.gd.
##
## Run: godot --headless --path . --script res://tools/build_characters.gd

const Art := preload("res://tools/character_art.gd")
const Roster := preload("res://game/player/characters/roster.gd")

## The cast's sheet. Living art: unlike the frozen body enemies are seeded from
## (game/enemies/src/body_cc0.png), this one is meant to grow.
const SRC := "res://game/player/src/character_cc0.png"

## What the cast's sheet holds, and the ONE place to edit when it grows.
##
## Deliberately the cast's own copy rather than character_art.gd's CC0_LAYOUT,
## even though the two are identical today. They describe different things: that
## one is a fact about a frozen file, this one is a description of art under
## active development. Draw a new row into the sheet, add it here, and the seven
## characters pick it up with nothing else in the game moving - which is exactly
## what sharing one constant would have prevented.
const CAST_LAYOUT := {
	"down": {"idle": 0, "walk": 1, "attack": 6, "attack2": 9,
		"charge": 12, "heavy": 15, "wildfire": 18},
	"up": {"idle": 2, "walk": 3, "attack": 7, "attack2": 10,
		"charge": 13, "heavy": 16, "wildfire": 19},
	"side": {"idle": 4, "walk": 5, "attack": 8, "attack2": 11,
		"charge": 14, "heavy": 17, "wildfire": 20},
}
const CAST_SPECS := {
	"idle": {"frames": 1, "fps": 1.0, "loop": true},
	"walk": {"frames": 4, "fps": 10.0, "loop": true},
	"attack": {"frames": 4, "fps": 14.0, "loop": false},
	"attack2": {"frames": 4, "fps": 14.0, "loop": false},
	"charge": {"frames": 2, "fps": 5.0, "loop": true},
	"heavy": {"frames": 4, "fps": 14.0, "loop": false},
	"wildfire": {"frames": 4, "fps": 14.0, "loop": false},
}


func _initialize() -> void:
	var failed := false
	for entry in Roster.CHARACTERS:
		if not entry.has("recipe"):
			continue
		var sheet := Art.restyle(SRC, entry["recipe"])
		if sheet == null:
			printerr("Could not load ", SRC)
			quit(1)
			return
		var out: String = entry["frames"]
		var frames := Art.slice(sheet, CAST_LAYOUT, CAST_SPECS)
		var err := ResourceSaver.save(frames, out)
		print("saved ", out, " -> ", error_string(err))
		if err != OK:
			failed = true
	quit(1 if failed else 0)
