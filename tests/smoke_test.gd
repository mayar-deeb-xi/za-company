extends SceneTree
## End-to-end smoke test: menu -> game -> move -> attack -> pause -> wall -> menu.
##
## Run headless (see CLAUDE.md for the binary path):
##   <godot> --headless --path . --fixed-fps 60 --script res://tests/smoke_test.gd
## Exits 0 when every check passes, non-zero otherwise.

var _f := 0
var _fails: Array[String] = []
var _mark := Vector2.ZERO


func _check(label: String, cond: bool) -> void:
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


func _pause_menu() -> CanvasLayer:
	return current_scene.get_node("PauseMenu")


func _initialize() -> void:
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
			_check("play: reaches game scene (got %s)" % current_scene.scene_file_path,
				current_scene.scene_file_path == "res://game/game.tscn")
			_check("game: player sprite frames load (32x32)",
				_sprite().sprite_frames.get_frame_texture("walk_down", 0).get_size()
					== Vector2(32, 32))
			_mark = _player().global_position
			_key(KEY_W, true)
		50:
			_check("move: W moves the player up", _player().global_position.y < _mark.y - 5.0)
			_check("move: walk_up animation (got %s)" % _sprite().animation,
				_sprite().animation == "walk_up")
			_key(KEY_W, false)
			_key(KEY_ESCAPE, true)
			_key(KEY_ESCAPE, false)
		56:
			_check("pause: Escape pauses and shows the overlay",
				paused and _pause_menu().get_node("Root").visible)
			_check("pause: Continue has keyboard focus",
				(_pause_menu().get_node("%ContinueButton") as Button).has_focus())
			_mark = _player().global_position
			_key(KEY_W, true)
		86:
			_check("pause: player is frozen (moved %.2f px)"
				% _player().global_position.distance_to(_mark),
				_player().global_position.distance_to(_mark) < 0.01)
			_key(KEY_W, false)
			_key(KEY_ESCAPE, true)
			_key(KEY_ESCAPE, false)
		92:
			_check("pause: Escape resumes", not paused)
			_key(KEY_SPACE, true)
			_key(KEY_SPACE, false)
		96:
			_check("attack: animation plays (got %s)" % _sprite().animation,
				String(_sprite().animation).begins_with("attack"))
		135:
			_check("attack: releases back to idle (got %s)" % _sprite().animation,
				String(_sprite().animation).begins_with("idle"))
			_player().global_position = Vector2(40, 180)
			_key(KEY_A, true)
		225:
			_check("collision: left wall blocks the player (x=%.1f)"
				% _player().global_position.x,
				_player().global_position.x > 16.0)
			_key(KEY_A, false)
			_key(KEY_ESCAPE, true)
			_key(KEY_ESCAPE, false)
		231:
			(_pause_menu().get_node("%MainMenuButton") as Button).pressed.emit()
		243:
			_check("pause: Main Menu returns to the menu, unpaused (got %s)"
				% current_scene.scene_file_path,
				current_scene.scene_file_path == "res://ui/main_menu/main_menu.tscn"
					and not paused)
			print("\n%d checks, %d failed" % [16, _fails.size()])
			print("RESULT: ", "PASS" if _fails.is_empty() else "FAIL -> " + ", ".join(_fails))
			quit(0 if _fails.is_empty() else 1)
	return false
