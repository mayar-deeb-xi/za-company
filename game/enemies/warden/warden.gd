extends "res://game/enemies/enemy_base.gd"
## The warden. It never strikes and never touches you for anything: it follows
## until you are inside its area, plants itself, and winds up. If it finishes,
## everyone still in the area is slowed to half speed for four seconds.
##
## Its area IS the Touch shape, tuned wide - the same trick as the wraith's
## aura - so the base already answers "is anyone in range", and reaching the
## player is what starts the wind-up.
##
## **Its charge is the base's wind-up, not a clock of its own.** They were the
## same shape - hold the player, count, then land - so the warden is simply a
## very slow telegraph (`windup_seconds` 2.0 on the scene) whose strike costs
## speed instead of health. Everything the cycle brings comes with it: the
## sword interrupts the charge before `commit_fraction`, `interrupt_cooldown`
## keeps that from being a mash, and `recover_seconds` is the beat you get back
## after eating one.
##
## It plants at the RIM of its area rather than in your face, and that falls out
## of the rooting rather than being a second rule: being in contact is what
## roots it, so it stops the moment it has you and never closes further. That
## keeps it at arm's length from your sword and makes killing it a decision to
## walk into the thing that is about to slow you.
##
## Leaving resets the wind-up instead of pausing it - `_windup_needs_contact()`,
## because unlike a swing this is an effect that has to HOLD you. The
## counterplay is to move, and a warden you keep stepping in and out of should
## never land something it did not hold you for the whole two seconds.
##
## **That counterplay is only a choice if both halves of it are visible**, and
## the halves are different questions asked of different things:
##
## - *Where is the area?* - 48 px of floor, six times the width of the body. No
##   animation on a sprite that size can say where it ends, so it is the drawn
##   field (charge_ring.gd), whose rim is on show before the player is anywhere
##   near it.
## - *How far into the wind-up is it?* - the frost creeping out from its feet
##   toward that rim, and the body tinting violet. Both read one number, so an
##   interrupt wipes the frost and drops the tint in the frame it lands.
##
## **It does not mime a strike.** The base animates every wind-up as `attack`,
## which on this sheet is a sword swing - and a harmless enemy raising a sword
## for two seconds read as an attack, which is the one thing the warden is not.
## So it holds its idle pose through the charge and lets the floor and the tint
## do the telling; past the commit point the body shivers one pixel, the same
## "too late" the field's edge is blinking.

## Winds visibly tighter as the wind-up fills - two seconds have to read as a
## warning rather than a surprise, since the counter is to walk away or swing,
## and neither is a choice the player can make blind.
const CHARGE_TINT := Color(0.55, 0.45, 1.0)
## The committed shiver: one pixel either side, this many flips per second.
const SHIVER_HZ := 15.0

@export var slow_factor := 0.5
@export var slow_seconds := 4.0

@onready var _ring: Node2D = $ChargeRing
## The sheet's own offset, so the shiver is added to it rather than replacing it.
@onready var _sprite_offset: Vector2 = _sprite.offset


func _ready() -> void:
	super()
	# The field never carries the radius itself. Copying in the Touch shape's
	# own circle means the drawing IS the area - retune the shape and the field
	# moves with it, and it can never be caught claiming a reach the enemy does
	# not have. (_touch_area is only live once the base's _ready has run.)
	var shape := _touch_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null and shape.shape is CircleShape2D:
		_ring.radius = (shape.shape as CircleShape2D).radius
		_ring.position = shape.position


func _physics_process(delta: float) -> void:
	super(delta)
	# Read once, after the base has settled the phase for the frame. 0 outside
	# the wind-up, so leaving, being staggered and landing the effect all clear
	# the field without any of them being handled here.
	var progress := _windup_progress()
	var committed := progress >= commit_fraction
	_ring.set_progress(progress, committed)
	var shiver := 0.0
	if progress > 0.0 and committed:
		shiver = 1.0 if int(progress * windup_seconds * SHIVER_HZ * 2.0) % 2 == 0 else -1.0
	_sprite.offset = _sprite_offset + Vector2(shiver, 0.0)


## An effect that has to hold you, not a blow thrown at where you were. Stepping
## out unwinds it completely.
func _windup_needs_contact() -> bool:
	return true


## Violet rather than the swing's orange: what is coming is not a hit.
func _windup_tint() -> Color:
	return CHARGE_TINT


## Standing, not swinging: the warden never draws a weapon, so it must not mime
## one. The charge is told by the field and the tint.
func _windup_state() -> String:
	return "idle"


## Rooted for every frame you are in its area. The cycle already roots anything
## that is not CHASE, so this is specifically about the frames before the
## wind-up starts and the cooldown after an interrupt - it must not use those to
## close the last of the ground.
func _can_advance() -> bool:
	return not touching_player


## Planted, waiting to begin. The charge is `_windup_state()`, also idle; the
## warden stands for the whole of it.
func _contact_state() -> String:
	return "idle"


## The area landing, on everyone in it - the base already loops the bodies, so
## all that is left is what it costs them.
func _touch_strike(player: Node2D) -> void:
	if player.has_method("apply_slow"):
		player.call("apply_slow", slow_factor, slow_seconds)


func _strike() -> void:
	super()
	# The floor says what just happened to everything standing on it, and stays
	# iced for exactly as long as they are slow.
	_ring.land(slow_seconds)


## No blow of any kind, and no per-frame cost either: what its area takes from
## you is settled by the wind-up, not by contact the grace window would meter.
func _touch(_player: Node2D, _delta: float) -> void:
	pass
