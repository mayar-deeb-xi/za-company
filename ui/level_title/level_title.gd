extends Control
## The room's name, announced on arrival.
##
## Deliberately dumb, exactly like the HUD: game.gd hands it a string and it
## renders it, so nothing in here knows what a level or a door is. It sits above
## the transition fade rather than below it, so the name is already legible on
## the black and the room fades in behind it.

const HOLD_SECONDS := 3.0
## Long enough to read as a fade rather than a cut, short enough that the name
## is gone before the player has walked anywhere worth looking at.
const FADE_SECONDS := 0.4

@onready var _label: Label = %Name

var _tween: Tween


func _ready() -> void:
	modulate.a = 0.0


## Held at full opacity for HOLD_SECONDS, then faded out.
##
## A second call restarts the count rather than queueing behind the first, so
## stepping straight back through a door reads the room you are now in - a
## queue would leave the previous room's name sitting over it.
func show_title(text: String) -> void:
	_label.text = text
	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate.a = 1.0
	_tween = create_tween()
	_tween.tween_interval(HOLD_SECONDS)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
