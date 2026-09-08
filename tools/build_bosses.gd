extends SceneTree
## Generates SpriteFrames for the bosses - one <id>_frames.tres per boss, cut
## from THAT BOSS'S OWN sheet in game/bosses/<id>/src/<id>.png.
##
## Same contract as build_enemies.gd, **seed once, slice always**, with one
## difference in where the seed comes from: an enemy is recoloured from the
## frozen CC0 body, while a boss is a body of its own, so its seed is a painter
## in tools/bosses/<id>.gd that draws every frame from the boss's pose data.
## The painter runs only when the PNG is missing. From then on the sheet is
## hand-owned art: draw into it, re-run this, and only the frames change.
## Delete the PNG to start the boss's art over from the painter.
##
## Nothing is shared between bosses - not a sheet, not a body, not a layout.
## Each roster entry says its own cell size and rows, and the poses each boss
## keeps under game/bosses/<id>/ are what its painter, its frames and its live
## effects all agree on.
##
## Run: godot --headless --path . --script res://tools/build_bosses.gd

const Art := preload("res://tools/character_art.gd")
const Bestiary := preload("res://game/bosses/roster.gd")


func _initialize() -> void:
	var failed := false
	for entry in Bestiary.BOSSES:
		if not _build(entry):
			failed = true
	quit(1 if failed else 0)


func _build(entry: Dictionary) -> bool:
	var id: String = entry["id"]
	var src: String = entry["src"]
	print(id, ":")

	if not FileAccess.file_exists(src):
		var painter := load(entry["painter"]) as GDScript
		if painter == null:
			printerr("  no sheet at %s and no painter at %s" % [src, entry["painter"]])
			return false
		var seeded: Image = painter.paint()
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(src.get_base_dir()))
		var wrote := seeded.save_png(ProjectSettings.globalize_path(src))
		if wrote != OK:
			printerr("  could not write ", src, " -> ", error_string(wrote))
			return false
		print("  seeded ", src, " (hand-owned from here on)")

	var sheet := Image.load_from_file(ProjectSettings.globalize_path(src))
	if sheet == null:
		printerr("  could not read ", src)
		return false
	sheet.convert(Image.FORMAT_RGBA8)

	var frames := Art.slice(sheet, Bestiary.layout_of(entry), Bestiary.specs_of(entry),
		entry["cell"])
	var out: String = entry["frames"]
	var err := ResourceSaver.save(frames, out)
	print("  ", out, " -> ", error_string(err))
	return err == OK
