extends RefCounted
## A stream of states, each stamped in the HOST's time, and the picture of it at
## any moment in between (DESIGN.md's Multiplayer, M4).
##
## Twenty or thirty states a second is a picture that STEPS: a body walking at
## 90 px/s jumps three or four pixels at a time while the screen is drawn sixty
## times a second. So a drawn thing is shown a little in the past (sync.gd's
## `DELAY`), where there is a state on both sides of the moment being drawn,
## and it goes along the line between them. The newest state is never the one
## on screen - it is the one the picture is heading for.
##
## **A thing that JUMPED is not drawn sliding there.** Getting up at the door,
## or anything the room puts somewhere in one frame, would otherwise glide
## across the floor for a twentieth of a second; faster than `JUMP_SPEED`
## between two states is a jump, and the picture holds where it was until the
## state after the jump is the one on screen.

## Faster than this between two states is a jump, not a walk. Well over every
## real speed in the building - Ahmed's chair at 255 px/s, his leap at about
## 330 - and well under a door: one frame from one end of a room to the other.
const JUMP_SPEED := 600.0
## How many states are kept. A second of the fastest stream, which is far more
## than a playhead a tenth of a second behind ever looks back.
const KEEP := 32

var _stamps: Array[float] = []
var _states: Array = []


## One more state, stamped in host time. A state no newer than the last is
## dropped: the picture only ever moves forward.
func add(stamp: float, state: Variant) -> void:
	if not _stamps.is_empty() and stamp <= _stamps[-1]:
		return
	_stamps.append(stamp)
	_states.append(state)
	if _stamps.size() > KEEP:
		_stamps.pop_front()
		_states.pop_front()


func clear() -> void:
	_stamps.clear()
	_states.clear()


func is_empty() -> bool:
	return _stamps.is_empty()


## The picture at `time`: `[stamp, before, after, weight, span]` - the newest
## state at or before it and its stamp, the one after it, how far the picture
## is from one to the other, and how long that is. `after` is null when there
## is nothing newer yet (the picture holds on `before`), and `before` is the
## oldest state there is when every state is newer than `time`. Empty with
## nothing in it at all.
func at(time: float) -> Array:
	if _stamps.is_empty():
		return []
	var i := _stamps.size() - 1
	while i > 0 and _stamps[i] > time:
		i -= 1
	if i == _stamps.size() - 1 or _stamps[i] > time:
		return [_stamps[i], _states[i], null, 0.0, 0.0]
	var span := _stamps[i + 1] - _stamps[i]
	return [_stamps[i], _states[i], _states[i + 1],
		clampf((time - _stamps[i]) / span, 0.0, 1.0), span]


## Where a thing stands `weight` of the way from `a` to `b`, `span` seconds
## apart - or still at `a`, if getting to `b` that fast was a jump.
static func point(a: Vector2, b: Vector2, weight: float, span: float) -> Vector2:
	return a if jumped(a, b, span) else a.lerp(b, weight)


## Whether going from `a` to `b` in `span` seconds was a jump - see the header.
static func jumped(a: Vector2, b: Vector2, span: float) -> bool:
	return a.distance_to(b) > JUMP_SPEED * span
