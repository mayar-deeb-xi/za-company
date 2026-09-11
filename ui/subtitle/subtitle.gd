extends Control
## What a boss shouts, at the bottom of the screen, while the fight carries on
## around it.
##
## Deliberately dumb, exactly like the HUD and the level card: it is handed a
## name, a line and how long to hold them, and it renders them. It does not know
## what a boss is, and no boss knows it exists - game.gd wires the two together
## at the moment the room is built, the same way it wires his health bar.
##
## ## Not the dialogue box, and the difference is the whole reason it exists
##
## `ui/dialogue/dialogue_box.gd` is a CONVERSATION: it types its line out, it
## waits for a keypress, and the player is under someone else's control the
## whole time it is up. None of that can happen in the middle of a fight - a
## line that eats the attack key is a line that gets you hit - so this one types
## nothing, takes no input at all, and goes away on a timer it was handed.
##
## It also carries no panel. A box at the bottom of the screen is the shape the
## player has already learned means "stop and read"; a shout over the room is
## read the way the level card is, off its own outline.
##
## ## It sits above the boss bar, not on the bottom edge
##
## The dialogue box is pinned 10 px off the bottom because nothing else is down
## there while it is up. This one is up during a FIGHT, and the bottom of the
## screen in a fight belongs to the boss's health bar and the name over it - so
## the block is pinned clear of both, 46 px up. It is the one measurement in
## here that is not a taste: `tests/test_barks.gd` reads the bar's own name
## label and checks this block ends above it, so moving either cannot quietly
## put a line the player is reading on top of the number they are watching.
##
## The speaker row survives that crowding for one reason, and it is the LAST
## line: conceding clears the bar and says his final line in the same breath,
## so that one line is on screen with nothing else to say who is talking.

## Long enough to read as a voice trailing off rather than a cut.
const FADE_SECONDS := 0.3

@onready var _speaker: Label = %Speaker
@onready var _line: Label = %Line

var _tween: Tween


func _ready() -> void:
	modulate.a = 0.0


## Put a line up for `seconds`, then fade it.
##
## A second call REPLACES the first rather than queueing behind it: what he is
## shouting now is the only thing worth reading, and a queue would leave the
## last swing's line sitting over the one that is about to land.
func show_line(speaker: String, text: String, seconds: float) -> void:
	_speaker.text = speaker
	_line.text = text
	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate.a = 1.0
	_tween = create_tween()
	_tween.tween_interval(maxf(seconds, 0.0))
	_tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)


## Take it down now, with no fade. A door and a death both move the player
## somewhere the line was never said.
func clear() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate.a = 0.0


## Whether anything is on screen. For game.gd and for tests; nothing in here
## decides anything from it.
func showing() -> bool:
	return modulate.a > 0.0
