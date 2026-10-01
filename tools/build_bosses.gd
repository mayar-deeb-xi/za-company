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
## A boss that gains an animation after his sheet was seeded gets it the way
## the cast got its arc (tools/arc_pose.gd): the painter paints ONLY the rows
## the PNG is too short to hold, onto the end, and never touches a row already
## there. So a new row goes LAST in that boss's ORDER - anywhere else and it
## would land on a row somebody may have drawn into. See `_extend`.
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
	sheet = _extend(entry, sheet)
	if sheet == null:
		return false

	var frames := Art.slice(sheet, Bestiary.layout_of(entry), Bestiary.specs_of(entry),
		entry["cell"])
	var out: String = entry["frames"]
	var err := ResourceSaver.save(frames, out)
	print("  ", out, " -> ", error_string(err))
	return err == OK


## The sheet, grown by whatever rows the painter has that it does not. Returns
## it unchanged when it is already tall enough, which is every run but the one
## after a row is added; null if the grown sheet could not be written back.
func _extend(entry: Dictionary, sheet: Image) -> Image:
	var painter := load(entry["painter"]) as GDScript
	if painter == null:
		return sheet
	var painted: Image = painter.paint()
	if painted.get_height() <= sheet.get_height():
		return sheet
	var old_h := sheet.get_height()
	var grown := Image.create(maxi(sheet.get_width(), painted.get_width()),
		painted.get_height(), false, Image.FORMAT_RGBA8)
	grown.blit_rect(sheet, Rect2i(Vector2i.ZERO, sheet.get_size()), Vector2i.ZERO)
	grown.blit_rect(painted, Rect2i(0, old_h, painted.get_width(),
		painted.get_height() - old_h), Vector2i(0, old_h))
	var src: String = entry["src"]
	var wrote := grown.save_png(ProjectSettings.globalize_path(src))
	if wrote != OK:
		printerr("  could not grow ", src, " -> ", error_string(wrote))
		return null
	print("  painted rows %d-%d onto the end of %s (rows above untouched)"
		% [old_h / int(entry["cell"]), painted.get_height() / int(entry["cell"]) - 1, src])
	return grown
