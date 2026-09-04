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

const SRC := "res://game/player/src/character_cc0.png"


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
		var frames := Art.slice(sheet, Art.DEFAULT_LAYOUT, Art.DEFAULT_SPECS)
		var err := ResourceSaver.save(frames, out)
		print("saved ", out, " -> ", error_string(err))
		if err != OK:
			failed = true
	quit(1 if failed else 0)
