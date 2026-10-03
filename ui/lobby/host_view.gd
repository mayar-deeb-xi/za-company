extends Control
## The lobby's HOST A GAME (lobby.gd), as the Open Games preview drew it: who
## can join, how hard, OPEN THE ROOM. Each choice has one line under it that
## says what it does.
##
## - **ROOM: PUBLIC / PRIVATE.** Every game is in the list either way; public
##   lets anybody in from it, private only somebody with the code. Public is the
##   default, and the last choice is remembered (Settings' `online` section) -
##   the room's own switch (room_view.gd) changes the same one.
## - **DIFFICULTY.** The same saved mode Settings offers, stepped round here
##   (Difficulty's `cycle()`). The whole party plays on the host's, because only
##   the host's world reaches anybody.

signal open_requested(public: bool)
signal back_requested

const SETTINGS := &"online"
const PUBLIC_KEY := &"public"
const ACCENT := Color("6eb39d")
const MID := Color("e8b84a")

@onready var _public_button: Button = %PublicChoice
@onready var _public_line: Label = %PublicLine
@onready var _difficulty_button: Button = %DifficultyChoice
@onready var _open_button: Button = %OpenButton
@onready var _back_button: Button = %HostBack
@onready var _status: Label = %HostStatus

var _busy := false


func _ready() -> void:
	_public_button.pressed.connect(_on_public)
	_difficulty_button.pressed.connect(_on_difficulty)
	_open_button.pressed.connect(_on_open)
	_back_button.pressed.connect(back_requested.emit)


## The lobby has just put this screen up.
func shown() -> void:
	_set_busy(false)
	_status.text = ""
	_refresh()
	_open_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	UiSound.back()
	if _busy:
		Net.leave()
		_set_busy(false)
		_status.text = ""
		_open_button.grab_focus()
	else:
		back_requested.emit()


## Opening the room did not happen; `message` is why.
func say(message: String) -> void:
	_set_busy(false)
	_status.text = message
	_status.add_theme_color_override(&"font_color", MID)
	_open_button.grab_focus()


static func public_choice() -> bool:
	return bool(Settings.get_value(SETTINGS, PUBLIC_KEY, true))


func _refresh() -> void:
	var public := public_choice()
	_public_button.text = "ROOM: PUBLIC" if public else "ROOM: PRIVATE"
	_public_line.text = ("ANYONE CAN JOIN FROM THE LIST OF GAMES" if public
		else "IN THE LIST FOR ALL TO SEE - ONLY YOUR CODE GETS IN")
	_public_line.add_theme_color_override(&"font_color", ACCENT if public else MID)
	_difficulty_button.text = "DIFFICULTY: %s" % Difficulty.display_name()


func _on_public() -> void:
	Settings.set_value(SETTINGS, PUBLIC_KEY, not public_choice())
	_refresh()


func _on_difficulty() -> void:
	Difficulty.cycle()
	_refresh()


func _on_open() -> void:
	if _busy:
		return
	_set_busy(true)
	_status.text = "OPENING THE ROOM..."
	_status.add_theme_color_override(&"font_color", ACCENT)
	open_requested.emit(public_choice())


func _set_busy(busy: bool) -> void:
	_busy = busy
	for button: Button in [_public_button, _difficulty_button, _open_button]:
		button.disabled = busy
