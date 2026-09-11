extends "res://tests/helpers.gd"
## Dialogue test: the subtitle box, the choices, the escorted tour and HR's
## unrefusable contract. Boots into the lobby, which is the one floor she is
## standing on, and has her whole induction out.
##
## **Driven by what is on screen, not by frame numbers.** From the moment the
## conversation opens, `_tick` presses advance whenever the box is waiting and
## answers whenever it is asking, recording every line as it goes - so the
## checks at the end read the conversation that actually happened. Betting on
## frame numbers here would mean re-timing the whole file every time a line is
## reworded, since a line's length IS its duration.
##
## The one stretch that is scripted by hand is the first: the typewriter and
## the "the stick is dead while she talks" check both need the auto-advance to
## stop pressing for a moment.

## Presses this often while the box is up. The first press of a line completes
## its reveal and the second advances, so a line costs two of these - fast
## enough to get through an induction, slow enough that no press is dropped.
const ADVANCE_EVERY := 6
## Answers picked in order, by index, as each question comes up:
## 1 - "JUST... HR?"        (the side branch, reached by moving the selection)
## 1 - "NOT RIGHT NOW"      (refusing, which she does not accept)
## 2 - "LET ME READ IT"     (the contract, which cannot be read)
## 0 - "SIGN IT"            (the only way out of the room)
const ANSWERS := [1, 1, 2, 0]

var _hr: Node2D
## Every line delivered, in order, as "SPEAKER|text".
var _said: Array[String] = []
var _asked := 0
var _done := false
## Set while the hand-scripted opening stretch owns the keyboard.
var _held := true
## Where the player was when HR set off, and the widest gap that opened up
## between them on the way - the escort's whole job in one number.
var _escort_mark := Vector2.ZERO
var _escort_gap := 0.0
var _escorted := 0.0
var _walked := false
## The contract, captured while it was up: it is freed the moment she takes it
## back, so a check at the end has nothing left to read.
var _contract_body := ""
var _contract_header := ""
var _prompt_during := false
var _moved_while_talking := 0.0
## The panel sizes itself to the line it is given, so these two are the whole
## of that promise: the tallest it ever got, and whether any line was ever
## taller than the rect drawing it.
var _tallest_box := 0.0
var _clipped := ""


func _tick(frame: int) -> void:
	# Nothing to watch until the game scene is up: frames 1-17 are still the
	# main menu, which has no player, no room and no box in it.
	if _hr != null:
		_watch()
		if not _held:
			_drive(frame)

	match frame:
		2:
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		17:
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
		32:
			_hr = _level().get_node_or_null("Props/HrLady")
			_check("npc: HR is standing in the lobby",
				_hr != null and _hr.global_position == Vector2(356, 226))
			# The whole of what makes her friendly - see game/npcs/CLAUDE.md.
			# Nothing in this game reaches anything by type, so being in
			# neither of the two fighting groups is the entire mechanism.
			_check("npc: friendly by group, not by flag",
				_hr.is_in_group("npcs") and not _hr.is_in_group("enemies")
					and not _hr.is_in_group("player"))
			_check("npc: no prompt while nobody is near her",
				not (_hr.get_node("Prompt") as Control).visible)
			_check("dialogue: the box starts closed", not _box().visible)
			_dialogue().connect("finished", func(_npc) -> void: _done = true)
			# Walked to rather than teleported onto: her talk radius is an
			# Area2D, and an overlap that exists before the first physics frame
			# is an overlap that never emits body_entered.
			_player().global_position = Vector2(300, 226)
		40:
			_player().global_position = Vector2(336, 226)
		52:
			_check("npc: the prompt comes up in range",
				(_hr.get_node("Prompt") as Control).visible)
			_key(KEY_E, true)
		54:
			_key(KEY_E, false)
		58:
			_check("dialogue: E opens the box, with her name on it (got '%s')"
				% _speaker(), _box().visible and _speaker() == "HR")
			_check("dialogue: the line types out rather than appearing whole "
				+ "(%d of %d chars)"
				% [_line().visible_characters, _line().text.length()],
				_line().visible_characters < _line().text.length())
			_prompt_during = not (_hr.get_node("Prompt") as Control).visible
			_check("npc: the prompt goes away while she is talking",
				_prompt_during)
			_check("player: the world has the wheel",
				bool(_player().call("scripted")))
			# The stick, hard over, for twenty frames. A conversation that can
			# be walked out of is a conversation the player can strand.
			_mark = _player().global_position
			_key(KEY_D, true)
		78:
			_key(KEY_D, false)
			_moved_while_talking = _player().global_position.distance_to(_mark)
			_check("player: the stick is dead while she is talking (%.1f px)"
				% _moved_while_talking, _moved_while_talking < 1.0)
			_key(KEY_E, true)
		80:
			_key(KEY_E, false)
		84:
			_check("dialogue: one press finishes the line instead of skipping "
				+ "it (%d of %d chars)"
				% [_line().visible_characters, _line().text.length()],
				_box().visible
					and _line().visible_characters == _line().text.length())
			# Escape, mid-sentence. Dialogue does NOT pause the tree - it
			# cannot, the guide has to walk while she talks - so the pause menu
			# has to still work over the top of an open conversation.
			_key(KEY_ESCAPE, true)
		90:
			_key(KEY_ESCAPE, false)
		96:
			_check("pause: Escape still opens the menu mid-conversation",
				paused and _pause_menu().get_node("Root").visible)
			_check("pause: the box stays on screen behind it",
				_box().visible and bool(_dialogue().call("talking")))
			# The advance key, while paused. The box is PAUSABLE like the rest
			# of the room, so this must reach nothing at all - a conversation
			# read through a paused game is a conversation nobody is in.
			_key(KEY_E, true)
		98:
			_key(KEY_E, false)
		104:
			_check("pause: advancing does nothing while the game is paused",
				paused and bool(_dialogue().call("talking")))
			_key(KEY_ESCAPE, true)
		106:
			_key(KEY_ESCAPE, false)
		118:
			_check("pause: the conversation picks up where it left off",
				not paused and _box().visible
					and bool(_dialogue().call("talking")))
			# From here the conversation runs itself - see _drive().
			_held = false

	if _done:
		_report()
	elif frame == 3000:
		_check("dialogue: the induction finished inside 3000 frames", false)
		_report()


## Answers and advances. Everything the box can be doing has one response:
## asking - answer it; talking - press on; walking - wait.
func _drive(frame: int) -> void:
	if _done or not _box().visible:
		return
	if frame % ADVANCE_EVERY == 3:
		_key(KEY_E, false)
		return
	if frame % ADVANCE_EVERY != 0:
		return

	var options := _choices()
	if options.visible and options.get_child_count() > 0:
		_answer(options)
		return
	_key(KEY_E, true)


## Moves the selection to the planned answer one row at a time and takes it,
## which is also the check that moving the selection works: the row it lands on
## is the one that gets picked, and the branch it leads to shows up in `_said`.
func _answer(options: VBoxContainer) -> void:
	var want: int = ANSWERS[mini(_asked, ANSWERS.size() - 1)]
	var row := _selected(options)
	if row < 0:
		return
	if row != want:
		_key(KEY_S, true)
		_key(KEY_S, false)
		return
	_asked += 1
	_key(KEY_E, true)


## Which row is lit, read off the caret the box paints rather than off any
## private state of it.
func _selected(options: VBoxContainer) -> int:
	for i in options.get_child_count():
		if (options.get_child(i) as Label).text.begins_with(">"):
			return i
	return -1


## Runs every frame from boot: records each new line, measures the escort, and
## reads the contract while it is still on screen.
func _watch() -> void:
	if _box().visible and _line().text != "":
		var entry := "%s|%s" % [_speaker(), _line().text]
		if _said.is_empty() or _said[-1] != entry:
			_said.append(entry)

	if _box().visible:
		_tallest_box = maxf(_tallest_box, (_box().get_node("%Panel") as Control).size.y)
		# get_visible_line_count() is how many of the wrapped lines fit in the
		# label's rect. Fewer than there are is a line the player cannot read.
		if _line().get_visible_line_count() < _line().get_line_count():
			_clipped = _line().text

	var page := _overlay().get_node_or_null("ContractPanel")
	if page != null and _contract_body == "":
		_contract_body = (page.get_node("%Body") as Label).text
		_contract_header = (page.get_node("Page/Header") as Label).text

	if _hr == null or not bool(_hr.call("walking")):
		return
	if not _walked:
		_walked = true
		_escort_mark = _player().global_position
	_escorted = maxf(_escorted, _player().global_position.distance_to(_escort_mark))
	_escort_gap = maxf(_escort_gap,
		_player().global_position.distance_to(_hr.global_position))


func _report() -> void:
	var script := "\n".join(_said)

	_check("dialogue: she introduces herself (%d lines)" % _said.size(),
		script.contains("I'm HR. Just HR."))
	_check("choice: picking the second answer took the second branch",
		script.contains("A person can leave. A department can't."))

	# The tour. She has to have actually gone somewhere, and the player has to
	# have been taken along - a guide who walks off alone is a guide the player
	# watches from across the room.
	_check("tour: she leaves her post and comes back to it (%s)"
		% _hr.global_position,
		_walked and _hr.global_position.distance_to(Vector2(356, 226)) < 24.0)
	_check("escort: the player is towed along behind her (%.0f px moved)"
		% _escorted, _escorted > 80.0)
	_check("escort: and is never left behind (widest gap %.0f px)"
		% _escort_gap, _escort_gap < 90.0)
	_check("tour: she stops at the front desk on the way (%d lines)"
		% _said.size(), script.contains("She came in for a two-week contract."))

	# The contract, and the two jokes in it.
	_check("contract: refusing gets the line rather than the exit",
		script.contains("Oh, it's so simple. Just sign it."))
	_check("contract: it was raised while she talked over it",
		_contract_header == "EMPLOYMENT AGREEMENT")
	_check("contract: and it is unreadable (%d chars)" % _contract_body.length(),
		_contract_body.length() > 200 and not _contract_body.contains(" the ")
			and _contract_body.contains("\n"))
	_check("contract: it is taken away again when she is done with it",
		_overlay().get_node_or_null("ContractPanel") == null)
	_check("contract: signing is the only way out of the induction",
		script.contains("Welcome to the company."))

	# The box is as tall as what is in it. 34 px is one line of KenneyPixel at
	# 16 with the name row above it; every line in the induction is one line,
	# so nothing in this conversation should ever have grown it.
	_check("box: it is sized to the line, not to the longest line there could "
		+ "be (tallest %.0f px)" % _tallest_box,
		_tallest_box > 0.0 and _tallest_box <= 50.0)
	_check("box: and no line was ever taller than the box drawing it (%s)"
		% ("none" if _clipped == "" else _clipped), _clipped == "")

	# And the body comes back.
	_check("player: the wheel is handed back at the end",
		not bool(_player().call("scripted")))
	_check("dialogue: the box closes with it", not _box().visible)
	_check("npc: the prompt comes back up, so she can be talked to again",
		(_hr.get_node("Prompt") as Control).visible)

	_finish()
