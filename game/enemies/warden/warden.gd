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
##   ring (charge_ring.gd), on show before the player is anywhere near it.
## - *How far into the wind-up is it?* - the ring's sweep, the body tinting
##   violet, and the sprite itself, whose four-frame attack is stretched across
##   the whole two seconds so it finishes rising exactly as the effect lands.
##   Three readings of one number, because this is the only enemy whose entire
##   threat is invisible without them.

## Winds visibly tighter as the wind-up fills - two seconds have to read as a
## warning rather than a surprise, since the counter is to walk away or swing,
## and neither is a choice the player can make blind.
const CHARGE_TINT := Color(0.55, 0.45, 1.0)

@export var slow_factor := 0.5
@export var slow_seconds := 4.0

@onready var _ring: Node2D = $ChargeRing


func _ready() -> void:
	super()
	# The ring never carries the radius itself. Copying in the Touch shape's own
	# circle means the drawing IS the area - retune the shape and the ring moves
	# with it, and it can never be caught claiming a reach the enemy does not
	# have. (_touch_area is only live once the base's _ready has run.)
	var shape := _touch_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null and shape.shape is CircleShape2D:
		_ring.radius = (shape.shape as CircleShape2D).radius
		_ring.position = shape.position


func _physics_process(delta: float) -> void:
	super(delta)
	# Read once, after the base has settled the phase for the frame. 0 outside
	# the wind-up, so leaving, being staggered and landing the effect all clear
	# the ring without any of them being handled here.
	var progress := _windup_progress()
	_ring.set_progress(progress)
	if progress > 0.0:
		_hold_windup_frame(progress)


## Holds the sheet's own attack animation to the pace of the wind-up.
##
## The frame is set from the progress rather than left to play at its own speed,
## and that is what makes it survive the two things that would otherwise break
## it: turning to face the player swaps to another direction's animation and
## restarts it from the top, and four frames at 14 fps are over in a third of a
## second - six loops per wind-up, which reads as flailing rather than winding
## up. Driven from the number, the sprite is as far through its rise as the ring
## is round its sweep, always.
##
## No new art: these rows have been in every enemy sheet since seeding, and the
## warden was the one type that never played them. Run after super(), so it is
## the last word on the frame before it is drawn.
func _hold_windup_frame(progress: float) -> void:
	var frames := _sprite.sprite_frames
	if frames == null or not frames.has_animation(_sprite.animation):
		return
	var count := frames.get_frame_count(_sprite.animation)
	if count <= 0:
		return
	_sprite.frame = mini(int(progress * count), count - 1)


## An effect that has to hold you, not a blow thrown at where you were. Stepping
## out unwinds it completely.
func _windup_needs_contact() -> bool:
	return true


## Violet rather than the swing's orange: what is coming is not a hit.
func _windup_tint() -> Color:
	return CHARGE_TINT


## Rooted for every frame you are in its area. The cycle already roots anything
## that is not CHASE, so this is specifically about the frames before the
## wind-up starts and the cooldown after an interrupt - it must not use those to
## close the last of the ground.
func _can_advance() -> bool:
	return not touching_player


## Planted, waiting to begin. The rise itself is `_windup_state()`, which the
## base plays for the whole telegraph; between them the warden just stands.
func _contact_state() -> String:
	return "idle"


## The area landing, on everyone in it - the base already loops the bodies, so
## all that is left is what it costs them.
func _touch_strike(player: Node2D) -> void:
	if player.has_method("apply_slow"):
		player.call("apply_slow", slow_factor, slow_seconds)


func _strike() -> void:
	super()
	# The circle says what just happened to everything inside it. The one moment
	# the ring is allowed to be loud.
	_ring.flash()


## No blow of any kind, and no per-frame cost either: what its area takes from
## you is settled by the wind-up, not by contact the grace window would meter.
func _touch(_player: Node2D, _delta: float) -> void:
	pass
