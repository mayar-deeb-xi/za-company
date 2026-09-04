extends Node
## Persistent player settings, backed by user://settings.cfg.
##
## Owns the file and nothing else. What a setting *means* belongs to whoever
## applies it - display.gd for the window - so a future audio or controls page
## adds its own section here without this script learning about it.
##
## Registered as the first autoload so everything after it can read its values
## during _ready, before the first frame is drawn.

const PATH := "user://settings.cfg"

signal changed(section: StringName, key: StringName)

var _config := ConfigFile.new()


func _ready() -> void:
	var err := _config.load(PATH)
	# A missing file is the normal first run, not a problem worth reporting.
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("could not read %s: %s" % [PATH, error_string(err)])


func get_value(section: StringName, key: StringName, default: Variant) -> Variant:
	return _config.get_value(String(section), String(key), default)


## Whether the player has ever set this, as opposed to it merely having a
## default. Callers use it to leave untouched anything never chosen.
func has(section: StringName, key: StringName) -> bool:
	return _config.has_section_key(String(section), String(key))


## Writes straight through to disk. Settings are changed one at a time by hand,
## so there is nothing to batch, and a crash should never cost the player the
## adjustment they just made.
func set_value(section: StringName, key: StringName, value: Variant) -> void:
	# has_section_key first: ConfigFile treats a null default as "no default"
	# and complains rather than reporting the key as missing.
	if _config.has_section_key(String(section), String(key)) \
			and _config.get_value(String(section), String(key)) == value:
		return
	_config.set_value(String(section), String(key), value)
	var err := _config.save(PATH)
	if err != OK:
		push_warning("could not write %s: %s" % [PATH, error_string(err)])
	changed.emit(section, key)


## Drops every stored setting. Exists for tests and for a future "reset to
## defaults" button; applying the cleared values is the caller's job.
func clear() -> void:
	_config.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
