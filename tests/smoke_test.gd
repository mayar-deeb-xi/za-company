extends SceneTree
## End-to-end smoke test: menu -> character select -> game -> move -> pause ->
## settings -> attack -> torch -> heart -> death -> wall -> door -> menu ->
## settings -> new run -> three deaths -> game over -> third run -> enemy
## chase -> contact damage -> two swings kill a guard -> wraith drain.
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
var _health_mark := 0
var _enemy: Node2D
var _wraith: Node2D
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


## The red part of the HUD health bar; its width is the readout players get.
func _fill() -> ColorRect:
	return current_scene.get_node("HUD/Hud").get_node("%Fill")


func _percent() -> Label:
	return current_scene.get_node("HUD/Hud").get_node("%Percent")


func _hearts() -> HBoxContainer:
	return current_scene.get_node("HUD/Hud").get_node("%Hearts")


func _heart_tex(i: int) -> Texture2D:
	return (_hearts().get_child(i) as TextureRect).texture


## How much world the camera actually shows, which is what decides whether a
## level is framed whole or scrolled.
func _view_size() -> Vector2:
	return root.get_visible_rect().size / _camera().zoom


## An autoload's constants are not properties, so get() cannot reach them.
func _zooms() -> Array:
	return _autoload("Display").get_script().get_script_constant_map()["ZOOMS"]


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


## The size the UI is designed against, which is not what a headless run's
## viewport reports.
func _base_viewport() -> Vector2:
	return Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width", 640),
		ProjectSettings.get_setting("display/window/size/viewport_height", 360))


func _zoom_option(host: Node) -> OptionButton:
	return _panel(host).get_node("%ZoomOption")


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
		1:
			# From here the run is a clean install: whatever the developer has
			# picked for themselves - a zoom of 2 will do it - must not decide
			# whether a check about framing or window size passes.
			# _restore_settings() hands their own file back at the end.
			#
			# Frame 1 rather than _initialize: setting current_scene is not
			# enough to make an autoload reachable by absolute path, and the
			# null that comes back there fails quietly.
			_autoload("Settings").call("clear")
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
			_check("settings: window mode dropdown takes focus",
				(_panel(_pause_menu()).get_node("%ModeOption") as OptionButton)
					.has_focus())
			# Off the centre line first, or following and centring would put the
			# camera in the same place and the next check would prove nothing.
			_player().global_position = Vector2(100, 200)
			# Zoom in from the pause menu. It has to take effect immediately,
			# with the tree paused, or the player cannot see what they picked.
			_pick(_zoom_option(_pause_menu()), _zooms().find(2.0))
		125:
			_check("zoom: 200%% takes effect while still paused (zoom %s)"
				% _camera().zoom, _camera().zoom == Vector2(2, 2) and paused)
			_check("zoom: the view is now smaller than the level (%s vs %s)"
				% [_view_size(), _level().bounds().size],
				_view_size().x < _level().bounds().size.x)
			_check("zoom: camera follows the player instead of centring (%s)"
				% _camera().global_position,
				_camera().global_position.x != _level().bounds().get_center().x)
			_check("zoom: choice is saved", _saved(&"zoom", 0) == 2)
			# Labelled by percentage, not by how much of a room it happens to
			# show: a name like "WHOLE ROOM" stops being true once a level is
			# bigger than the screen.
			_check("zoom: every level in Display.ZOOMS is offered, as a percentage",
				_zoom_option(_pause_menu()).item_count == _zooms().size()
				and _zoom_option(_pause_menu())
					.get_item_text(_zooms().find(1.5)) == "150%")
			# The jump straight from the whole room to a quarter of it was too big.
			var between: Array = _zooms().filter(func(z): return z > 1.0 and z < 2.0)
			_check("zoom: two steps sit between 100%% and 200%% (%s)" % [between],
				between.size() == 2)
			_pick(_zoom_option(_pause_menu()), 0)
		127:
			_check("zoom: back to 100%% re-centres on the level (%s)"
				% _camera().global_position,
				_camera().zoom == Vector2(1, 1)
					and _camera().global_position == _level().bounds().get_center())
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
			# Health: stand in the torch, then on the heart, then die outright.
			# One landing is one tick - the player's grace window is the meter.
			_check("hud: health bar starts full (%s)" % _player().get("health"),
				_player().get("health") == 100 and _fill().size.x == 66.0
					and _percent().text == "100%")
			_check("hud: three full hearts to start (%s lives, %d icons)"
				% [_player().get("lives"), _hearts().get_child_count()],
				_player().get("lives") == 3 and _hearts().get_child_count() == 3
					and _heart_tex(0) == _heart_tex(2))
			_player().global_position = Vector2(120, 152)
		190:
			_check("torch: standing in the flame costs health (%s)"
				% _player().get("health"), _player().get("health") < 100)
			_check("hud: the bar tracks the hit (%.0f px, '%s')"
				% [_fill().size.x, _percent().text],
				_fill().size.x < 66.0
					and _percent().text == "%d%%" % int(_player().get("health")))
			_health_mark = _player().get("health")
			_player().global_position = Vector2(424, 152)
		200:
			_check("heart: healed on touch (%d -> %s)"
				% [_health_mark, _player().get("health")],
				int(_player().get("health")) > _health_mark)
			_check("heart: consumed on pickup",
				_level().get_node_or_null("Props/Health") == null)
		230:
			# Waited out the torch hit's grace window, so this lethal hit lands.
			_player().call("take_damage", 9999)
		280:
			_check("death: respawns at the level's start with full health (%s at %s)"
				% [_player().get("health"), _player().global_position],
				_player().get("health") == 100
					and _player().global_position.distance_to(Vector2(272, 240)) < 1.0)
			_check("death: hud bar refilled (%.0f px, '%s')"
				% [_fill().size.x, _percent().text],
				_fill().size.x == 66.0 and _percent().text == "100%")
			_check("death: one life spent, hud dims the last heart (%s left)"
				% _player().get("lives"),
				_player().get("lives") == 2
					and _heart_tex(0) == _heart_tex(1)
					and _heart_tex(2) != _heart_tex(0))
			_check("death: fade cleared",
				(current_scene.get_node("Transition/Fade") as ColorRect).color.a < 0.01)
			_player().global_position = Vector2(40, 180)
			_key(KEY_A, true)
		370:
			_check("collision: tiled left wall blocks the player (x=%.1f)"
				% _player().global_position.x,
				_player().global_position.x > 16.0)
			_key(KEY_A, false)
			# Walk north into the doorway. Approaching on foot rather than
			# teleporting onto the threshold is the point: this is the path a
			# player actually takes through the door.
			_player().global_position = Vector2(272, 78)
			_key(KEY_W, true)
		445:
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
			# Per-biome composition: hellfire is the room that escalates. The
			# wraith is identified by its own export rather than by class, the
			# same way everything else here avoids the class cache.
			var here := get_nodes_in_group("enemies")
			var drainers := here.filter(func(e): return e.get("drain_per_second") != null)
			_check("enemies: hellfire adds a wraith to its two guards (%d of %d)"
				% [drainers.size(), here.size()],
				here.size() == 3 and drainers.size() == 1)
			# Turn round and walk back out the way we came in. The wraith is on
			# the far wall, outside its own 120 px sight of this whole path.
			_key(KEY_S, true)
		525:
			_key(KEY_S, false)
			_check("return: hellfire's south door goes back to the marble hall (got %s)"
				% ("<none>" if _level() == null else _level().name),
				_level() != null and _level().name == "MarbleHall")
			_check("return: player arrives by the door they left through (%s)"
				% _player().global_position,
				_player().global_position.distance_to(Vector2(272, 80)) < 60.0)
			_key(KEY_ESCAPE, true)
			_key(KEY_ESCAPE, false)
		531:
			(_pause_menu().get_node("%MainMenuButton") as Button).pressed.emit()
		543:
			_check("pause: Main Menu returns to the menu, unpaused (got %s)"
				% current_scene.scene_file_path,
				current_scene.scene_file_path == "res://ui/main_menu/main_menu.tscn"
					and not paused)
			(current_scene.get_node("%SettingsButton") as Button).pressed.emit()
		549:
			_check("settings: opens from the main menu too",
				_panel(current_scene).visible)
			# Measured against the DESIGN viewport, not the runtime one: a
			# headless window reports its own size, and 640x360 is the size the
			# panel has to survive. Guards the page as more rows are added.
			var box := _panel(current_scene).get_node(
				"CenterContainer/Panel") as Control
			_check("settings: the panel fits the 640x360 screen (%s)" % box.size,
				box.size.x <= _base_viewport().x and box.size.y <= _base_viewport().y)
			_check("settings: display dropdown offers windowed and fullscreen",
				_mode_option(current_scene).item_count == 2)
			_check("settings: window size dropdown is populated (%d entries)"
				% _window_size_option(current_scene).item_count,
				_window_size_option(current_scene).item_count > 0)
			_pick(_mode_option(current_scene), 1)
		555:
			_check("settings: choosing fullscreen is saved",
				_saved(&"fullscreen", false) == true)
			# Window size means nothing in fullscreen, so the dropdown has to
			# track the window rather than assert a mode of its own.
			_check("settings: window size dropdown tracks the window mode",
				_window_size_option(current_scene).disabled == _is_fullscreen())
			_pick(_mode_option(current_scene), 0)
		561:
			_check("settings: switching back to windowed is saved",
				_saved(&"fullscreen", true) == false)
			_check("settings: window size dropdown is usable in windowed mode",
				not _window_size_option(current_scene).disabled)
			_pick(_window_size_option(current_scene), 0)
		567:
			_check("settings: window size choice is applied and saved (%s)"
				% _first_window_size(),
				_display_window_size() == _first_window_size()
				and _saved(&"window_size", Vector2i.ZERO) == _first_window_size())
			(_panel(current_scene).get_node("%BackButton") as Button).pressed.emit()
		573:
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
			# Second run: spend every life and prove the run actually ends.
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		585:
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
		597:
			_check("lives: a new run starts with all three again (%s)"
				% _player().get("lives"),
				current_scene.scene_file_path == "res://game/game.tscn"
					and _player().get("lives") == 3)
			_player().call("take_damage", 9999)
		650:
			_check("lives: first death respawns with two left (%s, health %s)"
				% [_player().get("lives"), _player().get("health")],
				_player().get("lives") == 2 and _player().get("health") == 100)
			_player().call("take_damage", 9999)
		700:
			_check("lives: second death respawns with one left (%s)"
				% _player().get("lives"),
				_player().get("lives") == 1 and _player().get("health") == 100)
			_player().call("take_damage", 9999)
		750:
			_check("game over: the last death raises the death screen, paused",
				paused and _pause_menu().get_node("Root").visible)
			_check("game over: heading reads YOU DIED (got '%s')"
				% (_pause_menu().get_node("%Heading") as Label).text,
				(_pause_menu().get_node("%Heading") as Label).text == "YOU DIED")
			_check("game over: CONTINUE is disabled, MAIN MENU has focus",
				(_pause_menu().get_node("%ContinueButton") as Button).disabled
					and (_pause_menu().get_node("%MainMenuButton") as Button)
						.has_focus())
			# Escape must not dismiss a finished run - there is nothing to
			# resume back into.
			_key(KEY_ESCAPE, true)
			_key(KEY_ESCAPE, false)
		756:
			_check("game over: Escape cannot dismiss the death screen",
				paused and _pause_menu().get_node("Root").visible)
			(_pause_menu().get_node("%MainMenuButton") as Button).pressed.emit()
		768:
			_check("game over: MAIN MENU leaves the run, unpaused (got %s)"
				% current_scene.scene_file_path,
				current_scene.scene_file_path == "res://ui/main_menu/main_menu.tscn"
					and not paused)
			# Third run: combat. The guards stood clear of every path above -
			# they sight 80 px and nothing so far came within it.
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		783:
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
		798:
			var enemies := get_nodes_in_group("enemies")
			_check("enemies: marble hall places two guards (%d)" % enemies.size(),
				enemies.size() == 2)
			_check("enemies: a guard starts at full health",
				enemies.size() > 0 and enemies[0].get("health") == 10)
			# Park mid-room, clear of props, and bring one guard inside its sight.
			# The player has not moved this run, so they still face down - the
			# guard approaches straight into the swing.
			_player().global_position = Vector2(272, 140)
			_enemy = enemies[0] as Node2D
			_enemy.global_position = Vector2(272, 190)
		824:
			_check("enemies: the guard chases the player (%.0f px away)"
				% _enemy.global_position.distance_to(_player().global_position),
				_enemy.global_position.distance_to(_player().global_position) < 45.0)
		864:
			# Contact happened well before this; the grace window keeps a second
			# touch from landing until after the check, so the cost is exactly one
			# hit of the guard's contact damage.
			_check("enemies: touch costs contact damage, metered by grace (%s)"
				% _player().get("health"), _player().get("health") == 95)
			# Arrived and stopped: past its stop_distance it would be grinding
			# against the player's collision at the 10 px the two bodies block
			# at, and sliding around them.
			var guard_gap: float = _enemy.global_position.distance_to(
				_player().global_position)
			_check("enemies: the guard stops short instead of grinding in (%.1f px)"
				% guard_gap, guard_gap > 10.0 and guard_gap < 14.0)
			_key(KEY_SPACE, true)
		868:
			_key(KEY_SPACE, false)
		894:
			_check("attack: one swing costs the enemy ATTACK_POWER (health %s)"
				% (str(_enemy.get("health")) if is_instance_valid(_enemy) else "<freed>"),
				is_instance_valid(_enemy) and _enemy.get("health") == 5)
			_key(KEY_SPACE, true)
		898:
			_key(KEY_SPACE, false)
		928:
			_check("attack: the second swing kills - the guard is gone (%d left)"
				% get_nodes_in_group("enemies").size(),
				not is_instance_valid(_enemy)
					and get_nodes_in_group("enemies").size() == 1)
			# The wraith, placed by hand rather than walked to in hellfire: the
			# drain is a rate, and a rate needs contact to start on a frame the
			# test knows. It is the real scene either way.
			var wraith_scene := load("res://game/enemies/wraith/wraith.tscn") as PackedScene
			_wraith = wraith_scene.instantiate()
			_level().get_node("Props").add_child(_wraith)
			_wraith.global_position = Vector2(272, 152)
			_health_mark = _player().get("health")
		1070:
			# 140 frames of contact at one point per second. Exactly two, and
			# nothing like the 5-a-hit a regular would have dealt in that time -
			# which is the check that it really has no attack.
			_check("wraith: drains one point per second of proximity (%d -> %s)"
				% [_health_mark, _player().get("health")],
				_health_mark - int(_player().get("health")) == 2)
			# Held at stop_distance, not grinding into the player's collision and
			# not stalled out of its own aura either - and never attacking.
			var gap: float = _wraith.global_position.distance_to(_player().global_position)
			_check("wraith: holds station close by instead of pushing in (%.1f px, '%s')"
				% [gap, _wraith.get_node("AnimatedSprite2D").animation],
				gap > 10.0 and gap < 14.0
					and not String(_wraith.get_node("AnimatedSprite2D").animation)
						.begins_with("attack"))
			# The point of drain() existing. Land a normal hit to open a grace
			# window, then stay well inside it: a drain routed through
			# take_damage() would be swallowed whole and the loss would be the
			# 5 of the hit alone. The rate is turned up so the tick lands inside
			# 0.8s rather than straddling it.
			_wraith.set("drain_per_second", 4.0)
			_health_mark = _player().get("health")
			_player().call("take_damage", 5)
		1100:
			# 30 frames later - still inside HURT_GRACE_SECONDS.
			_check("wraith: the drain lands during the grace window a hit opens (lost %d)"
				% (_health_mark - int(_player().get("health"))),
				_health_mark - int(_player().get("health")) >= 6)
			_key(KEY_SPACE, true)
		1104:
			_key(KEY_SPACE, false)
		1130:
			_check("wraith: takes ATTACK_POWER like anything else (health %s)"
				% (str(_wraith.get("health")) if is_instance_valid(_wraith) else "<freed>"),
				is_instance_valid(_wraith) and _wraith.get("health") == 5)
			_key(KEY_SPACE, true)
		1134:
			_key(KEY_SPACE, false)
		1164:
			_check("wraith: dies to two swings like the guards (%d enemies left)"
				% get_nodes_in_group("enemies").size(),
				not is_instance_valid(_wraith)
					and get_nodes_in_group("enemies").size() == 1)
			_finish()
	return false
