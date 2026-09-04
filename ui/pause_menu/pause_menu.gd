extends CanvasLayer
## In-game pause overlay, doubling as the game-over screen: same panel, but the
## heading reads YOU DIED, CONTINUE is disabled and Escape cannot dismiss it -
## the only ways out of a finished run are MAIN MENU and QUIT.
##
## Runs with PROCESS_MODE_ALWAYS so it keeps receiving input while the tree is
## paused - it has to, or nothing could unpause it. Everything else in the game
## scene stays PAUSABLE and freezes.

const MAIN_MENU_SCENE := "res://ui/main_menu/main_menu.tscn"

## Typed by preloaded script rather than by `class_name`: global class names come
## from a cache the editor writes, which a fresh headless checkout lacks.
const SettingsPanelType := preload("res://ui/settings/settings_panel.gd")

@onready var _root: Control = $Root
@onready var _heading: Label = %Heading
@onready var _continue_button: Button = %ContinueButton
@onready var _settings_button: Button = %SettingsButton
@onready var _menu_button: Button = %MainMenuButton
@onready var _quit_button: Button = %QuitButton
@onready var _quit_confirm: ConfirmationDialog = %QuitConfirm
@onready var _settings: SettingsPanelType = %SettingsPanel

var _game_over := false


func _ready() -> void:
	_continue_button.pressed.connect(resume)
	_settings_button.pressed.connect(_on_settings_pressed)
	_menu_button.pressed.connect(_on_main_menu_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_quit_confirm.confirmed.connect(_on_quit_confirmed)
	_root.visible = false


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	# While the quit dialog or the settings panel is open, Escape belongs to it:
	# it should back out one step, not unpause the game underneath.
	if _quit_confirm.visible or _settings.is_open():
		return
	get_viewport().set_input_as_handled()
	# A finished run has nothing to resume: Escape is swallowed so it cannot
	# dismiss the death screen and leave a paused game with no way back in.
	if _game_over:
		return
	if is_paused():
		resume()
	else:
		pause()


func is_paused() -> bool:
	return _root.visible


func pause() -> void:
	# Also resets the game-over dressing; unreachable today (a finished run
	# only leaves this scene), but cheap insurance against a future path back.
	_game_over = false
	_heading.text = "PAUSED"
	_continue_button.disabled = false
	get_tree().paused = true
	_root.visible = true
	_continue_button.grab_focus()


## The same overlay worn as a death screen. Called by game.gd when the last
## life is spent; the room stays visible behind the dim, frozen where you fell.
func show_game_over() -> void:
	_game_over = true
	_heading.text = "YOU DIED"
	_continue_button.disabled = true
	get_tree().paused = true
	_root.visible = true
	_menu_button.grab_focus()


func resume() -> void:
	# Close settings on the way out, or it would still be open behind the next
	# pause - hidden along with Root, then revealed again on top of the menu.
	if _settings.is_open():
		_settings.close()
	_root.visible = false
	get_tree().paused = false


func _on_settings_pressed() -> void:
	# Hand the panel the button to hand focus back to when it closes.
	_settings.open(_settings_button)


func _on_main_menu_pressed() -> void:
	# Unpause before leaving, or the menu scene loads frozen.
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_quit_pressed() -> void:
	_quit_confirm.popup_centered()
	# Focus Cancel so a stray Enter can't quit the game.
	_quit_confirm.get_cancel_button().grab_focus()


func _on_quit_confirmed() -> void:
	get_tree().quit()
