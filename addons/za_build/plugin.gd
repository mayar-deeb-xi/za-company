@tool
extends EditorPlugin
## Project > Tools > za-build: the generators in tools/, as menu items.
##
## Every item does exactly what the terminal does - spawns a headless Godot on
## this project and runs one script under tools/ - rather than calling the
## generator inside the editor's own process. That is a deliberate choice about
## the resource cache, not a shortcut around refactoring.
##
## build_levels.gd rewrites .tscn files the editor may currently have open, and
## an editor holding a stale copy of one will write it back over the fresh one.
## That has already cost this project files. A child process has its own cache
## and cannot do it; when it exits, a filesystem scan is what makes the editor
## notice what changed on disk. It also keeps tools/ honestly headless-only,
## which is what the root CLAUDE.md says those scripts are.
##
## The editor blocks while a build runs, because the output is worth having:
## OS.execute is synchronous and its stdout goes to the Output panel.

const Biomes := preload("res://tools/biomes.gd")
const LevelPicker := preload("res://addons/za_build/level_picker.gd")

const MENU := "za-build"

## The generators that take no arguments, in the order they belong in the menu.
## build_levels.gd is deliberately NOT here: which levels to name is the one
## real choice its command line makes you make, so it goes through the picker.
const PLAIN := [
	["Rebuild biome art (tilesets + doorways)", "res://tools/build_biomes.gd"],
	["Rebuild character frames", "res://tools/build_characters.gd"],
	["Rebuild enemy frames", "res://tools/build_enemies.gd"],
	["Rebuild the UI theme", "res://tools/build_ui_theme.gd"],
	["Re-apply project settings", "res://tools/setup_project.gd"],
]

var _menu: PopupMenu
var _actions := {}


func _enter_tree() -> void:
	_menu = PopupMenu.new()
	_add("Rebuild levels...", _pick_levels)
	_menu.add_separator()
	for entry: Array in PLAIN:
		var path: String = entry[1]
		_add(entry[0], func() -> void: run(path, PackedStringArray()))
	_menu.id_pressed.connect(func(id: int) -> void: _actions[id].call())
	add_tool_submenu_item(MENU, _menu)


func _exit_tree() -> void:
	remove_tool_menu_item(MENU)
	_menu = null
	_actions.clear()


func _add(label: String, action: Callable) -> void:
	var id: int = _actions.size()
	_menu.add_item(label, id)
	_actions[id] = action


## The picker is built fresh each time rather than kept around, so it always
## opens showing the current CHAIN - which is the thing most likely to have
## changed since the last build.
func _pick_levels() -> void:
	var picker: ConfirmationDialog = LevelPicker.new()
	EditorInterface.get_base_control().add_child(picker)
	picker.confirmed.connect(func() -> void:
		run("res://tools/build_levels.gd", picker.selection()))
	picker.close_requested.connect(picker.queue_free)
	picker.confirmed.connect(picker.queue_free)
	picker.popup_centered()


## Runs one generator and reports what it said. Public because the picker is
## not the only caller and a future dock would want the same entry point.
func run(script_path: String, names: PackedStringArray) -> void:
	_warn_about_open_scenes(script_path, names)
	var argv := PackedStringArray(["--headless", "--path",
		ProjectSettings.globalize_path("res://"), "--script", script_path])
	if not names.is_empty():
		argv.append("--")
		argv.append_array(names)
	print_rich("[b][za-build][/b] %s %s"
		% [script_path.get_file(), " ".join(names)])
	var out: Array = []
	var code := OS.execute(OS.get_executable_path(), argv, out, true)
	for chunk: String in out:
		print(chunk.strip_edges())
	# What makes the editor see the files the child just wrote. Without it the
	# new scenes sit on disk until something else triggers a scan.
	EditorInterface.get_resource_filesystem().scan()
	if code == 0:
		print_rich("[color=green][za-build] done.[/color]")
	else:
		push_error("[za-build] %s exited %d" % [script_path.get_file(), code])


## An open level scene is the one way this can still go wrong: the child writes
## the file, and then the editor saves its own cached copy back over it. The
## plugin cannot close a tab for you, so it says so and lets you decide - and
## it does NOT offer to save first, because saving is the failure.
func _warn_about_open_scenes(script: String, names: PackedStringArray) -> void:
	if not script.ends_with("build_levels.gd"):
		return
	var open: Array = Array(EditorInterface.get_open_scenes()).filter(
		func(path: String) -> bool:
			if not path.begins_with("res://game/levels/"):
				return false
			var at: String = path.trim_prefix("res://game/levels/")
			return names.is_empty() or names.has(at.get_slice("/", 0)))
	if open.is_empty():
		return
	push_warning(("[za-build] %d level scene(s) open in the editor and about "
		+ "to be regenerated: %s. Close the tab(s) without saving, or the "
		+ "editor may write its cached copy back over the new file.")
		% [open.size(), ", ".join(PackedStringArray(open))])
