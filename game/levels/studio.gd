extends Node2D
## The studio's clock: a take rolls, then the room rests, and everything on this
## floor that can hurt you reads which of the two it is.
##
## ## Why a room needs a clock at all
##
## Floor 2 teaches ROUTING - three overlapping drain fields and a ring light
## knocked over in the middle of them - and routing is a lesson a player solves
## exactly once. Every threat in the room stands where it was placed, so the
## second visit is the first visit walked from memory. What was missing was not
## more damage; it was a reason to be somewhere at a particular MOMENT rather
## than merely somewhere.
##
## So the room got a rhythm instead of more bodies. One node counts, and the
## things that hurt read it:
##
## - the five ring lights that were furniture go hot (game/levels/hot_light.gd)
## - the dolly runs its rail across the set (game/levels/dolly.gd)
## - the LIVE / LAUGH / ENGAGE sign says which it is (game/levels/on_air.gd)
##
## They are three consumers of one number, which is the whole design: a player
## learns ONE rhythm and then knows what the entire floor is about to do. Three
## timers would have been three things to read, and a room that asks you to read
## three clocks while two drains tick is a room that is simply noisy.
##
## ## The three phases, and why the middle one exists
##
##   REST  nothing in the room is hot. The floor is the floor it always was.
##   CUE   the lead-in. Nothing hurts yet, and everything that is ABOUT to
##         says so - the sign warms, the light pools open on the floor.
##   TAKE  rolling. The pools burn and the dolly runs.
##
## CUE is the whole of what makes this fair. A hazard that switches on is a
## hazard that hits you for standing somewhere that was safe when you decided to
## stand there; a hazard that opens a visible pool for a second and a half first
## is a hazard you walked into. It is the enemies' wind-up applied to the room,
## and it is read the same way - by watching, not by counting.
##
## ## `heat()` rather than three booleans
##
## Consumers ask for ONE float: 0.0 at rest, ramping 0 to 1 across the cue, 1.0
## for the whole take. A light multiplies its pool's alpha by it and a sign its
## brightness, so the telegraph and the danger are the same number seen twice -
## which is exactly the property that makes the pool trustworthy. There is no
## way for a light to draw a pool it does not then burn in, because it does not
## know two numbers.
##
## `rolling()` is the other half, and it is a hard edge rather than a ramp: it
## is what "does this hurt right now" means, and it is deliberately false for
## every frame of the cue.
##
## ## Rooms keep no state, and that is load-bearing here
##
## Levels are re-instantiated per entry, so the clock starts at REST on every
## arrival and the player always gets a full rest to read the room before the
## first take. That is not a limitation being worked around - it is the reason
## walking back through the south door and returning is not an exploit worth
## having: you get the same quiet moment either way, and the fight is what
## happens in between.
##
## Authored per floor as `studio` in tools/biomes/<level>.gd. A floor without
## the key gets no node, and then every consumer above finds nothing and stays
## exactly the furniture it was - see hot_light.gd's own note on that.

## What a consumer is told, and the only thing this node says out loud. The
## phase it carries is one of the three below.
signal phase_changed(phase: int)

enum { REST, CUE, TAKE }

## Seconds per phase, authored per floor. The defaults are the studio's own
## numbers and are tuned against one thing: the player walks at 90 px/s, so a
## 1.5 s cue is 135 px of warning - most of the way across the west half of the
## room, which is the half this floor is fought in.
@export var take := 5.5
@export var rest := 4.0
@export var lead := 1.5

var phase := REST

## Seconds left in the current phase. Counted down rather than up because every
## consumer wants the fraction ELAPSED and the cue is the only phase whose
## fraction anybody reads - see heat().
var _left := 0.0


func _ready() -> void:
	_enter(REST)


func _process(delta: float) -> void:
	_left -= delta
	if _left > 0.0:
		return
	match phase:
		REST:
			# A cue of zero would be a hazard that switches on, which is the one
			# shape this whole node exists to avoid - so a floor that authors it
			# away goes straight to the take and the lights have no telegraph.
			# Legal, and nobody should do it.
			_enter(CUE if lead > 0.0 else TAKE)
		CUE:
			_enter(TAKE)
		_:
			_enter(REST)


## How hot the room is: 0 at rest, ramping to 1 across the cue, 1 for the whole
## take. One number, three consumers - see the header.
func heat() -> float:
	match phase:
		TAKE:
			return 1.0
		CUE:
			return clampf(1.0 - _left / maxf(lead, 0.001), 0.0, 1.0)
		_:
			return 0.0


## Whether anything on this floor is currently hurting anybody. Deliberately
## false through the cue: the pools are open and visible for that whole second
## and a half, and nothing in them has happened yet.
func rolling() -> bool:
	return phase == TAKE


func _enter(next: int) -> void:
	phase = next
	_left = [rest, lead, take][next]
	phase_changed.emit(phase)
