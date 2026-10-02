extends Node
## The in-game updater: whether this copy may update itself, and the run of
## download -> verify -> install when it may. todo.md is the whole plan.
##
## **Off until both platforms pass** (todo.md, Part D). While ENABLED is
## false every copy gets the browser link, exactly as before the updater
## existed - so a release made in the meantime treats Windows and Mac alike.
## A run started with `--update-feed=` switches it on for that run only,
## which is how it is tested before then.
##
## The platform's own work is one small script each, with the same three
## members (ASSET_SUFFIX, refusal(), install()); this file calls nothing else
## on them, which is what lets the macOS half be written by someone who never
## touches the rest.

signal progressed(done: int, total: int)
signal installing
signal failed(reason: String)

const ENABLED := false

const ReleaseCheck := preload("res://ui/update/release_check.gd")
const Download := preload("res://ui/update/update_download.gd")
const WINDOWS := preload("res://ui/update/update_install_windows.gd")
const MACOS := preload("res://ui/update/update_install_macos.gd")

## Where downloads land; emptied whenever the main menu opens, so an
## installer that already ran is not left behind.
const FOLDER := "user://updates"

var _download: Download


## The install step for an OS, or null where there is none (the web build,
## Linux).
static func platform(os_name := OS.get_name()) -> GDScript:
	match os_name:
		"Windows":
			return WINDOWS
		"macOS":
			return MACOS
	return null


static func switched_on(feed := ReleaseCheck.feed()) -> bool:
	return ENABLED or feed != ""


## "" when this copy can update itself from inside the game, else why not -
## in which case the menu offers the browser link instead.
static func refusal(os_name := OS.get_name(), executable_path := OS.get_executable_path(),
		feed := ReleaseCheck.feed()) -> String:
	if not switched_on(feed):
		return "the in-game updater is switched off"
	var script := platform(os_name)
	if script == null:
		return "there is no in-game updater for " + os_name
	return script.refusal(executable_path)


static func clear_downloads() -> void:
	var dir := DirAccess.open(FOLDER)
	if dir == null:
		return
	for file_name in dir.get_files():
		dir.remove(file_name)


## Download, verify and install `release` (the JSON ReleaseCheck.found()
## returns). Reports through the three signals; `failed` always leaves the
## game exactly as it was, and on success the game quits for the installer.
func start(release: Dictionary) -> void:
	var script := platform()
	var assets: Array = release.get("assets", [])
	var asset := Download.pick(assets, script.ASSET_SUFFIX) if script != null else {}
	var sums := Download.named(assets, Download.SUMS)
	if asset.is_empty() or sums.is_empty():
		failed.emit.call_deferred("this release has nothing to install on " + OS.get_name())
		return
	_download = Download.new()
	add_child(_download)
	_download.progressed.connect(func(done: int, total: int) -> void: progressed.emit(done, total))
	_download.finished.connect(_on_downloaded)
	_download.fetch(asset, sums, ProjectSettings.globalize_path(FOLDER))


func cancel() -> void:
	if _download != null:
		_download.cancel()
		_download.queue_free()
		_download = null


func _on_downloaded(path: String, error: String) -> void:
	if error != "":
		failed.emit(error)
		return
	installing.emit()
	var reason: String = platform().install(path, OS.get_executable_path())
	if reason != "":
		failed.emit(reason)
		return
	get_tree().quit()
