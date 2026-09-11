extends "res://game/levels/hazard_base.gd"
## The camera dolly: a rig on a rail that runs across the set while a take is
## rolling, and shoves whatever is standing on the track.
##
## The first thing in this game that hurts you and MOVES. Everything else the
## world deals is either standing where it was placed (a torch, a ring light) or
## is a person who came looking for you; a dolly is neither, and that is the
## whole reason it is here - a room whose threats all have addresses is a room
## you solve by learning the addresses.
##
## ## It runs a rail, and the rail is painted on the floor
##
## `from` and `to` are the two ends, authored per floor, and
## tools/props/markings/rail.gd draws the track between them as a floor marking.
## That is not decoration: the danger has to be legible before it arrives, and a
## lane the player can see is a lane they time rather than a thing that hits
## them from off-screen. The rail is the promise that the dolly goes HERE and
## nowhere else - one axis, constant speed, no decisions.
##
## ## Why it stops short of the door lane
##
## The studio's rail runs the WEST half of the room only. Every floor in this
## game keeps x 246-300 walkable top to bottom - no enemy's sight reaches it and
## nothing is placed on it - so that the straight walk between the two doors is
## safe in every biome, and the flow tests lean on that. A moving hazard is the
## first thing that could cross a lane without ever being placed in one, and the
## answer is that it does not: it tracks across the SET, which is where a dolly
## belongs anyway, and the set is the north-west quarter.
##
## What that buys is better than the rule it keeps. The west half is where the
## two drain fields overlap and where the fallen light already burns, so the
## dolly charges exactly the ground this floor was built to make expensive, and
## the way out stays a way out.
##
## ## Rolling, and resetting
##
## While the studio clock is rolling it runs end to end and back, and it hurts.
## Between takes it returns to its parked end and does NOT hurt - which is the
## floor's one rule seen from the other side: this room is dangerous during a
## take and not otherwise, and a dolly that hurt while the sign was dark would
## be the exception that makes the rule not worth learning. It is also a second
## telegraph, and the earliest one the floor gives: a rig sliding back to its
## mark means somebody is about to call action.
##
## A floor with no clock parks it and leaves it there - see hot_light.gd.

## Authored per floor as `dolly` in tools/biomes/<level>.gd. `from` is the
## parked end: the one it is standing at when the room is quiet, and the end
## every take starts from.
@export var from := Vector2.ZERO
@export var to := Vector2.ZERO
## Pixels per second. 78 against the player's 90 is the number that matters:
## the dolly must never be able to run somebody down from behind, so it is
## slower than a walk and being hit by it is always a matter of standing still.
@export var speed := 78.0

var _studio: Node = null
## Where along the rail it is, 0 at `from` and 1 at `to`, and which way it is
## going. A scalar rather than a target position because the rail is a segment
## and a ping-pong on a segment is one number changing sign.
var _along := 0.0
var _towards := 1.0


func _ready() -> void:
	super()
	_studio = get_tree().get_first_node_in_group("studio")
	position = from


func _process(delta: float) -> void:
	var step := speed * delta / maxf(from.distance_to(to), 1.0)
	if _rolling():
		_along += step * _towards
		# Ping-pong: reflect off whichever end it reached rather than clamping,
		# so a take longer than one crossing is one continuous run instead of a
		# rig parked against the far wall for the rest of it.
		if _along > 1.0:
			_along = 2.0 - _along
			_towards = -1.0
		elif _along < 0.0:
			_along = -_along
			_towards = 1.0
	else:
		# Back to the mark. The same speed, so the longest reset is the length
		# of the rail over the speed - 2.2 s on the studio's, comfortably inside
		# its 4 s rest, which is what makes every take start from the same end.
		_along = maxf(_along - step, 0.0)
		_towards = 1.0
	position = from.lerp(to, _along)


## Hurts only while a take is rolling. Between takes it is a prop being pushed
## back to its mark, and walking through it costs nothing.
func _physics_process(delta: float) -> void:
	if not _rolling():
		return
	super(delta)


func _rolling() -> bool:
	return _studio != null and bool(_studio.call("rolling"))
