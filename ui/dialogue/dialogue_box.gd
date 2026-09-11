extends Control
## The subtitle box: who is speaking, what they are saying, and - when a line
## asks a question - what the player can say back.
##
## Deliberately dumb, exactly like the HUD and the level card: it is handed a
## name and a string and it renders them. It does not know what an NPC is, what
## a conversation is, or what comes next. `game/dialogue/dialogue_director.gd`
## knows all of that and drives this through four calls.
##
## ## Subtitles first, voice second
##
## There is no audio in the game yet, and this is built so that adding it is a
## change in ONE place. `say()` already takes a `voice` path and hands it to
## `_play_voice()`, which is the stub that will one day feed an AudioStreamPlayer
## - so every line in every conversation is already carrying its clip, and no
## conversation data has to be rewritten when the clips arrive.
##
## The reveal rate is the other half of that bet. Text types out at
## CHARS_PER_SECOND today; when a line has a clip, the rate that matters is the
## clip's LENGTH, and `_reveal_rate()` is the one function that has to learn it.
## Both halves are marked TODO(audio).
##
## ## Sized against the 640x360 design viewport
##
## 592 px wide, 10 px off the bottom, with the speaker's name on its own row
## above a rule and the line beneath.
##
## **The panel is as tall as the line in it and no taller** - 34 px for one
## line, 15 more for each line after. A fixed box has to reserve room for the
## longest thing anyone might ever say, and since almost nothing in the game
## says two lines, that reserve is empty space under the text on nearly every
## beat: it reads as a menu that has lost something rather than as somebody
## talking. `_fit_panel()` measures instead, off the LABEL's own wrapped line
## count rather than off a re-measure of the string, so the box cannot disagree
## with the text it is drawing and no line can ever be clipped out of view.
##
## It resizes only in `say()`, between beats, and only the TOP edge moves - the
## bottom is pinned. So the box never changes height under a line being read.
##
## Choices go ABOVE the panel rather than inside it: at one line tall there is
## no inside. They ride on the panel's top edge and carry their own outline
## instead of a second panel, because they are read against the room.

signal advanced
signal chose(index: int)

## Typewriter rate. Fast enough not to be a wait, slow enough that a line reads
## as delivered rather than pasted.
const CHARS_PER_SECOND := 45.0
## Blink period of the "there is more" caret, in seconds.
const BLINK_SECONDS := 0.5

## Panel geometry, in design pixels against the 640x360 viewport. Everything
## except the line count itself, which is measured - see _fit_panel().
const PANEL_BOTTOM := 10.0    ## gap between the panel and the bottom of screen
const TEXT_TOP := 18.0        ## the name row and its rule, above the first line
const TEXT_BOTTOM := 4.0      ## padding under the last line
const OPTIONS_GAP := 8.0      ## between the choices and the top of the panel

@onready var _panel: Control = %Panel
@onready var _speaker: Label = %Speaker
@onready var _line: Label = %Line
## A blinking block rather than a glyph: the box is pixel art and the font is
## not guaranteed to carry a triangle.
@onready var _caret: ColorRect = %Caret
@onready var _options: VBoxContainer = %Options

## How many characters of the current line are on screen, as a float so the
## reveal is not quantised to the frame rate.
var _revealed := 0.0
## The choices on offer, or empty while the box is just talking.
var _choices: Array = []
var _pick := 0
var _blink := 0.0


func _ready() -> void:
	close()


## Put a line on screen. `voice` is the clip that will one day play with it -
## see the class docs; today it is carried and ignored.
func say(speaker: String, text: String, voice := "") -> void:
	_speaker.text = speaker
	_line.text = text
	_line.visible_characters = 0
	_revealed = 0.0
	_choices = []
	_options.visible = false
	_caret.visible = false
	_blink = 0.0
	# Before it is shown, so the box never appears at the last line's height
	# and snaps to this one's.
	_fit_panel()
	visible = true
	_play_voice(voice)
	set_process(true)
	set_process_unhandled_input(true)


## Offer the player something to say. Only legal after `say()`: a question is a
## line WITH answers, never answers on their own, so the box never asks
## something nobody has heard.
func offer(choices: Array) -> void:
	_choices = choices
	_pick = 0
	# Removed as well as freed: queue_free() lands at the end of the frame, and
	# _paint_choices() below would otherwise index rows that are on their way
	# out as though they were the new ones.
	for child in _options.get_children():
		_options.remove_child(child)
		child.queue_free()
	for i in choices.size():
		var row := Label.new()
		row.add_theme_font_override("font", _line.get_theme_font("font"))
		row.add_theme_font_size_override("font_size", 16)
		row.add_theme_color_override("font_color", Color("c8ccd8"))
		# Choices sit over the room, not over the panel, so each row carries
		# its own outline - the same trick the level card uses.
		row.add_theme_color_override("font_outline_color", Color("14161f"))
		row.add_theme_constant_override("outline_size", 4)
		_options.add_child(row)
	# Shown only once the line has finished typing - see _process. A question
	# whose answers appear before the question does reads as a menu.
	_options.visible = false
	_paint_choices()


func close() -> void:
	visible = false
	_choices = []
	set_process(false)
	set_process_unhandled_input(false)


## True while characters are still appearing. The director does not care; the
## first press does - it completes the line instead of advancing past it.
func revealing() -> bool:
	return _line.visible_characters < _line.text.length()


func reveal_all() -> void:
	_revealed = float(_line.text.length())
	_line.visible_characters = _line.text.length()


func _process(delta: float) -> void:
	if revealing():
		_revealed += delta * _reveal_rate()
		_line.visible_characters = mini(int(_revealed), _line.text.length())
		return

	# The line is finished, so whatever it was waiting to show can appear.
	if not _choices.is_empty():
		_options.visible = true
		return
	_blink += delta
	_caret.visible = fmod(_blink, BLINK_SECONDS * 2.0) < BLINK_SECONDS


## Handled rather than polled, so a press cannot be counted by both this box
## and the NPC standing behind it in the same frame. The director's own guard
## covers the rest (see dialogue_director.gd's cooldown).
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if not _choices.is_empty() and not revealing():
		if event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
			_move_pick(-1)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
			_move_pick(1)
			get_viewport().set_input_as_handled()
			return

	if not (event.is_action_pressed("interact") or event.is_action_pressed("attack")):
		return
	get_viewport().set_input_as_handled()

	# The first press always completes the line. Nothing is ever skipped past
	# unread, and mashing still moves at the reader's pace rather than eating a
	# line whole.
	if revealing():
		reveal_all()
		return
	if _choices.is_empty():
		advanced.emit()
	else:
		chose.emit(_pick)


## Grows the panel upward to hold exactly the line it was just given, and takes
## the choices up with it.
##
## The line count comes from the Label, which has already wrapped the text by
## the time `text` is assigned - no frame in between, and no second opinion. A
## re-measure through the font would be a second opinion, and the one time it
## disagreed the box would clip a line the player then could not read.
func _fit_panel() -> void:
	var font := _line.get_theme_font("font")
	var size := _line.get_theme_font_size("font_size")
	var lines := maxi(_line.get_line_count(), 1)
	var step := font.get_height(size) + _line.get_theme_constant("line_spacing")
	var height := TEXT_TOP + font.get_height(size) + step * (lines - 1) + TEXT_BOTTOM
	_panel.offset_top = -(PANEL_BOTTOM + height)
	_options.offset_top = _panel.offset_top - OPTIONS_GAP
	_options.offset_bottom = _options.offset_top


func _move_pick(step: int) -> void:
	_pick = wrapi(_pick + step, 0, _choices.size())
	_paint_choices()


## The selected row is marked with a caret and lit; the rest sit back. A
## pointer rather than a highlight bar, because the box is 1px-bordered pixel
## art and a filled bar at this size reads as a second panel.
func _paint_choices() -> void:
	for i in _options.get_child_count():
		var row := _options.get_child(i) as Label
		var picked := i == _pick
		row.text = ("> " if picked else "  ") + String(_choices[i])
		row.add_theme_color_override("font_color",
			Color("f2d479") if picked else Color("9aa0b0"))


## Characters per second for the line on screen.
##
## TODO(audio): when the line has a clip, this becomes text length divided by
## the clip's length, so the subtitle finishes with the voice instead of racing
## it. Everything that would need to change is here and in _play_voice().
func _reveal_rate() -> float:
	return CHARS_PER_SECOND


## TODO(audio): feed an AudioStreamPlayer. Deliberately a real parameter on
## `say()` already, so conversation data can carry its clip paths from today and
## none of it needs rewriting when the clips exist.
func _play_voice(_voice: String) -> void:
	pass
