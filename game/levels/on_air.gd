extends Node2D
## The LIVE / LAUGH / ENGAGE sign, wired to the studio clock. It is the room's
## tally light: when the tubes are hot, the floor is hot.
##
## There is no new art here and there is deliberately none. The sign is the
## brightest object on a near-black wall and it is already the first thing the
## eye goes to in this room, so the cheapest honest way to say "the room is
## about to hurt" was to take that brightness AWAY at rest and give it back on
## the cue. A player who never consciously reads the sign still learns the room
## off it, because the whole wall changes value.
##
## It is the only consumer of the clock that does not hurt anybody, which is
## exactly why it is worth having: `heat()` is one number driving a light pool,
## a rolling dolly and this, so the sign cannot ever be telling the truth about
## a take the rest of the floor is not having.
##
## A floor that stands the sign without running a clock gets it at full output,
## which is what it always was.

## What the tubes drop to between takes. Not zero: cold neon is glass with the
## room behind it, not a hole in the wall, and a sign that vanishes entirely
## reads as a prop being deleted rather than as one being switched off.
const COLD := 0.34

var _studio: Node = null
var _sprite: CanvasItem = null


func _ready() -> void:
	_studio = get_tree().get_first_node_in_group("studio")
	_sprite = get_node_or_null("Sprite2D") as CanvasItem
	set_process(_studio != null and _sprite != null)


func _process(_delta: float) -> void:
	var heat := float(_studio.call("heat"))
	# Straight off the clock's ramp, so the tubes come up over the cue at the
	# same rate the light pools open on the floor. The two are the same warning
	# seen at the wall and at the feet.
	var level := lerpf(COLD, 1.0, heat)
	_sprite.modulate = Color(level, level, level, 1.0)
