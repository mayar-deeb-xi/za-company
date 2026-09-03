extends CanvasLayer
## In-game pause overlay.
##
## Runs with PROCESS_MODE_ALWAYS so it keeps receiving input while the tree is
## paused - it has to, or nothing could unpause it. Everything else in the game
## scene stays PAUSABLE and freezes.

const MAIN_MENU_SCENE := "res://ui/main_menu/main_menu.tscn"

@onready var _root: Control = $Root
@onready var _continue_button: Button = %ContinueButton
@onready var _menu_button: Button = %MainMenuButton
@onready var _quit_button: Button = %QuitButton
@onready var _quit_confirm: ConfirmationDialog = %QuitConfirm


func _ready() -> void:
	_continue_button.pressed.connect(resume)
	_menu_button.pressed.connect(_on_main_menu_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_quit_confirm.confirmed.connect(_on_quit_confirmed)
	_root.visible = false


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	# While the quit dialog is open, Escape belongs to the dialog.
	if _quit_confirm.visible:
		return
	get_viewport().set_input_as_handled()
	if is_paused():
		resume()
	else:
		pause()


func is_paused() -> bool:
	return _root.visible


func pause() -> void:
	get_tree().paused = true
	_root.visible = true
	_continue_button.grab_focus()


func resume() -> void:
	_root.visible = false
	get_tree().paused = false


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
