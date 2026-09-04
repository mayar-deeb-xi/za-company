extends "res://game/enemies/enemy_base.gd"
## The warden. It never strikes and never touches you for anything: it follows
## until you are inside its area, plants itself, and winds up for two seconds.
## If it finishes, everyone still in the area is slowed to half speed for four.
##
## Its area IS the Touch shape, tuned wide - the same trick as the wraith's
## aura - so the base already answers "is anyone in range", and `touching_player`
## is the whole input the wind-up needs.
##
## It plants at the RIM of its area rather than in your face, and that falls out
## of the rooting rather than being a second rule: being in contact is what
## roots it, so it stops the moment it has you and never closes further. That
## keeps it at arm's length from your sword and makes killing it a decision to
## walk into the thing that is about to slow you.
##
## Leaving resets the wind-up instead of pausing it. The counterplay is to move,
## and a warden you keep stepping in and out of should never land an effect it
## did not hold you for the whole two seconds.

const CHARGE_SECONDS := 2.0
## Winds visibly tighter as the charge fills - the two seconds have to read as a
## warning rather than a surprise, since the player's counter is to walk away
## and they can only choose that if they can see it coming.
const CHARGE_TINT := Color(0.55, 0.45, 1.0)

@export var slow_factor := 0.5
@export var slow_seconds := 4.0

var _charge := 0.0


## Rooted for every frame you are in its area, which is every frame it is
## winding up.
func _can_advance() -> bool:
	return not touching_player


func _physics_process(delta: float) -> void:
	super(delta)
	# Counted here rather than in _touch(), which the base calls once per body
	# in range: with two players in the area a wind-up counted there would fill
	# twice as fast. After super() the base has settled touching_player for the
	# frame, so one read covers however many are standing in it.
	if not touching_player:
		_charge = 0.0
		return
	_charge += delta
	if _charge >= CHARGE_SECONDS:
		_charge = 0.0
		_release()


## Everyone in the area when it lands, not merely whoever it was following.
func _release() -> void:
	for body in _touch_area.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("apply_slow"):
			body.call("apply_slow", slow_factor, slow_seconds)


## No blow of any kind. What its area costs you is settled by the wind-up, not
## by the frame-by-frame contact the base meters through the grace window.
func _touch(_player: Node2D, _delta: float) -> void:
	pass


## Planted and winding up, so it is standing rather than lunging.
func _contact_state() -> String:
	return "idle"


func _resting_tint() -> Color:
	if _charge <= 0.0:
		return Color.WHITE
	return Color.WHITE.lerp(CHARGE_TINT, _charge / CHARGE_SECONDS)
