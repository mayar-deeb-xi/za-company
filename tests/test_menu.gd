extends "res://tests/helpers.gd"
## Menu-side test: main menu (focus, theme, quit confirm), the MODE button and
## its difficulty scaling, the character select screen, and the settings panel
## as hosted by the main menu. Never enters the game - the pause-menu host and
## zoom live in test_flow.gd, which owns a running world.


func _tick(frame: int) -> void:
	match frame:
		4:
			_check("main_scene uid resolves to the main menu",
				ResourceUID.uid_to_path("uid://baccfre32cs6j")
					== "res://ui/main_menu/main_menu.tscn")
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
			# MODE: one cycling button, three states. All checked in one frame -
			# everything here is synchronous, including an enemy's _ready reading
			# its difficulty numbers the moment it is added.
			var mode := current_scene.get_node("%ModeButton") as Button
			_check("mode: defaults to MEDIUM without saving (%s)" % mode.text,
				mode.text == "MODE: MEDIUM"
					and not _autoload("Settings").call("has", &"game", &"difficulty"))
			mode.pressed.emit()
			_check("mode: a press cycles to HARD and saves the pick (%s)" % mode.text,
				mode.text == "MODE: HARD" and _autoload("Settings").call(
					"get_value", &"game", &"difficulty", "") == "hard")
			# Difficulty scales what the world deals, never enemy health - the
			# health numbers are exact combo breakpoints on every mode.
			var hard_guard := (load("res://game/enemies/regular/regular.tscn")
				as PackedScene).instantiate()
			root.add_child(hard_guard)
			_check("mode: HARD guards hit half again as hard, same health (%s dmg, %s hp)"
				% [hard_guard.get("contact_damage"), hard_guard.get("max_health")],
				hard_guard.get("contact_damage") == 15
					and hard_guard.get("max_health") == 24)
			hard_guard.free()
			mode.pressed.emit()
			var easy_guard := (load("res://game/enemies/regular/regular.tscn")
				as PackedScene).instantiate()
			root.add_child(easy_guard)
			_check("mode: EASY guards hit softer, same health (%s dmg)"
				% easy_guard.get("contact_damage"),
				mode.text == "MODE: EASY" and easy_guard.get("contact_damage") == 6)
			easy_guard.free()
			mode.pressed.emit()
			_check("mode: a third press comes round to MEDIUM (%s)" % mode.text,
				mode.text == "MODE: MEDIUM")
			# The rest of the run assumes a clean install; drop what the
			# cycling just saved.
			_autoload("Settings").call("clear")
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		20:
			_check("play: opens the character select (got %s)"
				% current_scene.scene_file_path,
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
			(current_scene.get_node("%SettingsButton") as Button).pressed.emit()
		32:
			_check("settings: opens from the main menu",
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
		38:
			_check("settings: choosing fullscreen is saved",
				_saved(&"fullscreen", false) == true)
			# Window size means nothing in fullscreen, so the dropdown has to
			# track the window rather than assert a mode of its own.
			_check("settings: window size dropdown tracks the window mode",
				_window_size_option(current_scene).disabled == _is_fullscreen())
			_pick(_mode_option(current_scene), 0)
		44:
			_check("settings: switching back to windowed is saved",
				_saved(&"fullscreen", true) == false)
			_check("settings: window size dropdown is usable in windowed mode",
				not _window_size_option(current_scene).disabled)
			_pick(_window_size_option(current_scene), 0)
		50:
			_check("settings: window size choice is applied and saved (%s)"
				% _first_window_size(),
				_display_window_size() == _first_window_size()
				and _saved(&"window_size", Vector2i.ZERO) == _first_window_size())
			(_panel(current_scene).get_node("%BackButton") as Button).pressed.emit()
		56:
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
