extends Control
## Home screen: hands off to the character select - on to the game, or by way
## of ONLINE on to the lobby - or quits after confirmation.

const CHARACTER_SELECT_SCENE := "res://ui/character_select/character_select.tscn"
const LOBBY_SCENE := "res://ui/lobby/lobby.tscn"
const CharacterSelect := preload("res://ui/character_select/character_select.gd")

## Typed by preloaded script rather than by `class_name`: global class names come
## from a cache the editor writes, which a fresh headless checkout lacks.
const SettingsPanelType := preload("res://ui/settings/settings_panel.gd")
const ReleaseCheck := preload("res://ui/update/release_check.gd")
const Updater := preload("res://ui/update/updater.gd")
const UpdatePanel := preload("res://ui/update/update_panel.tscn")

@onready var _play_button: Button = %PlayButton
@onready var _online_button: Button = %OnlineButton
@onready var _mode_button: Button = %ModeButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _quit_confirm: ConfirmationDialog = %QuitConfirm
@onready var _settings: SettingsPanelType = %SettingsPanel
@onready var _version: Label = %Version
@onready var _update_button: Button = %UpdateButton


func _ready() -> void:
	# The menu is home: whatever party this machine was in - a run left by the
	# pause menu, a lobby backed out of - is over by the time it is here.
	Net.leave()
	_play_button.pressed.connect(_on_play_pressed)
	_online_button.pressed.connect(_on_online_pressed)
	_mode_button.pressed.connect(_on_mode_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_quit_confirm.confirmed.connect(_on_quit_confirmed)
	# A browser tab cannot be quit: the engine stops and leaves the page frozen
	# on its last frame. Closing the tab is the web build's way out.
	_quit_button.visible = not OS.has_feature("web")
	_show_mode()

	# The footer's version is the VERSION file itself, and an installed build
	# also asks whether a newer release is out (release_check.gd says when).
	_version.text = "v" + ReleaseCheck.current()
	# Nothing can be mid-update on a menu that has just opened, so whatever an
	# earlier update downloaded has done its job (or never will).
	Updater.clear_downloads()
	_update_button.add_theme_font_override(&"font", get_theme_font(&"font", &"Footer"))
	var check := ReleaseCheck.new()
	check.name = "ReleaseCheck"
	check.newer_found.connect(_on_newer_release)
	add_child(check)

	# Idempotent on the track: coming back from the character select or out of
	# a finished run finds it already playing and leaves it alone.
	Music.play(Music.MENU)

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
	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)


## The same character select as PLAY, told to go on to the lobby rather than
## the game - the pick is made once, on the screen that already makes it.
func _on_online_pressed() -> void:
	CharacterSelect.next_scene = LOBBY_SCENE
	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)


## One button, three states: each press steps EASY -> MEDIUM -> HARD -> round
## again, and the label always says where you are. A separate screen was not
## worth it for a three-way choice, and a cycling button keeps the whole
## decision on the surface. Difficulty saves the pick; what each mode means
## lives with it in autoload/difficulty.gd.
func _on_mode_pressed() -> void:
	Difficulty.cycle()
	_show_mode()


func _show_mode() -> void:
	_mode_button.text = "MODE: %s" % Difficulty.display_name()


func _on_settings_pressed() -> void:
	# Hand the panel the button to hand focus back to when it closes.
	_settings.open(_settings_button)


func _on_quit_pressed() -> void:
	_quit_confirm.popup_centered()
	# Focus Cancel by default so a stray Enter can't quit the game.
	_quit_confirm.get_cancel_button().grab_focus()


func _on_quit_confirmed() -> void:
	get_tree().quit()


## Shown only once a newer release is known, so a menu with nothing to offer
## has nothing extra to tab through. UPDATE when this copy can update itself
## (ui/update/updater.gd decides, and says no while its switch is off), GET IT
## - the release page in the browser - in every other case.
func _on_newer_release(version: String, url: String) -> void:
	var in_game := Updater.refusal() == ""
	_update_button.text = ("v%s IS OUT - UPDATE" if in_game else "v%s IS OUT - GET IT") % version
	_update_button.visible = true
	if in_game:
		_update_button.pressed.connect(_open_update.bind(version, url))
	else:
		_update_button.pressed.connect(OS.shell_open.bind(url))


func _open_update(version: String, url: String) -> void:
	var panel := UpdatePanel.instantiate()
	add_child(panel)
	panel.call("open", ReleaseCheck.found(), version, url, _update_button)
