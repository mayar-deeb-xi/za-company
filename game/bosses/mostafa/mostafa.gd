extends "res://game/bosses/boss_base.gd"
## Mostafa, F7's boss. 144 HP - six heavies, twenty-four light hits - and a
## rhythm rather than a menu. Where Ahmed picks an attack to suit the range,
## Mostafa runs a COMBINATION and makes you learn its shape:
##
## - **jab, jab, hook**, in that order, three times through, then a breath.
##   That is the whole fight. The jabs are 0.25 s and 6 damage and are
##   effectively uninterruptible - they are swings, so step out and they whiff
##   rather than being staggered out of him. The hook is 0.7 s and 18, and it
##   IS interruptible: it is the one read, and the one punish.
## - **corner rush** breaks the pattern for a player who kites. If you are out
##   of reach and in front of him he closes the gap in one dash, then the
##   combination starts again from the top.
##
## The interrupt economy is enemy_base's, unchanged - `commit_fraction` and
## `interrupt_cooldown` mean what they always meant. The only thing this script
## does with them is set commit per attack when the attack begins, which is
## what makes the jab uninterruptible and the hook not.
##
## Each attack's wind-up and recover come from its frames in poses.gd, so the
## picture and the timer are one thing. Every hit is a blow, metered by the
## player's grace window; nothing here drains.
##
## He is drawn FRONT ON at 2x density - see poses.gd for why both of those are
## deliberate, and why the base's side-only facing still works on him.

const Poses := preload("res://game/bosses/mostafa/poses.gd")

## MEDIUM numbers; the difficulty scale is applied by the base when chosen.
const DAMAGE := {"jab": 6, "hook": 18, "rush": 10}

## The combination, run in order and then repeated.
const COMBO := ["jab", "jab", "hook"]

## Per-attack commit. The jabs are swings you step out of, not blows you
## stagger him out of; the hook is the one that can be interrupted early.
const COMMIT := {"jab": 1.0, "hook": 0.45, "rush": 1.0}

## How hard the room takes each blow - world pixels of camera throw, decaying
## over SHAKE_SECONDS. Applied by game.gd off `shook`; see boss_base. It is on
## every blow, the jab included - it is 3 px where the hook is 4.65, which is
## what keeps the hook the big one. Zero an entry to take the throw off that
## attack without touching the rest.
const SHAKE := {"jab": 3.0, "hook": 4.65, "rush": 3.6}
const SHAKE_SECONDS := 0.12

## Hit-stop: the sprite holds still for this long on the frame the blow lands,
## which is most of what tells a player the attack is OVER. The hook gets half
## again, being the one worth stopping for.
##
## It pauses the SPRITE only - `_phase_time` runs on untouched, so his wind-up,
## his recover and the window you can punish him in are all exactly what
## poses.gd says. The cost is that the last 0.08 s of the recover animation is
## clipped when the phase moves on before the picture has finished, which is
## the right way round: the timings are load-bearing and the tail of a
## return-to-guard is not. Set to 0.0 to switch it off.
const HIT_STOP := 0.08
const HIT_STOP_HOOK := 1.3

## THE RAGE. At half health he goes up, once, and never comes back down -
## `rage.gd` draws it, this decides when. Half of 144 is 72, which is already a
## moment: his floor cues a reinforcement beat at `at_boss_health: 72`, so the
## fire and the south door open together.
##
## One flip rather than a ladder. DESIGN.md gives the ladder to Khaled, and two
## bosses making the same argument is one boss too many.
##
## He does NOT get stronger here. Every number in this file is still the
## number it was, because 24 / 17 / 36 and the heavy's 24 are exact combo
## breakpoints and the fight was tuned around them. If the rage should bite as
## well as burn, the cheapest honest lever is `breath_seconds`: the combination
## he taught you, arriving with less room to answer it.
const RAGE_AT := 0.5
## Seconds into the animation that the blast lands - the same number rage.gd
## draws it on, and the frame boundary in poses.gd both come off.
const RAGE_BLAST := 0.51
## He holds still on the blast, and the whole room takes it.
const RAGE_HOLD := 0.12
const RAGE_SHAKE := 6.0
const RAGE_SHAKE_SECONDS := 0.20

## Public, because the fire he KEEPS has to outlive the animation that started
## it: rage.gd reads this rather than trying to see a rage in an idle sprite.
var is_raging := false

## After a full combination he holds for this long before starting again -
## the window the fight is built around.
@export var breath_seconds := 0.7
## Closer than this and he just punches; the rush is for the gap.
@export var rush_min_distance := 46.0
@export var rush_cooldown := 3.5
## How far the dash carries him, per strike frame.
@export var rush_speed := 190.0

@onready var _lane: Area2D = $Lane
@onready var _lane_reach: float = absf(_lane.position.x)

var _step := 0
var _breath := 0.0
var _rush_timer := 0.0
var _stop := 0.0
## Seconds into the eruption, and -1 when he is not having one.
var _rage_time := -1.0
var _blown := false


func _physics_process(delta: float) -> void:
	_rush_timer = maxf(_rush_timer - delta, 0.0)
	_breath = maxf(_breath - delta, 0.0)
	# Hit-stop, and the one thing that must always let go of it: a boss who
	# conceded mid-hold still has a concede animation to play.
	if _stop > 0.0:
		_stop = 0.0 if has_conceded else maxf(_stop - delta, 0.0)
		_sprite.speed_scale = 0.0 if _stop > 0.0 else 1.0
	_burn(delta)
	super(delta)
	if has_conceded:
		return
	_lane.position.x = -_lane_reach if _facing_left else _lane_reach
	# The dash IS the rush's wind-up: he crouches, runs, and the blow lands on
	# the last running frame, so he connects when he arrives rather than
	# swinging at the air halfway there. There is no STRIKE phase to hang this
	# on - enemy_base fires the blow at the end of WINDUP and goes straight to
	# RECOVER - so the travel is the whole wind-up.
	if attack == "rush" and phase == Phase.WINDUP:
		var dir := -1.0 if _facing_left else 1.0
		velocity.x = dir * rush_speed
		move_and_slide()


## The eruption's own clock. It follows the SPRITE rather than the wall: while
## the blast holds him still, this holds too, so the fire rage.gd draws off the
## animation and the blast this fires cannot come apart.
func _burn(delta: float) -> void:
	if _rage_time < 0.0 or has_conceded:
		return
	if _stop > 0.0:
		return
	var was := _rage_time
	_rage_time += delta
	if not _blown and was < RAGE_BLAST and _rage_time >= RAGE_BLAST:
		_blown = true
		_stop = RAGE_HOLD
		_sprite.speed_scale = 0.0
		shook.emit(RAGE_SHAKE, RAGE_SHAKE_SECONDS)
	if _rage_time >= Poses.length_of("rage"):
		_rage_time = -1.0


## True only while the eruption is playing. He is rooted, silent and
## un-staggerable for its 0.95 s; `is_raging` is the thing that stays true.
func _erupting() -> bool:
	return _rage_time >= 0.0


func _attack_spec(id: String) -> Dictionary:
	return {
		"windup": Poses.windup_of(id),
		"recover": Poses.recover_of(id),
		"damage": DAMAGE[id],
	}


## Commit is per attack here, which the base does not do for itself.
func _begin_attack(id: String) -> void:
	commit_fraction = COMMIT.get(id, 0.6)
	super(id)


## The blow. The base decides whether it FINDS anybody; the room takes it
## either way, because a punch that misses still landed somewhere - and because
## the effect drawing it keys off the animation, which does not know either.
func _strike() -> void:
	var id := attack
	# The blow, before `super()` - which can clear `attack` - and paired with
	# the telegraph boss_base already fires on the wind-up. Said here rather
	# than in the base for the same reason as Ahmed's: a boss lands a blow his
	# own way. It plays whether or not the punch found anybody, exactly like
	# the shake below, because a punch that misses still landed somewhere.
	_sfx(id + "_hit")
	super()
	_stop = HIT_STOP * (HIT_STOP_HOOK if id == "hook" else 1.0)
	var throw: float = SHAKE.get(id, 0.0)
	if throw > 0.0:
		shook.emit(throw, SHAKE_SECONDS)


## In reach: the next beat of the combination, unless he is still breathing
## after finishing one.
func _pick_attack() -> String:
	if _breath > 0.0:
		return ""
	var id: String = COMBO[_step]
	_step += 1
	if _step >= COMBO.size():
		_step = 0
		_breath = breath_seconds
	return id


## Half health, once. Checked after the base has taken the hit, so a blow that
## finishes him concedes instead of setting him on fire on the way down.
func take_damage(amount: int) -> void:
	super(amount)
	if is_raging or has_conceded or health <= 0:
		return
	if health <= roundi(float(max_health) * RAGE_AT):
		_begin_rage()


## He drops whatever he was swinging. Being interrupted by your own temper is
## the point: the combination stops mid-count and starts again from the top.
func _begin_rage() -> void:
	# Both halves of the noise, on the one frame he goes up. The eruption is a
	# one-shot cut to land its loudest moment on RAGE_BLAST, so the blast, the
	# camera shake and the sound are one event rather than three. The fire
	# underneath it is a LOOP with no stop anywhere - he catches fire once and
	# never comes back down, and he is still burning when he kneels, which is
	# why nothing fades it on concede the way Ahmed's axe fades: Ahmed drops
	# the axe, and Mostafa is the fire.
	_sfx("rage")
	_sfx_loop("fire")
	# And the line. His alone - the base fires spot/taunt/hurt/stagger/concede
	# and one cue per attack, and none of those is "the moment the process
	# stops". It is said BEFORE `is_raging` goes true only for readability;
	# `_say` neither reads nor cares about that flag.
	_say("rage")
	is_raging = true
	_rage_time = 0.0
	_blown = false
	attack = ""
	_step = 0
	_breath = 0.0
	_stop = 0.0
	_sprite.speed_scale = 1.0
	_enter(Phase.CHASE)


## Rooted through the eruption: no attack starts, and the rush cannot open.
func _advance_phase() -> void:
	if _erupting():
		return
	if phase == Phase.CHASE and not touching_player and _rush_timer <= 0.0 \
			and _breath <= 0.0 and _player_in_lane():
		_rush_timer = rush_cooldown
		_begin_attack("rush")
		return
	super()


## The eruption is the whole animation, so it owns the sprite while it runs.
func _animation_state(advancing: bool) -> String:
	if _erupting():
		return "rage"
	return super(advancing)


## He does not walk through it, and he cannot be staggered out of it. Damage
## still lands - a 0.95 s window of free hits is the reward for being close.
func _can_advance() -> bool:
	if _erupting():
		return false
	return super()


func _interruptible() -> bool:
	if _erupting():
		return false
	return super()


func _player_in_lane() -> bool:
	for body in _lane.get_overlapping_bodies():
		if body.is_in_group("player") and _forward_of(body) >= rush_min_distance:
			return true
	return false

## How far ahead of him a body stands, along the way he faces.
func _forward_of(body: Node2D) -> float:
	var dx := body.global_position.x - global_position.x
	return -dx if _facing_left else dx
