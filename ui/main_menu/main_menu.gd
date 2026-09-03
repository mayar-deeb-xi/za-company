extends Control
## Home screen: starts the game, or quits after confirmation.

const GAME_SCENE := "res://game/game.tscn"

@onready var _play_button: Button = %PlayButton
@onready var _quit_button: Button = %QuitButton
@onready var _quit_confirm: ConfirmationDialog = %QuitConfirm


func _ready() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_quit_confirm.confirmed.connect(_on_quit_confirmed)

	# Route the window's X button through the same confirmation.
	get_tree().auto_accept_quit = false

	_play_button.grab_focus()


func _exit_tree() -> void:
	# Leaving the menu hands window-close handling back to the engine.
	get_tree().auto_accept_quit = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_on_quit_pressed()


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_quit_pressed() -> void:
	_quit_confirm.popup_centered()
	# Focus Cancel by default so a stray Enter can't quit the game.
	_quit_confirm.get_cancel_button().grab_focus()


func _on_quit_confirmed() -> void:
	get_tree().quit()
