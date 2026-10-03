extends RefCounted
## Another machine's clock, read from this one (DESIGN.md's Multiplayer, M4).
##
## Every message that says WHEN carries the sender's own time, which means
## nothing here by itself: two machines' clocks start at two different moments.
## What can be known is the gap between a stamp and the moment it was heard, and
## that gap is the clocks' difference plus however long the trip took. The
## SMALLEST gap ever seen is the fastest trip, so it is the one that is mostly
## the clocks' difference - and reading the other clock as "here, minus that
## gap" puts every message at the soonest it could have arrived. A message that
## was held up on the way is then simply late by its delay, which is exactly
## what the tenth of a second the picture is drawn behind (sync.gd's `DELAY`)
## is there to absorb.
##
## A route can get slower for good, so the smallest gap is let CREEP up while
## nothing confirms it: a few milliseconds a second, which the next quick
## message takes straight back down.

## How fast the smallest gap is let grow while nothing confirms it, in seconds
## per second.
const CREEP := 0.005

## Local time minus remote time, at its smallest - see the header.
var _gap := INF
var _heard_at := 0.0


## This machine's own clock, in seconds. The one every stamp is written in.
static func local() -> float:
	return Time.get_ticks_usec() / 1000000.0


## A message stamped `stamp` by the other machine has just arrived.
func heard(stamp: float) -> void:
	var now := local()
	if is_inf(_gap):
		_gap = now - stamp
	else:
		_gap = minf(_gap + CREEP * (now - _heard_at), now - stamp)
	_heard_at = now


## Whether anything has been heard yet - before it, the other clock is unknown.
func known() -> bool:
	return not is_inf(_gap)


## The other clock, as it reads now from here.
func there() -> float:
	return local() - (_gap if known() else 0.0)


## A time on the other clock, as this machine's.
func here(stamp: float) -> float:
	return stamp + (_gap if known() else 0.0)
