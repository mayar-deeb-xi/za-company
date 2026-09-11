extends Node
## The menu's own noise: a tick when you move between options, a chime when you
## choose one, a lower chime when you back out.
##
## An autoload for `autoload/music.gd`'s two reasons, both of which bite here:
##
## - **The front end is THREE scenes.** `change_scene_to_file` frees the old
##   one, so a press sound started by the PLAY button and living in
##   main_menu.tscn would be destroyed in the same frame it began - the exact
##   trap `game/enemies/enemy_audio.gd` grew `play_detached` for. Above the
##   tree there is nothing to free and no detached copy to bury.
## - **The pause menu runs with the tree PAUSED**, and a paused
##   AudioStreamPlayer stops its stream. `PROCESS_MODE_ALWAYS` is set once
##   here rather than remembered in every screen that might host a menu.
##
## The files sit at `ui/sfx/` rather than in `assets/` on the placement rule in
## CLAUDE.md: four screens under `ui/` share them, so they bubble up exactly one
## level, to where `ui/theme/` already is. Only what is shared ACROSS features
## goes to `assets/`, which is why the music is there and this is not.
##
## ## Nothing wires itself to this
##
## No screen calls `move()` and no button is registered. Two cues ride on
## signals the engine already emits, so a menu gets them by existing:
##
## - `gui_focus_changed` on the root viewport is every focus change in the
##   game, and that is the whole of the move cue. It works because of a fact
##   worth stating outright: **nothing outside the four menu screens ever takes
##   focus.** The dialogue box draws its choices as Labels and picks them with
##   its own index, the HUD is not focusable, and no room has a Control in it.
##   So a signal with no filter on it is already exactly the menus.
## - `node_added` catches every `BaseButton` on its way into the tree and hooks
##   `pressed`, which is the press cue. A button added to a screen next month
##   makes a noise without anybody remembering this file exists.
##
## The third cue is deliberately NOT automatic, and the split is the
## interesting part. `ui_cancel` is one key doing one job everywhere in this
## game - back out of a panel, or open and close the pause menu - so a global
## handler would look right. It is wrong for the reason `hit` only fires on a
## blow that LANDED: the death screen swallows Escape, and a chime on a key
## that did nothing teaches the player the sound does not mean anything
## happened. Only the screen handling the press knows whether it was consumed,
## so the three screens that handle it say `UiSound.back()` where they act on
## it, and nowhere else.
##
## ## The cue is named after what the PLAYER did
##
## Not after what the screen did - which is why the Back BUTTON plays `press`
## while Escape plays `back`. They are the same outcome and different inputs,
## and one sound per key is the version that cannot drift: the alternative is
## this file guessing which buttons "mean" back, by name, forever.
##
## A missing or unimported WAV is silence with no branch anywhere, on the
## bargain `player_audio.gd` and `enemy_audio.gd` both keep - so a fresh
## checkout has quiet menus rather than broken ones.

## id -> file. The catalogue lives here for Music's reason: a path spelled out
## in four screens is the one that goes stale when a file moves. These are
## generated, not recorded - `tools/sfx/ui.py`, which needs no API key and
## costs nothing to re-run.
const CUES := {
	&"move": "res://ui/sfx/move.wav",
	&"press": "res://ui/sfx/press.wav",
	&"back": "res://ui/sfx/back.wav",
}

## Trim over the levels baked into the files, which are set per cue in the
## recipe (`move` -22 dBFS, `press` -18, `back` -20) and are already pitched to
## sit under the menu bed. There is no bus layout in this project yet, so a
## file's own level IS the mix; this stays at 0 until there is something to
## balance it against.
const VOLUME_DB := 0.0

## What counts as MOVING between options. Focus also changes when a screen
## opens and hands it to its first control, when a panel closes and hands it
## back, and when a dialog pops - none of which the player did, and all of
## which would tick. So the move cue fires only when focus changed on a frame
## the player actually pressed a navigation key, which is precise where
## "had something else been focused?" is a guess.
##
## The built-in `ui_*` actions rather than the game's own `move_*`: menu focus
## is navigated by the engine through these, and the two are deliberately not
## the same map (see tools/setup_project.gd - `move_up` is W and is physical).
const NAVIGATION: Array[StringName] = [
	&"ui_up", &"ui_down", &"ui_left", &"ui_right",
	&"ui_focus_next", &"ui_focus_prev",
]

var _players := {}
## Frame of the last navigation press, compared against the frame a focus
## change arrives on. `_input` runs before the viewport resolves focus
## navigation, so the two land on the same frame.
var _navigated := -1
## id -> frame it last played on. One cue fires at most once per frame, which
## is `player.gd`'s rule for `hit` - a heavy landing on four bodies is one
## impact, not four copies of one clip started together, which is a click.
## Here it covers the honest double-ups: a settings panel and the pause menu
## behind it both seeing one Escape, or a dropdown reporting a selection twice.
var _fired := {}
## id -> how many times it has actually played. The readout, on `Music.track()`'s
## terms: a headless run has a dummy audio driver under which `playing` is false
## and `get_playback_position()` is a coin flip, so a count kept where the sound
## is really started is the only honest evidence a cue fired - and it is the
## only thing that can show the per-frame guard doing its job, which is a
## SUPPRESSED second play and therefore invisible in every other way.
var _plays := {}


func _ready() -> void:
	# A menu is the one thing that must still be audible while everything else
	# in the game is frozen.
	process_mode = Node.PROCESS_MODE_ALWAYS

	for id in CUES:
		var stream := load(CUES[id]) as AudioStream
		if stream == null:
			# Not an error: an un-imported WAV is what a fresh checkout looks
			# like, and quiet menus are better than a broken boot.
			continue
		var player := AudioStreamPlayer.new()
		player.name = "Sfx_%s" % id
		player.stream = stream
		player.volume_db = VOLUME_DB
		add_child(player)
		_players[id] = player

	get_tree().root.gui_focus_changed.connect(_on_focus_changed)
	get_tree().node_added.connect(_on_node_added)
	# Autoloads are readied before the main scene, so `node_added` sees every
	# button in the game. Anything already standing is a scene built by hand -
	# which is what the test suites do.
	_hook_tree(get_tree().root)


func _input(event: InputEvent) -> void:
	for action in NAVIGATION:
		if event.is_action_pressed(action):
			_navigated = Engine.get_process_frames()
			return


## Fire a cue. An unknown id is silence, deliberately, and so is a known id
## whose file never loaded.
func play(id: StringName) -> void:
	var player: AudioStreamPlayer = _players.get(id)
	if player == null:
		return
	var frame := Engine.get_process_frames()
	if _fired.get(id, -1) == frame:
		return
	_fired[id] = frame
	_plays[id] = int(_plays.get(id, 0)) + 1
	player.play()


## Backing out: a panel closing, or the pause menu opening or closing. Said by
## the screen that handled the press rather than heard globally - see the
## header for why that one is not automatic.
func back() -> void:
	play(&"back")


## Whether a cue's file is loaded and ready to make a noise. For callers who
## want to know, and for the suite that checks every cue resolved.
func has(id: StringName) -> bool:
	return _players.has(id)


## How many times a cue has fired this run. See `_plays` for why a count rather
## than a flag, and why anything is exposed at all.
func plays(id: StringName) -> int:
	return int(_plays.get(id, 0))


func _on_focus_changed(node: Control) -> void:
	if node == null:
		return
	# Focus was GRANTED rather than moved - a screen opening, a panel handing
	# it back - so there was nothing for the player to hear moving.
	if Engine.get_process_frames() != _navigated:
		return
	play(&"move")


func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button != null:
		_connect(button.pressed, play.bind(&"press"))
		# A dropdown's own list is navigated inside a PopupMenu, which is not a
		# Control and never takes focus - so without this the settings page
		# goes silent exactly where it has the most options.
		var option := node as OptionButton
		if option != null:
			_hook_popup(option.get_popup())
		return

	var popup := node as PopupMenu
	if popup != null:
		_hook_popup(popup)


## Walk what is already in the tree. Only reaches anything when a scene was
## built before this ran, which outside the tests is never.
func _hook_tree(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_hook_tree(child)


func _hook_popup(popup: PopupMenu) -> void:
	if popup == null:
		return
	# `id_focused` is emitted only for keyboard navigation, which is already
	# exactly the move cue's question - so it needs no frame check of its own.
	_connect(popup.id_focused, _on_popup_moved)
	_connect(popup.index_pressed, _on_popup_pressed)


func _on_popup_moved(_id: int) -> void:
	play(&"move")


func _on_popup_pressed(_index: int) -> void:
	play(&"press")


## Connect once. A node can enter the tree more than once, and a second
## connection would fire the cue twice - which the per-frame guard would catch,
## but a leak is better not made than caught.
func _connect(sig: Signal, target: Callable) -> void:
	if not sig.is_connected(target):
		sig.connect(target)
