extends SceneTree
## Keeps a generated file's identifiers stable across regenerations, so a
## re-run with unchanged data produces a byte-identical file and git diff
## shows only real changes.
##
## Two identifiers churn without this. ResourceSaver mints a random per-node
## unique_id every time a scene is packed, so a regenerated .tscn rewrote
## every [node] line even when nothing about the room changed; stabilize()
## re-derives each one from (file, parent, name), and the engine preserves
## ids it finds on load, so the editor never re-rolls them afterwards either.
## And a headless save DROPS the uid="uid://..." the editor stamps into a
## header it finds bare, so editor and generator took turns rewriting every
## file's first line; uid_of() captures it before the save overwrites it and
## stabilize() splices it back.
##
## The generators call the statics around every save (build_levels._pack,
## build_biomes._save). Run this file itself to normalize what is already on
## disk without regenerating it - a one-off after this fix, or after an
## engine upgrade re-rolls something:
##   godot --headless --path . --script res://tools/stable_ids.gd

const LEVELS_DIR := "res://game/levels"


## The uid the file at path currently declares, "" when it has none or does
## not exist yet. Capture BEFORE saving over it - the save is what loses it.
static func uid_of(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var head := f.get_line()
	f.close()
	var found := RegEx.create_from_string("uid=\"(uid://[^\"]*)\"").search(head)
	return "" if found == null else found.get_string(1)


## Rewrites the freshly saved file at path in place: the kept uid back into
## its header, and every node's unique_id to a hash of path|parent|name.
static func stabilize(path: String, keep_uid: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	var lines := text.split("\n")
	if lines.size() == 0:
		return
	if keep_uid != "" and not lines[0].contains("uid=\""):
		lines[0] = lines[0].trim_suffix("]") + " uid=\"%s\"]" % keep_uid
	var name_re := RegEx.create_from_string("name=\"([^\"]*)\"")
	var parent_re := RegEx.create_from_string("parent=\"([^\"]*)\"")
	var id_re := RegEx.create_from_string("unique_id=[0-9]+")
	var used := {}
	for i in lines.size():
		var line: String = lines[i]
		if not line.begins_with("[node ") or id_re.search(line) == null:
			continue
		var name := name_re.search(line)
		var parent := parent_re.search(line)
		var key := "%s|%s|%s" % [path,
				"" if parent == null else parent.get_string(1),
				"" if name == null else name.get_string(1)]
		var id := key.hash() & 0x7FFFFFFF
		while id == 0 or used.has(id):
			id = (id + 1) & 0x7FFFFFFF
		used[id] = true
		lines[i] = id_re.sub(line, "unique_id=%d" % id)
	var out := "\n".join(lines)
	if out == text:
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(out)
	f.close()


## Standalone entry point: normalize every level scene already on disk.
func _initialize() -> void:
	var count := 0
	for path in _scenes(LEVELS_DIR):
		stabilize(path, uid_of(path))
		count += 1
	print("normalized ", count, " scenes under ", LEVELS_DIR)
	quit(0)


static func _scenes(dir: String) -> PackedStringArray:
	var found := PackedStringArray()
	var d := DirAccess.open(dir)
	if d == null:
		return found
	d.list_dir_begin()
	var entry := d.get_next()
	while entry != "":
		var path := "%s/%s" % [dir, entry]
		if d.current_is_dir():
			found.append_array(_scenes(path))
		elif entry.ends_with(".tscn"):
			found.append(path)
		entry = d.get_next()
	d.list_dir_end()
	return found
