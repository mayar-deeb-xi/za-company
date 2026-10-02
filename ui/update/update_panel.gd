extends Control
## The screen over the main menu while an update runs: progress and CANCEL,
## then "installing", or - on any failure - why, with the browser link
## (decided: the link never goes away) and CLOSE.
##
## Three states and nothing else. DOWNLOADING can be cancelled, which deletes
## the partial file and leaves the game exactly as it was. INSTALLING cannot:
## by then the installer is starting and the game is about to quit for it.
## FAILED says why and offers the release page, so a broken updater still
## leaves the player a way forward.
##
## The menu owns the release check; this only runs ui/update/updater.gd on
## the release it is handed. Escape is swallowed and sounds like a back, the
## settings panel's rule.

signal closed

const Updater := preload("res://ui/update/updater.gd")

enum State { DOWNLOADING, INSTALLING, FAILED }

@onready var _status: Label = %Status
@onready var _progress: ProgressBar = %Progress
@onready var _detail: Label = %Detail
@onready var _cancel: Button = %CancelButton
@onready var _link: Button = %LinkButton
@onready var _close: Button = %CloseButton

var state := State.DOWNLOADING
var _updater: Updater
var _url := ""
var _return_focus: Control = null


func _ready() -> void:
	_cancel.pressed.connect(close)
	_close.pressed.connect(close)
	_link.pressed.connect(func() -> void: OS.shell_open(_url))


## Opens over the menu for `release` (ReleaseCheck.found()). `begin` false is
## for tests: the panel then shows its first state without touching the
## network, and the signal handlers below are driven by hand.
func open(release: Dictionary, version: String, url: String, return_focus: Control = null,
		begin := true) -> void:
	_url = url
	_return_focus = return_focus
	_show_downloading(version)
	if not begin:
		return
	_updater = Updater.new()
	add_child(_updater)
	_updater.progressed.connect(_on_progressed)
	_updater.installing.connect(_on_installing)
	_updater.failed.connect(_on_failed)
	_updater.start(release)


func close() -> void:
	if state == State.INSTALLING:
		return
	if _updater != null:
		_updater.cancel()
	if is_instance_valid(_return_focus):
		_return_focus.grab_focus()
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if state != State.INSTALLING:
		UiSound.back()
		close()


func _show_downloading(version: String) -> void:
	state = State.DOWNLOADING
	_status.text = "DOWNLOADING v%s" % version
	_progress.value = 0.0
	_detail.text = "STARTING..."
	_cancel.visible = true
	_link.visible = false
	_close.visible = false
	_cancel.grab_focus()


func _on_progressed(done: int, total: int) -> void:
	if total > 0:
		_progress.value = float(done) / float(total)
		_detail.text = "%.1f OF %.1f MB" % [done / 1048576.0, total / 1048576.0]
	else:
		_detail.text = "%.1f MB" % (done / 1048576.0)


func _on_installing() -> void:
	state = State.INSTALLING
	_progress.value = 1.0
	_status.text = "INSTALLING"
	_detail.text = "THE GAME WILL CLOSE AND START AGAIN"
	_cancel.visible = false


func _on_failed(reason: String) -> void:
	state = State.FAILED
	_status.text = "COULD NOT UPDATE"
	_detail.text = reason.to_upper()
	_cancel.visible = false
	_link.visible = true
	_close.visible = true
	_link.grab_focus()
