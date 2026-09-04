extends "res://game/enemies/enemy_base.gd"
## The wraith. It never strikes: it simply follows, and being near it costs the
## player a point of health every second.
##
## This is the first enemy whose harm has a clock of its own, and it is where
## the kinds of harm in the game separate. A regular's blow is a discrete event
## the player's grace window meters against everything else hitting them - but a
## drain IS a rate already, so it accumulates here and presses the player's
## drain() instead: no grace, no blink, no competing with whatever last hit them.
##
## The aura is just the Touch area, tuned wide: "near you" and "touching you"
## are the same question, so the base's overlap machinery answers both.
##
## **It has no swing, so there is nothing to interrupt - and that is its
## identity, not an omission.** Every other enemy can be staggered out of its
## attack; this one cannot, because it has no attack, only proximity. It is the
## single thing in the game that hitting does not stop, which leaves exactly two
## answers to it: leave, or kill it. Being the squishiest of the three is the
## other half of that bargain.

## Health per second of proximity, scaled by difficulty at spawn. Fractional
## and float on purpose - the rate is the tunable thing. 3 rather than the
## original 1 because at 1 it took 100 seconds to matter: two of them together
## now cost about half a guard's output, from the one source that cannot be
## staggered and that ignores the grace window - which is exactly the pressure
## a wraith is for.
@export var drain_per_second := 3.0


func _ready() -> void:
	super()
	# The drain is a blow-rate in disguise, so it rides the same dial as every
	# other harm the world deals; the base has already scaled contact_damage,
	# which a wraith does not use.
	drain_per_second *= Difficulty.damage_scale()


## No wind-up, no strike, nothing to stagger. Its harm is _touch(), every frame.
func _attacks() -> bool:
	return false

## A cold glow while it feeds, so health ticking down has a visible cause.
const FEED_TINT := Color(0.55, 0.85, 1.0)
const FEED_PULSE_HZ := 1.6

## Fraction of a health point owed but not yet whole. Deliberately NOT cleared
## when contact breaks: keeping it means stepping out and back in resumes the
## tick rather than restarting it, so dancing on the edge of the aura cannot
## drain the wraith of its bite.
var _owed := 0.0
var _feed_time := 0.0


## Health is an integer, so the rate is banked and spent in whole points. The
## remainder carries, which keeps the rate true across frames of any length.
func _touch(player: Node2D, delta: float) -> void:
	if not player.has_method("drain"):
		return
	_feed_time += delta
	_owed += delta * drain_per_second
	var points := int(_owed)
	if points > 0:
		_owed -= points
		player.call("drain", points)


## It has no attack to play and, having arrived, nowhere left to walk. It just
## stands over you facing your way while your health goes - which is the whole
## threat, and reads worse than a lunge would.
func _contact_state() -> String:
	return "idle"


func _resting_tint() -> Color:
	if not touching_player:
		return Color.WHITE
	var pulse := 0.5 + 0.5 * sin(_feed_time * TAU * FEED_PULSE_HZ)
	return Color.WHITE.lerp(FEED_TINT, pulse)
