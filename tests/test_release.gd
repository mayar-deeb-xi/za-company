extends "res://tests/helpers.gd"
## The game's half of a release (RELEASING.md): the menu shows the VERSION file,
## a newer release on GitHub raises a notice and an older or broken answer does
## not, and the export presets keep carrying what an installed build needs to
## know any of that. No network: a suite is not `packaged`, so the menu never
## asks, and the answers below are handed to the check directly.
##
## The presets are read off disk because they are the one place this can break
## silently - re-saving them from the editor with VERSION dropped from
## `include_filter` ships a game whose menu says "vdev", and `addons/*` copied
## over from the Web preset ships one that cannot play online.

const ReleaseCheck := preload("res://ui/main_menu/release_check.gd")
const PRESETS := "res://export_presets.cfg"
const DESKTOP := ["Windows Desktop", "macOS"]


func _tick(frame: int) -> void:
	match frame:
		4:
			_menu()
			_comparisons()
			_answers()
			_presets()
			_finish()


func _menu() -> void:
	var version := FileAccess.get_file_as_string("res://VERSION").strip_edges()
	_check("version: VERSION is MAJOR.MINOR.PATCH (%s)" % version,
		RegEx.create_from_string("^\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z.]+)?$").search(version) != null)
	_check("version: the check reads it (%s)" % ReleaseCheck.current(),
		ReleaseCheck.current() == version)
	var label := current_scene.get_node("%Version") as Label
	_check("menu: the footer shows it (%s)" % label.text, label.text == "v" + version)
	var button := current_scene.get_node("%UpdateButton") as Button
	_check("menu: no notice with nothing newer known", not button.visible)
	var check := current_scene.get_node("ReleaseCheck")
	_check("menu: an unpackaged run never asks GitHub (%d requests)"
		% check.get_child_count(), check.get_child_count() == 0)


func _comparisons() -> void:
	var cases := [
		["0.2.0", "0.1.0", true], ["0.1.1", "0.1.0", true], ["1.0.0", "0.9.9", true],
		["0.10.0", "0.9.0", true], ["v0.2.0", "0.1.0", true],
		["0.1.0", "0.1.0", false], ["0.0.9", "0.1.0", false],
		["1.0.0", "1.0.0-rc.1", true], ["1.0.0-rc.1", "1.0.0", false],
		["banana", "0.1.0", false], ["0.2", "0.1.0", false], ["0.2.0", "dev", false],
	]
	var wrong := []
	for c in cases:
		if ReleaseCheck.is_newer(c[0], c[1]) != c[2]:
			wrong.append("%s vs %s" % [c[0], c[1]])
	_check("compare: %d cases, wrong: %s" % [cases.size(), wrong], wrong.is_empty())


func _answers() -> void:
	# A loose check first, so nothing it raises can land on the menu's button.
	var loose := ReleaseCheck.new()
	var raised := []
	loose.newer_found.connect(func(v: String, _u: String) -> void: raised.append(v))
	loose.take(_release("v0.0.1"))
	loose.take(_release("v" + ReleaseCheck.current()))
	loose.take("{not json")
	loose.take("[]")
	loose.take(JSON.stringify({"tag_name": "v99.0.0", "html_url": "https://example.com/x"}))
	_check("answers: older, the same, junk and a foreign link raise nothing (%s)" % [raised],
		raised.is_empty())
	loose.free()

	current_scene.get_node("ReleaseCheck").call("take", _release("v99.0.0"))
	var button := current_scene.get_node("%UpdateButton") as Button
	_check("answers: a newer release shows the notice (%s)" % button.text,
		button.visible and button.text == "v99.0.0 IS OUT - GET IT")
	_check("answers: and it is a button the player can press",
		button.focus_mode != Control.FOCUS_NONE and not button.disabled)


func _release(tag: String) -> String:
	return JSON.stringify({"tag_name": tag,
		"html_url": "https://github.com/mayar4ki/za-company/releases/tag/" + tag})


func _presets() -> void:
	var cfg := ConfigFile.new()
	_check("presets: export_presets.cfg reads", cfg.load(PRESETS) == OK)
	var by_name := {}
	for section in cfg.get_sections():
		if cfg.has_section_key(section, "platform"):
			by_name[cfg.get_value(section, "name")] = section
	for preset in ["Web"] + DESKTOP:
		_check("presets: %s exists" % preset, by_name.has(preset))
		if by_name.has(preset):
			var include := String(cfg.get_value(by_name[preset], "include_filter", ""))
			_check("presets: %s ships VERSION (%s)" % [preset, include], _listed(include, "VERSION"))
	for preset in DESKTOP:
		if not by_name.has(preset):
			continue
		var section: String = by_name[preset]
		var features := String(cfg.get_value(section, "custom_features", ""))
		_check("presets: %s is `packaged` (%s)" % [preset, features], _listed(features, "packaged"))
		var exclude := String(cfg.get_value(section, "exclude_filter", ""))
		_check("presets: %s keeps the WebRTC plugin (%s)" % [preset, exclude],
			not exclude.contains("addons/*") and not exclude.contains("webrtc"))
	_check("project: a packaged build is called The New Hire",
		ProjectSettings.get_setting("application/config/name.packaged", "") == "The New Hire")


## Whether a comma-separated preset field names `item` exactly.
static func _listed(field: String, item: String) -> bool:
	for part in field.split(",", false):
		if part.strip_edges() == item:
			return true
	return false
