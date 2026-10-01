extends CanvasLayer
## The faint white the whole frame takes when the combo's finisher or the
## heavy lands - the thunderclap and the supernova.
##
## At layer 1, the slot game.gd's stack keeps for a fight's own screen effects:
## above the room and UNDER the HUD, because a flash that washed out the health
## bar would hide the one number the player is reading while it lands. Two
## steps rather than a fade, as previewed - 0.2 for the first 0.05 s, then 0.09
## - because a fade at this size is a smear and two flat steps are a clap.
##
## Built by player.gd in `_ready` rather than placed in player.tscn, so a body
## instanced on its own in a test carries it for free.

const LAYER := 1
const HOT := 0.2
const COOL := 0.09
const HOT_FOR := 0.05

var _rect: ColorRect
var _left := 0.0


func _ready() -> void:
	layer = LAYER
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.color = Color(1, 1, 1, 0)
	add_child(_rect)


## Flash for `seconds`. A longer flash already running is not cut short.
func flash(seconds: float) -> void:
	_left = maxf(_left, seconds)


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left = maxf(_left - delta, 0.0)
	_rect.color.a = 0.0 if _left == 0.0 else (HOT if _left > HOT_FOR else COOL)
