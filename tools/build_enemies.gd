extends SceneTree
## Generates SpriteFrames for the bestiary - one <id>_frames.tres per enemy,
## cut from THAT ENEMY'S OWN sheet in game/enemies/<id>/src/<id>.png.
##
## Seed once, slice always. The two steps are deliberately different in kind:
##
## - **Seeding** writes the source sheet, and only ever when it is missing. A
##   new enemy's recipe recolours the CC0 body into game/enemies/<id>/src/ to
##   give it something to walk around as on day one.
## - **Slicing** happens every run, on whatever sheet is actually on disk.
##
## So the seed is a starting point, exactly like the level scenes build_levels.gd
## writes, and from the moment it exists the sheet is HAND-OWNED ART. Draw a new
## animation into it, re-run this, and the frames pick it up - the recipe never
## touches it again. Deleting an enemy's PNG and re-running is how you start that
## enemy's art over from the body.
##
## This is why enemies do not share the cast's sheet: the cast will always want
## one animation set, while each enemy is heading somewhere different, and a
## shared sheet would mean every enemy's moves piling up in one file.
##
## An enemy that grows animations the CC0 grid does not have adds a `layout`
## (and if needed `specs`) to its roster entry; without one it uses the CC0
## layout that seeding produced.
##
## Run: godot --headless --path . --script res://tools/build_enemies.gd

const Art := preload("res://tools/character_art.gd")
const Bestiary := preload("res://game/enemies/roster.gd")

## The body a new enemy is seeded from - the same CC0 sheet the cast wears.
const SEED_SRC := "res://game/player/src/character_cc0.png"


func _initialize() -> void:
	var failed := false
	for entry in Bestiary.ENEMIES:
		if not _build(entry):
			failed = true
	quit(1 if failed else 0)


func _build(entry: Dictionary) -> bool:
	var id: String = entry["id"]
	var src: String = entry["src"]
	print(id, ":")

	if not FileAccess.file_exists(src):
		if not entry.has("recipe"):
			printerr("  no sheet at %s and no recipe to seed one from" % src)
			return false
		var seeded := Art.restyle(SEED_SRC, entry["recipe"])
		if seeded == null:
			printerr("  could not load the seed body ", SEED_SRC)
			return false
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(src.get_base_dir()))
		var wrote := seeded.save_png(ProjectSettings.globalize_path(src))
		if wrote != OK:
			printerr("  could not write ", src, " -> ", error_string(wrote))
			return false
		print("  seeded ", src, " (hand-owned from here on)")

	# Always from the file on disk, never from the recipe: whatever has been
	# drawn into that sheet since it was seeded is what the enemy looks like.
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(src))
	if sheet == null:
		printerr("  could not read ", src)
		return false
	sheet.convert(Image.FORMAT_RGBA8)

	var frames := Art.slice(sheet,
		entry.get("layout", Art.DEFAULT_LAYOUT),
		entry.get("specs", Art.DEFAULT_SPECS))
	var out: String = entry["frames"]
	var err := ResourceSaver.save(frames, out)
	print("  ", out, " -> ", error_string(err))
	return err == OK
