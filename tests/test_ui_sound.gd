extends "res://tests/helpers.gd"
## The menu's noise: that moving between options ticks, that choosing one
## chimes, that backing out chimes lower, and - the half that is harder and is
## most of this file - that none of the three fires when nothing happened.
##
## Its own suite rather than a section of test_menu.gd for a reason that is
## about the WORLD rather than about tidiness. Every check here is a DELTA on a
## play count across one action, so the suite has to own the focus state of the
## screen for its whole length: a stray `grab_focus` between two frames is a
## tick this file would blame on the frame after it. test_menu.gd's later
## sections deliberately move focus about - the settings panel opening, Back
## restoring focus to the button that opened it - which is exactly the traffic
## that cannot be running underneath a counter.
##
## Nothing here reads `AudioStreamPlayer.playing` or `get_playback_position()`.
## A headless run has a dummy audio driver, under which the first is false even
## for a stream that is really mixing, and `--fixed-fps` makes the second a coin
## flip (test_menu.gd's note has the long version). The evidence is instead
## structural - the streams resolved, they are one-shots, they are the right
## length - plus `UiSound.plays()`, a count kept at the one line where a sound
## is really started. A suppressed play is invisible in every other way, so a
## count is the only thing that can show the per-frame guard working at all.

## Baselines, so every check reads as "this action cost exactly one chime".
var _move := 0
var _press := 0
var _back := 0
var _pause: CanvasLayer = null


func _ui() -> Node:
	return _autoload("UiSound")


func _plays(cue: StringName) -> int:
	return _ui().call("plays", cue)


## Take the three counts, so the next check can compare against them.
func _mark_counts() -> void:
	_move = _plays(&"move")
	_press = _plays(&"press")
	_back = _plays(&"back")


func _sfx(cue: String) -> AudioStreamPlayer:
	return _ui().get_node_or_null("Sfx_" + cue) as AudioStreamPlayer


func _tick(frame: int) -> void:
	match frame:
		4:
			# The files first. Every cue the menus fire has to resolve, and a
			# miss here is silent by design - so nothing but this would notice
			# a renamed file or a WAV that never got an import pass.
			for cue in ["move", "press", "back"]:
				_check("sfx: the %s cue resolved to a stream" % cue,
					_ui().call("has", StringName(cue)))
				var stream: AudioStream = null
				if _sfx(cue) != null:
					stream = _sfx(cue).stream
				_check("sfx: %s is a WAV with real length (%.3fs)" % [cue,
					0.0 if stream == null else stream.get_length()],
					stream is AudioStreamWAV and stream.get_length() > 0.0)
				# The inverse of every other audio check in this project. The
				# wraith's drain and the charge stance are bugs unless they
				# loop; a menu tick is a bug if it EVER does, and a stray
				# loop_mode in a .import would be a blip that never stops.
				_check("sfx: %s is a one-shot, not a loop" % cue,
					stream is AudioStreamWAV
					and (stream as AudioStreamWAV).loop_mode
						== AudioStreamWAV.LOOP_DISABLED)

			# The main menu handed focus to PLAY in its _ready. That is focus
			# GRANTED, not focus moved, and a menu that chimes at itself on the
			# way in is the first thing anybody would report.
			_check("sfx: opening the menu is silent (move %d, press %d, back %d)"
				% [_plays(&"move"), _plays(&"press"), _plays(&"back")],
				_plays(&"move") == 0 and _plays(&"press") == 0
					and _plays(&"back") == 0)
			_mark_counts()
			_key(KEY_DOWN, true)
		6:
			_key(KEY_DOWN, false)
		8:
			# The headline: a navigation key moved focus, and that cost exactly
			# one tick. It also proves the ordering the whole move cue rests on
			# - that `_input` sees the press before the viewport resolves focus
			# navigation, so the two land on one frame and the stamp matches.
			_check("sfx: arrowing off Play moves focus to Mode",
				(current_scene.get_node("%ModeButton") as Button).has_focus())
			_check("sfx: and ticks exactly once (%d)" % (_plays(&"move") - _move),
				_plays(&"move") - _move == 1)
			_check("sfx: moving is not pressing",
				_plays(&"press") == _press and _plays(&"back") == _back)
			_mark_counts()
			_key(KEY_DOWN, true)
		10:
			_key(KEY_DOWN, false)
		12:
			_check("sfx: a second arrow ticks again (%d)"
				% (_plays(&"move") - _move), _plays(&"move") - _move == 1)
			_check("sfx: and lands on Settings",
				(current_scene.get_node("%SettingsButton") as Button).has_focus())
			_mark_counts()
			# Pressed rather than a synthesized Enter, and that is the check:
			# nothing in main_menu.tscn registers itself with UiSound, so a
			# chime here can only have come from `node_added` hooking the
			# button on its way into the tree.
			(current_scene.get_node("%SettingsButton") as Button).pressed.emit()
		14:
			_check("sfx: pressing a button chimes once (%d)"
				% (_plays(&"press") - _press), _plays(&"press") - _press == 1)
			_check("settings: the panel opened", _panel(current_scene).visible)
			# The other half of the rule, and the one a naive implementation
			# gets wrong: the panel took focus off the Settings button and gave
			# it to the dropdown. Nobody navigated, so nobody should hear a
			# move on top of the press.
			_check("sfx: the panel taking focus is not a move (%d)"
				% (_plays(&"move") - _move), _plays(&"move") - _move == 0)
			_mark_counts()
			_key(KEY_ESCAPE, true)
		16:
			_key(KEY_ESCAPE, false)
		18:
			_check("settings: Escape closed the panel",
				not _panel(current_scene).visible)
			_check("sfx: backing out chimes once (%d)" % (_plays(&"back") - _back),
				_plays(&"back") - _back == 1)
			_mark_counts()
			# A dropdown's list is a PopupMenu, which is not a Control and never
			# takes focus - so the settings page would be silent exactly where
			# it has the most options unless these two are hooked as well.
			var popup := _mode_option(current_scene).get_popup()
			popup.id_focused.emit(0)
			popup.index_pressed.emit(0)
		20:
			_check("sfx: arrowing inside a dropdown ticks (%d)"
				% (_plays(&"move") - _move), _plays(&"move") - _move == 1)
			_check("sfx: and choosing from one chimes (%d)"
				% (_plays(&"press") - _press), _plays(&"press") - _press == 1)
			_mark_counts()
			# The guard, in the one situation it exists for: two handlers
			# reaching the same cue on one frame. Restarting a player 3 ms into
			# its own clip is a click, and the settings panel and the pause menu
			# behind it really do both see one Escape.
			_ui().call("play", &"move")
			_ui().call("play", &"move")
			_ui().call("play", &"move")
		22:
			_check("sfx: three plays on one frame is one sound (%d)"
				% (_plays(&"move") - _move), _plays(&"move") - _move == 1)
			_mark_counts()

			# The death screen, built by hand rather than by dying - this suite
			# never enters the game, and the claim being tested is about one
			# key in one screen. test_reinforcements.gd builds its beat in the
			# empty lobby for the same reason.
			_pause = (load("res://ui/pause_menu/pause_menu.tscn") as PackedScene
				).instantiate()
			root.add_child(_pause)
		24:
			_pause.call("show_game_over")
			_check("pause: the death screen is up", _pause.call("is_paused"))
			_mark_counts()
			_key(KEY_ESCAPE, true)
		26:
			_key(KEY_ESCAPE, false)
		28:
			# The reason `back` is said by the three screens that handle Escape
			# rather than heard globally off `ui_cancel`. A finished run
			# swallows the key, and a chime on a press that did nothing teaches
			# the player the sound does not mean anything happened - which is
			# `hit` firing only on a blow that LANDED, arriving from the other
			# side of the game.
			_check("sfx: Escape on the death screen is swallowed AND silent (%d)"
				% (_plays(&"back") - _back), _plays(&"back") - _back == 0)
			_check("pause: and the death screen is still up",
				_pause.call("is_paused"))
			_mark_counts()
			# The same key, in the same screen, on a press that DOES something.
			_pause.call("resume")
			_pause.call("pause")
		30:
			_check("pause: paused normally this time", _pause.call("is_paused"))
			_check("sfx: opening the pause menu took no focus tick (%d)"
				% (_plays(&"move") - _move), _plays(&"move") - _move == 0)
			_mark_counts()
			_key(KEY_ESCAPE, true)
		32:
			_key(KEY_ESCAPE, false)
		34:
			_check("pause: Escape resumed", not _pause.call("is_paused"))
			_check("sfx: and that one DID chime (%d)" % (_plays(&"back") - _back),
				_plays(&"back") - _back == 1)
			# Leave the tree as it was found: the suite pauses it above, and a
			# paused tree outliving the check that needed it is how one file's
			# world reaches the next.
			root.remove_child(_pause)
			# free() rather than queue_free(): _finish() quits on this frame, so
			# a queued deletion is never flushed and the node is reported as a
			# leak at exit.
			_pause.free()
			paused = false
			_finish()
