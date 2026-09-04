extends SceneTree
## End-to-end smoke test: menu -> character select -> game -> move -> attack ->
## pause -> settings -> wall -> door -> menu -> settings.
##
## Run headless (see CLAUDE.md for the binary path):
##   <godot> --headless --path . --fixed-fps 60 --script res://tests/smoke_test.gd
## Exits 0 when every check passes, non-zero otherwise.
##
## The settings section writes to the real user://settings.cfg, so the file is
## backed up on the way in and restored on the way out - a test run must never
## change how the player's game opens.

const SETTINGS_PATH := "user://settings.cfg"   # keep in step with autoload/settings.gd

var _f := 0
var _checks := 0
var _fails: Array[String] = []
var _mark := Vector2.ZERO
var _settings_backup := PackedByteArray()
var _settings_existed := false


func _check(label: String, cond: bool) -> void:
	_checks += 1
	print(("  PASS  " if cond else "  FAIL  "), label)
	if not cond:
		_fails.append(label)


## Sets BOTH keycode and physical_keycode: this project's actions match on
## physical_keycode, Godot's built-in ui_* actions match on keycode.
func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _player() -> CharacterBody2D:
	return current_scene.get_node("Player")


func _sprite() -> AnimatedSprite2D:
	return current_scene.get_node("Player/AnimatedSprite2D")


func _camera() -> Camera2D:
	return current_scene.get_node("Camera2D")


## How much world the camera actually shows, which is what decides whether a
## level is framed whole or scrolled.
func _view_size() -> Vector2:
	return root.get_visible_rect().size / _camera().zoom


func _pause_menu() -> CanvasLayer:
	return current_scene.get_node("PauseMenu")


## game.tscn swaps one Level child in and out; its node name identifies the map.
func _level() -> Node2D:
	for child in current_scene.get_children():
		if child is Node2D and child.has_method("spawn_position"):
			return child
	return null


## Autoloads are reached through /root rather than by name: the script given to
## --script is compiled before the autoload list is available to the compiler,
## so `Settings` and `Display` are not identifiers here the way they are in
## ordinary game scripts. Calls go through call() for the same reason.
func _autoload(name: String) -> Node:
	return root.get_node_or_null("/root/" + name)


func _panel(host: Node) -> Control:
	return host.get_node("%SettingsPanel")


func _mode_option(host: Node) -> OptionButton:
	return _panel(host).get_node("%ModeOption")


func _window_size_option(host: Node) -> OptionButton:
	return _panel(host).get_node("%WindowSizeOption")


## select() alone does not emit item_selected; a real click does both.
func _pick(option: OptionButton, index: int) -> void:
	option.select(index)
	option.item_selected.emit(index)


func _saved(key: StringName, default: Variant) -> Variant:
	return _autoload("Settings").call("get_value", &"display", key, default)


func _is_fullscreen() -> bool:
	return _autoload("Display").call("is_fullscreen")


func _display_window_size() -> Vector2i:
	return _autoload("Display").call("window_size")


func _first_window_size() -> Vector2i:
	return _autoload("Display").call("available_window_sizes")[0]


func _snapshot_settings() -> void:
	_settings_existed = FileAccess.file_exists(SETTINGS_PATH)
	if _settings_existed:
		_settings_backup = FileAccess.get_file_as_bytes(SETTINGS_PATH)


func _restore_settings() -> void:
	if _settings_existed:
		var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
		f.store_buffer(_settings_backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _finish() -> void:
	_restore_settings()
	print("\n%d checks, %d failed" % [_checks, _fails.size()])
	print("RESULT: ", "PASS" if _fails.is_empty() else "FAIL -> " + ", ".join(_fails))
	quit(0 if _fails.is_empty() else 1)


func _initialize() -> void:
	_snapshot_settings()
	_check("main_scene uid resolves to the main menu",
		ResourceUID.uid_to_path("uid://baccfre32cs6j") == "res://ui/main_menu/main_menu.tscn")
	var menu := (load("res://ui/main_menu/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	current_scene = menu


func _process(_delta: float) -> bool:
	_f += 1
	match _f:
		4:
			_check("menu: Play has keyboard focus",
				(current_scene.get_node("%PlayButton") as Button).has_focus())
			_check("menu: themed stylebox applied",
				(current_scene.get_node("%PlayButton") as Button)
					.get_theme_stylebox("normal") is StyleBoxFlat)
			(current_scene.get_node("%QuitButton") as Button).pressed.emit()
		8:
			_check("menu: Quit opens the confirmation dialog",
				(current_scene.get_node("%QuitConfirm") as ConfirmationDialog).visible)
			(current_scene.get_node("%QuitConfirm") as ConfirmationDialog).hide()
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		20:
			_check("play: opens the character select (got %s)" % current_scene.scene_file_path,
				current_scene.scene_file_path
					== "res://ui/character_select/character_select.tscn")
			var row := current_scene.get_node("%Roster") as HBoxContainer
			_check("select: one portrait per roster character (%d)" % row.get_child_count(),
				row.get_child_count() == 7)
			# Focus lands on whichever character the settings file remembers, so
			# the expectation comes from the same place the screen reads.
			var expected: String = _autoload("Settings").call(
				"get_value", &"player", &"character", "mayar")
			_check("select: focus starts on the remembered character (%s)" % expected,
				(row.get_node(expected) as Button).has_focus())
			_key(KEY_ESCAPE, true)
			_key(KEY_ESCAPE, false)
		26:
			_check("select: Escape backs out to the main menu (got %s)"
				% current_scene.scene_file_path,
				current_scene.scene_file_path == "res://ui/main_menu/main_menu.tscn")
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		38:
			# Pick someone who is NOT the default, so the frame swap is provable.
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
		50:
			_check("play: reaches game scene (got %s)" % current_scene.scene_file_path,
				current_scene.scene_file_path == "res://game/game.tscn")
			_check("select: chosen character is saved",
				_autoload("Settings").call("get_value", &"player", &"character", "")
					== "reem")
			_check("select: player wears the chosen character's frames (got %s)"
				% _sprite().sprite_frames.resource_path,
				_sprite().sprite_frames.resource_path.ends_with("reem_frames.tres"))
			_check("game: player sprite frames load (32x32)",
				_sprite().sprite_frames.get_frame_texture("walk_down", 0).get_size()
					== Vector2(32, 32))
			_check("level: marble hall loads first (got %s)"
				% ("<none>" if _level() == null else _level().name),
				_level() != null and _level().name == "MarbleHall")
			_check("level: player spawned on the level's start marker (%s)"
				% _player().global_position,
				_player().global_position == Vector2(272, 240))
			_check("camera: the whole level is on screen (view %s vs level %s)"
				% [_view_size(), _level().bounds().size],
				_view_size().x >= _level().bounds().size.x
					and _view_size().y >= _level().bounds().size.y)
			_check("camera: centred on the level, since it fits (%s)"
				% _camera().global_position,
				_camera().global_position == _level().bounds().get_center())
			_check("level: doorway is a real gap in the wall ring, sealed by the door",
				(_level().get_node("Walls") as TileMapLayer)
					.get_cell_source_id(Vector2i(16, 0)) == -1
				and _level().get_node("Props/Exit/Seal") is StaticBody2D)
			_mark = _player().global_position
			_key(KEY_W, true)
		80:
			_check("move: W moves the player up", _player().global_position.y < _mark.y - 5.0)
			_check("move: walk_up animation (got %s)" % _sprite().animation,
				_sprite().animation == "walk_up")
			_key(KEY_W, false)
			_key(KEY_ESCAPE, true)
			_key(KEY_ESCAPE, false)
		86:
			_check("pause: Escape pauses and shows the overlay",
				paused and _pause_menu().get_node("Root").visible)
			_check("pause: Continue has keyboard focus",
				(_pause_menu().get_node("%ContinueButton") as Button).has_focus())
			_mark = _player().global_position
			_key(KEY_W, true)
		116:
			_check("pause: player is frozen (moved %.2f px)"
				% _player().global_position.distance_to(_mark),
				_player().global_position.distance_to(_mark) < 0.01)
			_key(KEY_W, false)
			(_pause_menu().get_node("%SettingsButton") as Button).pressed.emit()
		122:
			_check("settings: opens from the pause menu, still paused",
				_panel(_pause_menu()).visible and paused)
			_check("settings: display dropdown takes focus",
				(_panel(_pause_menu()).get_node("%ModeOption") as OptionButton)
					.has_focus())
			_key(KEY_ESCAPE, true)
			_key(KEY_ESCAPE, false)
		128:
			# The interesting case: Escape has to back out of settings without
			# also unpausing the game underneath it.
			_check("settings: Escape closes the panel but does NOT unpause",
				not _panel(_pause_menu()).visible and paused)
			_check("settings: focus returns to the button that opened it",
				(_pause_menu().get_node("%SettingsButton") as Button).has_focus())
			_key(KEY_ESCAPE, true)
			_key(KEY_ESCAPE, false)
		134:
			_check("pause: Escape resumes", not paused)
			_key(KEY_SPACE, true)
			_key(KEY_SPACE, false)
		138:
			_check("attack: animation plays (got %s)" % _sprite().animation,
				String(_sprite().animation).begins_with("attack"))
		177:
			_check("attack: releases back to idle (got %s)" % _sprite().animation,
				String(_sprite().animation).begins_with("idle"))
			_player().global_position = Vector2(40, 180)
			_key(KEY_A, true)
		267:
			_check("collision: tiled left wall blocks the player (x=%.1f)"
				% _player().global_position.x,
				_player().global_position.x > 16.0)
			_key(KEY_A, false)
			# Walk north into the doorway. Approaching on foot rather than
			# teleporting onto the threshold is the point: this is the path a
			# player actually takes through the door.
			_player().global_position = Vector2(272, 78)
			_key(KEY_W, true)
		342:
			_key(KEY_W, false)
			_check("door: walking north into the doorway loads hellfire (got %s)"
				% ("<none>" if _level() == null else _level().name),
				_level() != null and _level().name == "Hellfire")
			_check("door: player arrives by hellfire's south door (%s)"
				% _player().global_position,
				_player().global_position.distance_to(Vector2(272, 240)) < 40.0)
			_check("door: transition faded back in",
				(current_scene.get_node("Transition/Fade") as ColorRect).color.a < 0.01)
			_check("door: camera reframed on the new level (%s)"
				% _camera().global_position,
				_camera().global_position == _level().bounds().get_center())
			# Turn round and walk back out the way we came in.
			_key(KEY_S, true)
		422:
			_key(KEY_S, false)
			_check("return: hellfire's south door goes back to the marble hall (got %s)"
				% ("<none>" if _level() == null else _level().name),
				_level() != null and _level().name == "MarbleHall")
			_check("return: player arrives by the door they left through (%s)"
				% _player().global_position,
				_player().global_position.distance_to(Vector2(272, 80)) < 60.0)
			_key(KEY_ESCAPE, true)
			_key(KEY_ESCAPE, false)
		428:
			(_pause_menu().get_node("%MainMenuButton") as Button).pressed.emit()
		440:
			_check("pause: Main Menu returns to the menu, unpaused (got %s)"
				% current_scene.scene_file_path,
				current_scene.scene_file_path == "res://ui/main_menu/main_menu.tscn"
					and not paused)
			(current_scene.get_node("%SettingsButton") as Button).pressed.emit()
		446:
			_check("settings: opens from the main menu too",
				_panel(current_scene).visible)
			_check("settings: display dropdown offers windowed and fullscreen",
				_mode_option(current_scene).item_count == 2)
			_check("settings: window size dropdown is populated (%d entries)"
				% _window_size_option(current_scene).item_count,
				_window_size_option(current_scene).item_count > 0)
			_pick(_mode_option(current_scene), 1)
		452:
			_check("settings: choosing fullscreen is saved",
				_saved(&"fullscreen", false) == true)
			# Window size means nothing in fullscreen, so the dropdown has to
			# track the window rather than assert a mode of its own.
			_check("settings: window size dropdown tracks the window mode",
				_window_size_option(current_scene).disabled == _is_fullscreen())
			_pick(_mode_option(current_scene), 0)
		458:
			_check("settings: switching back to windowed is saved",
				_saved(&"fullscreen", true) == false)
			_check("settings: window size dropdown is usable in windowed mode",
				not _window_size_option(current_scene).disabled)
			_pick(_window_size_option(current_scene), 0)
		464:
			_check("settings: window size choice is applied and saved (%s)"
				% _first_window_size(),
				_display_window_size() == _first_window_size()
				and _saved(&"window_size", Vector2i.ZERO) == _first_window_size())
			(_panel(current_scene).get_node("%BackButton") as Button).pressed.emit()
		470:
			_check("settings: Back closes the panel and restores focus",
				not _panel(current_scene).visible
				and (current_scene.get_node("%SettingsButton") as Button).has_focus())
			# The actual requirement: it survives a restart. Read the file back
			# cold, the way the next launch will.
			var saved := ConfigFile.new()
			var err := saved.load(SETTINGS_PATH)
			_check("settings: on disk and readable on next launch (%s)"
				% error_string(err),
				err == OK
				and saved.get_value("display", "fullscreen", true) == false
				and saved.get_value("display", "window_size", Vector2i.ZERO)
					== _first_window_size())
			_finish()
	return false
