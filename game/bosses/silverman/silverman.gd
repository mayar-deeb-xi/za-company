extends "res://game/bosses/boss_base.gd"
## SILVERMAN. The last man in the building, and the first one in it who is not
## pretending to be a person: no suit, no face, no seams - a humanoid poured
## out of the same metal the penthouse is specified in.
##
## **His body never changes shape**, and every attack below obeys that rather
## than working around it. A row in his poses is the same eighteen columns of
## ASCII as his idle, at a different height and a different rung of the ramp;
## everything that makes an attack legible is drawn live beside him. So the
## whole fight cost two rows of art, and neither of them is a picture of a
## weapon.
##
## ## The ladder
##
## Three phases, DESIGN.md's own, and each one ADDS without removing - the
## fight gets more crowded rather than faster, which is the only escalation
## available to a man who never hurries:
##
## - **The Handshake** (192 -> 128): the crossing and the glare. Standard
##   interrupts. The fair phase.
## - **The Meeting** (128 -> 64): the split arrives. One interrupt, then a long
##   lockout - you get one.
## - **The Performance Review** (64 -> 0): the room goes cold, and standing
##   near him costs health on its own. Fully uninterruptible.
##
## A phase is announced by `herald`, which is his version of adjusting his
## cuffs: he has no cuffs, so what he does instead is spend a rung of his own
## shine on the room (glare.gd draws it) and shake it. Crossing a threshold
## also clears both cooldowns, so an escalation ARRIVES rather than being
## something you notice a few seconds later.
##
## ## The four things he does
##
## - **the crossing** (`DASH`) - locomotion that now hurts. He passes THROUGH
##   you, once per crossing, and it is the only thing he has that is not on the
##   attack cycle at all.
## - **the glare** - the room whites out and a band of it crosses the floor,
##   travelling through his recover. You step out of its line; you cannot
##   outrun it.
## - **the split** - he divides, and the copy walks at you while he stands
##   still. See copy.gd; it is drawn from a sheet row he never plays.
## - **the cold room** - an aura, not an attack. No telegraph, nothing to
##   interrupt, and it sits OUTSIDE the grace window because a drain is not a
##   blow.
##
## What he deliberately has NOT got is a melee swing. Nothing here is thrown
## with a hand: he glides through you, blinds you, divides, and freezes the air
## near him. A player standing on him is answered by the glare, whose band
## starts inside its own reach.

const Poses := preload("res://game/bosses/silverman/poses.gd")
const Copy := preload("res://game/bosses/silverman/copy.gd")

## MEDIUM numbers. The base scales an attack's damage when it is chosen; the
## crossing and the cold room are not on the cycle, so they scale their own
## (see `_ready`).
const DAMAGE := {"glare": 16, "split": 12}
const DASH_DAMAGE := 18

## How much of a wind-up can still be interrupted, by phase, and how long an
## interrupt then locks him out for. This IS the ladder: the base has one dial
## for each, and setting them per phase as an attack begins is the only way to
## have the same attack narrow over the fight.
##
## 0.0 is never interruptible, not always: `_interruptible()` asks whether the
## wind-up's progress is still BELOW this, so a lower number is a more
## committed boss. The third phase is 0.0, which is DESIGN.md's "fully
## uninterruptible" with no special case anywhere to make it so.
const COMMIT := {1: 0.65, 2: 0.40, 3: 0.0}
const LOCKOUT := {1: 1.2, 2: 3.0, 3: 3.0}

## Phase boundaries as fractions of his own max, so retuning his health in the
## scene moves the phases with it instead of stranding them at 128 and 64.
const PHASE_TWO := 2.0 / 3.0
const PHASE_THREE := 1.0 / 3.0

## The dash, beat by beat: seconds held, and where he is along the crossing in
## world px from where he started. It is a POSITION CURVE and nothing else -
## the sprite holds one unchanging frame for all 0.5 s of it, because a liquid
## that deforms while it travels was drawn, looked at and dropped.
##
## `moving` is what smear.gd draws on. The first and last two beats are the
## coil and the arrival, where he is standing still: three pixels back before
## he goes and two past the mark on the way in are the only anticipation this
## boss has, and they are position, so his shape is still never touched.
##
## `hit` is the pass-through. All three travel beats carry it and a flag keeps
## it to ONE blow per crossing, so where the player is standing along the
## crossing decides when it lands rather than whether it does. The coil and the
## arrival are harmless, which is what keeps it a pass-through and not a
## 0.5 s hitbox parked on top of you.
const DASH := [
	{"dur": 0.12, "x": -3.0, "moving": false},
	{"dur": 0.06, "x": 8.0, "moving": true, "hit": true},
	{"dur": 0.06, "x": 36.0, "moving": true, "hit": true},
	{"dur": 0.06, "x": 60.0, "moving": true, "hit": true},
	{"dur": 0.08, "x": 74.0, "moving": false},
	{"dur": 0.12, "x": 72.0, "moving": false},
]

## Closer than this and he answers with the room instead - the crossing is for
## a player who has made ground.
##
## **It has to be well inside the crossing's own 72 px**, and this is the one
## number the pass-through turned into a bug: at the 96 it was while the dash
## was pure locomotion, he triggered at 96 and travelled 72, so he ALWAYS
## stopped 24 px short and could never once pass through anybody. A gap-closer
## may stop short. A blow may not.
##
## At 40 the bands are: inside 40 he glares, 40 to ~86 he crosses THROUGH you,
## and past that he crosses and lands short - which is the old locomotion,
## still there, for a player who has backed off further than he can reach.
@export var dash_range := 40.0
## Long enough that the crossing is an event. He never hurries.
@export var dash_cooldown := 2.4
## How close the crossing passes to count as passing THROUGH. His own body
## radius plus a little, so clipping his shoulder is a hit and standing a step
## off the line is not.
@export var dash_reach := 12.0

## The glare's band: where its front is on the frame the light lands, how far
## it crosses, and the slack that puts a body on the edge of it inside it.
const GLARE_START := 16.0
const GLARE_REACH := 140.0
const GLARE_SLACK := 6.0

@export var glare_cooldown := 3.2
@export var split_cooldown := 5.0
## Closer than this and the copy would arrive before it has walked anywhere,
## so he glares instead. The split is the mid-range answer.
@export var split_min_distance := 34.0

## The cold room, third phase only. A drain, so it knows its own rate and is
## metered by nothing: the grace window neither blocks it nor is opened by it.
@export var chill_radius := 34.0
@export var chill_per_second := 3.0

## World pixels of camera throw. The glare is the big one because it is the
## whole room; a phase arriving is worth more than either.
const SHAKE := {"glare": 5.0, "dash": 3.4}
const SHAKE_SECONDS := 0.14
const HERALD_SECONDS := 0.9
const HERALD_SHAKE := 6.0

## True for the whole crossing; `dash_moving` only for the three beats he is
## actually travelling. Both public because smear.gd reads the second one and
## the tests read the first - neither is told anything.
var dashing := false
var dash_moving := false
## Seconds left of a phase announcement, counting down. Public for the same
## reason: glare.gd draws it and is told nothing.
var herald := 0.0

var _dash_time := 0.0
var _dash_from := Vector2.ZERO
var _dash_dir := 1.0
var _dash_cool := 0.0
var _dash_hit := false
## The body he is crossing through, while he is crossing it. Held so the
## exception can be dropped again from either end - the arrival or a concede.
var _dash_excepted: Node2D
var _dash_damage := DASH_DAMAGE

var _glare_timer := 0.0
var _glare_hit := {}
var _split_timer := 0.0
var _chill_rate := 0.0
var _owed := 0.0
var _tier := 1

var _dash_total := _total_of(DASH)

@onready var _band: Area2D = $Band


func _ready() -> void:
	super()
	# The two things that are not on the attack cycle scale themselves, where
	# the base scales an attack's damage as it is chosen. Read once at spawn
	# like every other consumer: the mode cannot change mid-fight.
	_dash_damage = roundi(DASH_DAMAGE * Difficulty.damage_scale())
	_chill_rate = chill_per_second * Difficulty.damage_scale()
	_sprite.animation_finished.connect(_on_animation_finished)


## Which phase he is in - 1, 2 or 3. Public because the tests read it and
## because his effects want to know how bad it has got without being told.
func tier() -> int:
	var left := float(health) / float(maxi(max_health, 1))
	if left > PHASE_TWO:
		return 1
	return 2 if left > PHASE_THREE else 3


## Rooted against the base's own walking while he is crossing: the dash moves
## him itself, and two things pushing one body fight each other.
func _can_advance() -> bool:
	return not dashing


## His wind-up is DRAWN, not tinted. The base fades the sprite towards an amber
## WINDUP_TINT as a swing fills, which is exactly wrong on a body whose whole
## look is six exact greyscale values: a multiply lands between two rungs of
## his ramp, and there is no hue anywhere in him to tint. The `dull` steps in
## poses.gd are the telegraph instead - see the `glare` row.
func _windup_tint() -> Color:
	return Color.WHITE


func _physics_process(delta: float) -> void:
	if has_conceded:
		super(delta)
		return
	_glare_timer = maxf(_glare_timer - delta, 0.0)
	_split_timer = maxf(_split_timer - delta, 0.0)
	herald = maxf(herald - delta, 0.0)
	if dashing:
		_dash_step(delta)
		_chill(delta)
		return
	super(delta)
	# The band runs on through the recover: each frame it has crossed further
	# hits whoever it has reached and not yet blinded.
	if attack == "glare" and phase == Phase.RECOVER:
		_glare_reach(glare_front(_phase_time))
	_chill(delta)
	_dash_cool = maxf(_dash_cool - delta, 0.0)
	_consider_dash()


# --- the attack cycle --------------------------------------------------------


func _attack_spec(id: String) -> Dictionary:
	return {
		"windup": Poses.windup_of(id),
		"recover": Poses.recover_of(id),
		"damage": DAMAGE[id],
	}


## Per-phase commit and lockout, set as the attack begins. The base has one
## dial for each and this is the only place they can narrow over a fight.
func _begin_attack(id: String) -> void:
	commit_fraction = COMMIT[tier()]
	interrupt_cooldown = LOCKOUT[tier()]
	super(id)


## The split while it is available and there is ground for the copy to cover,
## the glare otherwise. "" holds him where he is, which is a perfectly good
## thing for this boss to be doing.
func _pick_attack() -> String:
	if tier() >= 2 and _split_timer <= 0.0 and _distance_to_player() >= split_min_distance:
		return "split"
	if _glare_timer <= 0.0:
		return "glare"
	return ""


## Neither of his attacks needs to reach you, so neither waits for contact -
## the glare is the whole room and the copy does the walking. Ahmed's wave
## opens from CHASE the same way and for the same reason.
func _advance_phase() -> void:
	if phase == Phase.CHASE and not touching_player and not dashing:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null and _distance_to_player() <= sight_radius:
			var id := _pick_attack()
			if id != "":
				_begin_attack(id)
				return
	super()


## The blow, per attack. There is no `super()` branch here because he has no
## melee: nothing he does lands merely on whoever is inside `Touch`.
func _strike() -> void:
	match attack:
		"glare":
			_glare_timer = glare_cooldown
			_glare_hit.clear()
			# The burst BEFORE the travel - see below. It shares `_glare_hit`
			# with the band, so nobody is caught twice by one glare.
			_flash_at_source()
			_glare_reach(GLARE_START)
			shook.emit(SHAKE["glare"], SHAKE_SECONDS)
		"split":
			_split_timer = split_cooldown
			_cast_copy()


## The glare bursts off HIM before it sets out, and anyone inside his own reach
## when he spends his shine takes it whatever line they are standing on.
##
## **This is what stops him being free to hug**, and without it he had a hole
## you could win the last fight in the game through. Every reach he owns points
## along x or is too far out: the band is a 20 px lane through his chest, the
## crossing only travels along x, and the split will not fire closer than 34.
## So a player standing directly north or south of him at arm's length was
## missed by the lane on BOTH axes, slid past by the crossing, and not worth a
## split - phases one and two landed nothing at all on them.
##
## It needs no new number and no new shape: `Touch` is the reach the base
## already gives him, and standing in the source of the glare being the worst
## place to be is the obvious reading of it.
func _flash_at_source() -> void:
	for body in _touch_area.get_overlapping_bodies():
		if body == self or _glare_hit.has(body) or not body.has_method("take_damage"):
			continue
		_glare_hit[body] = true
		body.call("take_damage", contact_damage)


# --- the glare ---------------------------------------------------------------


## How far the band's front has crossed, `since` seconds after the light
## landed. glare.gd draws the band off this very function, so the picture and
## the hitbox are one number and cannot drift apart.
func glare_front(since: float) -> float:
	var travel := maxf(Poses.recover_of("glare"), 0.001)
	return GLARE_START + (GLARE_REACH - GLARE_START) * clampf(since / travel, 0.0, 1.0)


## Everything the band has reached and not yet caught, once each. The area is
## swung to his facing and moved to the front before it is asked.
func _glare_reach(front: float) -> void:
	_band.position.x = -front if _facing_left else front
	for body in _band.get_overlapping_bodies():
		if body == self or _glare_hit.has(body) or not body.has_method("take_damage"):
			continue
		if _forward_of(body) <= front + GLARE_SLACK:
			_glare_hit[body] = true
			body.call("take_damage", contact_damage)


## How far ahead of him a body stands, along the way he faces.
func _forward_of(body: Node2D) -> float:
	var dx := body.global_position.x - global_position.x
	return -dx if _facing_left else dx


# --- the split ---------------------------------------------------------------


## One copy, in the room rather than under him - a thing parented to the boss
## would drift with him, and the whole point is that he stands still while it
## goes. It is handed the damage the base already scaled for this attack.
func _cast_copy() -> void:
	var copy := Copy.new()
	get_parent().add_child(copy)
	copy.global_position = global_position
	copy.cast(self, contact_damage, -1.0 if _facing_left else 1.0)


# --- the cold room -----------------------------------------------------------


## Third phase only, and outside the cycle entirely. Health is an integer, so
## the rate is banked and spent in whole points with the remainder carried -
## the wraith's arrangement, because it is the same idea.
func _chill(delta: float) -> void:
	if tier() < 3:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not player.has_method("drain"):
		return
	if player.global_position.distance_to(global_position) > chill_radius:
		return
	_owed += delta * _chill_rate
	var points := int(_owed)
	if points > 0:
		_owed -= points
		player.call("drain", points)


# --- the crossing ------------------------------------------------------------


## Start one if he is watching a player he cannot reach. Distance alone, which
## is the whole cue: the crossing is how he keeps a kiting player in the same
## room as him, and now that it hurts it is also what that player pays.
func _consider_dash() -> void:
	if _dash_cool > 0.0 or phase != Phase.CHASE:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var to_player := player.global_position - global_position
	var distance := to_player.length()
	if distance > sight_radius or distance <= dash_range:
		return
	dashing = true
	dash_moving = false
	_dash_hit = false
	_dash_time = 0.0
	_dash_from = global_position
	_dash_dir = signf(to_player.x) if absf(to_player.x) > 0.01 else 1.0
	# THROUGH, which is a thing two solid bodies do not do on their own: his
	# own move_and_slide() collided with the player and stopped him dead 11 px
	# short, so the pass-through was a boss walking into you and halting. An
	# exception for the one body he is crossing, dropped the moment he arrives
	# - the arena's walls still stop him, which is the whole reason this is an
	# exception and not a collision mask.
	_dash_excepted = player
	add_collision_exception_with(player)
	# The picture, on the frame the crossing starts rather than the frame
	# after. `_dash_step` does not run until the next physics step, so without
	# this he spends one frame crossing the room in his idle pose.
	_apply_animation("dash")


## One frame of the crossing. It keeps the base's bookkeeping that still
## matters mid-dash - the hurt flash and the interrupt lock both tick - and
## drives position through `velocity` rather than by assignment, so the arena's
## walls still stop him.
func _dash_step(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
	if _interrupt_locked > 0.0:
		_interrupt_locked = maxf(_interrupt_locked - delta, 0.0)
	touching_player = false
	_dash_time += delta

	var beat := _beat_at(_dash_time)
	dash_moving = beat["moving"]
	_facing_left = _dash_dir < 0.0
	var target := _dash_from + Vector2(beat["x"] * _dash_dir, 0.0)
	velocity = (target - global_position) / maxf(delta, 0.0001)
	move_and_slide()
	if beat.get("hit", false):
		_pass_through()

	_apply_animation("dash")
	_sprite.modulate = HURT_TINT if _flash > 0.0 else _resting_tint()

	if _dash_time >= _dash_total:
		dashing = false
		dash_moving = false
		_dash_cool = dash_cooldown
		_solid_again()


## He passes through whoever is on the line, once per crossing. Metered by the
## player's grace window like any blow - it goes in through take_damage() and
## is nothing special on the way.
func _pass_through() -> void:
	if _dash_hit:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not player.has_method("take_damage"):
		return
	if player.global_position.distance_to(global_position) > dash_reach:
		return
	_dash_hit = true
	player.call("take_damage", _dash_damage)
	shook.emit(SHAKE["dash"], SHAKE_SECONDS)


func _beat_at(seconds: float) -> Dictionary:
	var acc := 0.0
	for beat in DASH:
		acc += beat["dur"]
		if seconds < acc:
			return beat
	return DASH[DASH.size() - 1]


static func _total_of(beats: Array) -> float:
	var total := 0.0
	for beat in beats:
		total += beat["dur"]
	return total


func _distance_to_player() -> float:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return INF
	return player.global_position.distance_to(global_position)


# --- phases and the end ------------------------------------------------------


## A phase arriving is announced and it arrives AT ONCE: both cooldowns clear,
## so the new thing he does is the next thing he does. He has no cuffs to
## adjust, so what he spends on the announcement is a rung of his own shine.
func take_damage(amount: int) -> void:
	var before := tier()
	super(amount)
	if has_conceded:
		return
	var now := tier()
	if now == before:
		return
	_tier = now
	herald = HERALD_SECONDS
	_glare_timer = 0.0
	_split_timer = 0.0
	shook.emit(HERALD_SHAKE, SHAKE_SECONDS)


## Losing flight is the defeat, so the crossing stops wherever it had got to -
## a boss who concedes mid-dash must not keep sliding while he sinks.
func _concede() -> void:
	dashing = false
	dash_moving = false
	herald = 0.0
	velocity = Vector2.ZERO
	_solid_again()
	super()


## He is only allowed through one body for the half second he is crossing it.
## Called from both ends - the arrival and a concede mid-flight - because a
## boss left permanently able to walk through the player is a boss you can
## never corner.
func _solid_again() -> void:
	if _dash_excepted == null:
		return
	if is_instance_valid(_dash_excepted):
		remove_collision_exception_with(_dash_excepted)
	_dash_excepted = null


func _on_animation_finished() -> void:
	if has_conceded and _sprite.animation == &"concede_side":
		_sprite.play("beaten_side")
