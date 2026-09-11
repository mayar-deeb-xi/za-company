extends Node2D
## What one boss SAYS. `boss_audio.gd` is the same idea for the noises he makes,
## and the split is the same one: the mechanism is shared, the lines are not.
##
## A boss's scene gets a `Lines` child naming a `.gd`; that file holds
## `const LINES` - a cue, and the things he says on it - and `boss_base` already
## calls the cues. So a boss talks by owning a file, exactly the deal his HUD
## bar, his theme and his grunts are on, and a boss with no `Lines` child says
## nothing with no branch anywhere but `_say`.
##
## Positional (AudioStreamPlayer2D) for the same reason his grunts are, and
## `extends Node2D` for the same reason too: a Node2D under a plain Node is cut
## off from the transform above it and would speak from the corner of the map.
##
## ## What is here is WHEN, not what
##
## The lines are data. What lives here is the policy that stops a man with
## twenty of them from reading all twenty at once:
##
## - **One line at a time.** While a line is still on screen nothing else is
##   said, so a subtitle is never overwritten part-read.
## - **A cue is on a cooldown.** He has a line for being hit; he is hit sixteen
##   times. `cue_seconds` is how long that cue waits before it may speak again,
##   and `cooldowns` overrides it per cue for the ones that should be rarer or
##   more eager than the rest.
## - **Never the same line twice running.** A cue with more than one line picks
##   from the others, so hearing a repeat means he has genuinely run out of
##   things to say rather than that the dice went that way.
## - **Two cues jump the queue.** Laying eyes on the player and going down are
##   the two moments that must land whatever else is happening, and `ALWAYS`
##   says them over anything.
##
## ## The clip is optional and it is the point
##
## A line may carry `voice`, a path to its recording, and `say()` plays it and
## returns its LENGTH as the line's duration - which is the one piece of
## arithmetic a subtitle can never guess for itself. Every miss is legal, on
## exactly the terms his grunts are: a line with no clip, a clip not recorded
## yet, and a fresh checkout whose WAVs have not been imported all land in the
## same check and play nothing, and the line still reads for as long as it takes
## to read.

## Cues that are said whatever else is going on - no gap, no cooldown.
const ALWAYS := ["spot", "concede"]

## The conversation file: a `.gd` holding `const LINES`. Pure data, no code,
## living with the boss who says it, on the placement rule an NPC's own
## conversation already follows.
@export_file("*.gd") var lines := ""

@export_group("Timing")
## Silence after a line before another may start, so two barks never run
## together into one wall of text.
@export var gap_seconds := 0.45
## The shortest a line stays up, however short it is. "Burn!" still has to be
## seen.
@export var min_seconds := 1.5
## Reading rate, which is what decides a longer line's hold. Deliberately well
## under the dialogue box's typing rate: that one is read at the reader's pace
## with the world waiting, and this one is read out of the corner of an eye
## while an axe comes down.
@export var chars_per_second := 13.0
## How long a cue waits before it may speak again.
@export var cue_seconds := 9.0
## Per-cue overrides of the above, for the ones that should come round sooner
## or later than the rest.
@export var cooldowns: Dictionary = {}

@export_group("Voice")
@export var volume_db := 0.0
## Flat across a room, then gone - his grunts' numbers, for his grunts' reason.
@export var max_distance := 600.0
@export var attenuation := 0.2

var _lines := {}
## cue -> seconds until it may speak again.
var _cooldown := {}
## cue -> the index it used last, so the next pick can avoid it.
var _last := {}
## Seconds until anything at all may be said.
var _held := 0.0

var _voice: AudioStreamPlayer2D


func _ready() -> void:
	if lines != "":
		# Read off the Script rather than an instance of it, exactly as the
		# dialogue director reads a conversation: a line file is data with
		# nothing to construct.
		var script := load(lines) as GDScript
		if script == null:
			push_warning("boss lines: nothing at %s" % lines)
		else:
			_lines = script.get_script_constant_map().get("LINES", {})
	_voice = AudioStreamPlayer2D.new()
	_voice.name = "Voice"
	_voice.volume_db = volume_db
	_voice.max_distance = max_distance
	_voice.attenuation = attenuation
	add_child(_voice)


func _process(delta: float) -> void:
	_held = maxf(_held - delta, 0.0)
	for cue in _cooldown:
		_cooldown[cue] = maxf(_cooldown[cue] - delta, 0.0)


## A line for `cue`, as {"text", "seconds"} - or {} for nothing to say, which
## is the answer most of the time and is not a failure: a cue with no lines, a
## cue still cooling down, and a cue arriving while he is already mid-sentence
## all come back empty and the fight carries on.
func say(cue: String) -> Dictionary:
	var choices: Array = _lines.get(cue, [])
	if choices.is_empty():
		return {}
	var forced := cue in ALWAYS
	if not forced and (_held > 0.0 or float(_cooldown.get(cue, 0.0)) > 0.0):
		return {}

	var pick := _pick(cue, choices.size())
	var line: Dictionary = choices[pick]
	var text := String(line.get("text", ""))
	if text == "":
		return {}

	var seconds := maxf(min_seconds, text.length() / maxf(chars_per_second, 1.0))
	seconds = maxf(seconds, _play_voice(String(line.get("voice", ""))))
	_last[cue] = pick
	_held = seconds + gap_seconds
	# Never shorter than the line itself: a cooldown under the hold would let a
	# cue queue up behind its own subtitle.
	_cooldown[cue] = maxf(float(cooldowns.get(cue, cue_seconds)), seconds)
	return {"text": text, "seconds": seconds}


## A different line from the one this cue used last, while there is one.
func _pick(cue: String, count: int) -> int:
	if count == 1:
		return 0
	var last := int(_last.get(cue, -1))
	var pick := randi() % count
	return (pick + 1) % count if pick == last else pick


## The clip, if the line named one and it is actually on disk, and how long it
## runs. See the header: every miss is legal and returns 0.0, which leaves the
## line held for as long as it takes to READ instead.
func _play_voice(path: String) -> float:
	if path == "" or not ResourceLoader.exists(path):
		return 0.0
	var stream := load(path) as AudioStream
	if stream == null:
		return 0.0
	_voice.stream = stream
	_voice.volume_db = volume_db
	_voice.play()
	return stream.get_length()
