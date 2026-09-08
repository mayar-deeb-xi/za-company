extends "res://game/bosses/boss_base.gd"
## Ahmed, F4's boss. 96 HP - four heavies, sixteen light hits - and a burning
## axe with four attacks, chosen by where you are and what you have been doing:
##
## - **chop** and **sweep** alternate when you are in reach. Same reach, same
##   cycle, different telegraphs: the axe up behind his head, or dragged low
##   behind him. 16 and 12 damage.
## - **slam** is the AREA attack, every third swing, or sooner if you hit him
##   twice inside two seconds - the punishment for standing in his face and
##   mashing. Both hands, a one-second wind-up while a ring of embers creeps out
##   to r 40, then 20 damage to EVERYONE in the ring: the player and any office
##   boy alike, which is what makes fighting beside his adds a way to have him
##   clear them for you. The 0.9 s recover afterwards is the punish window.
## - **wave** is the RANGED one, for anyone who thinks distance is safe: when
##   you are in front of him and out of reach, a wave of fire runs 64 px along
##   the floor in a straight line. Sidestep, do not backpedal. 14 damage, then
##   a cooldown so he cannot camp behind it.
##
## Each attack's wind-up and recover come from its frames in poses.gd, so the
## picture and the timer are one thing. Every hit is metered by the player's
## grace window like any blow; nothing here drains.
##
## Reach is three Area2Ds: `Touch` (r 24, the axe's melee reach, and what the
## base uses to decide he has arrived), `Ring` (r 40, the slam) and `Lane` (a
## 64x16 box in front of him that swings to whichever way he faces, the wave).

const Poses := preload("res://game/bosses/ahmed/poses.gd")

## MEDIUM numbers; the difficulty scale is applied by the base when chosen.
const DAMAGE := {"chop": 16, "sweep": 12, "slam": 20, "wave": 14}
## Melee attacks between slams.
const SWINGS_PER_SLAM := 2
## Two hits inside this window bring the slam forward.
const HIT_WINDOW := 2.0
## How far the wave has travelled on the strike frame itself, before the
## frames that carry it on down the lane.
const WAVE_START := 20.0
## Slack past the drawn front, so a body on the edge of the fire is in it.
const WAVE_SLACK := 6.0

@export var wave_cooldown := 3.0
## Closer than this and the axe would do; the wave is for the gap.
@export var wave_min_distance := 34.0

@onready var _ring: Area2D = $Ring
@onready var _lane: Area2D = $Lane
@onready var _lane_reach: float = absf(_lane.position.x)

var _swings := 0
var _last_melee := "sweep"
var _slam_due := false
var _hits := 0
var _hit_window := 0.0
var _wave_timer := 0.0
var _wave_hit := {}


func _physics_process(delta: float) -> void:
	_wave_timer = maxf(_wave_timer - delta, 0.0)
	_hit_window = maxf(_hit_window - delta, 0.0)
	super(delta)
	if has_conceded:
		return
	_lane.position.x = -_lane_reach if _facing_left else _lane_reach
	if attack == "wave" and phase == Phase.RECOVER:
		_wave_travel()


func _attack_spec(id: String) -> Dictionary:
	return {
		"windup": Poses.windup_of(id),
		"recover": Poses.recover_of(id),
		"damage": DAMAGE[id],
	}


## In reach: slam when it is owed, otherwise the other of chop and sweep.
func _pick_attack() -> String:
	if _slam_due or _swings >= SWINGS_PER_SLAM:
		_slam_due = false
		_swings = 0
		return "slam"
	_swings += 1
	_last_melee = "sweep" if _last_melee == "chop" else "chop"
	return _last_melee


## The wave opens from CHASE without contact: the player is in the lane and
## out of reach, and the last one has cooled down. Everything else is the base.
func _advance_phase() -> void:
	if phase == Phase.CHASE and not touching_player and _wave_timer <= 0.0 \
			and _player_in_lane():
		_begin_attack("wave")
		return
	super()


func _player_in_lane() -> bool:
	for body in _lane.get_overlapping_bodies():
		if body.is_in_group("player") and _forward_of(body) >= wave_min_distance:
			return true
	return false


## How far ahead of him a body stands, along the way he faces.
func _forward_of(body: Node2D) -> float:
	var dx := body.global_position.x - global_position.x
	return -dx if _facing_left else dx


## The blow, per attack. The base's own strike is the axe on whoever is in
## Touch; the slam and the wave read their own shapes.
func _strike() -> void:
	match attack:
		"slam":
			for body in _ring.get_overlapping_bodies():
				if body != self and body.has_method("take_damage"):
					body.call("take_damage", contact_damage)
		"wave":
			_wave_timer = wave_cooldown
			_wave_hit.clear()
			_wave_reach(WAVE_START)
		_:
			super()


## The wave runs on through the recover: each frame that draws it further down
## the lane hits whoever it has reached and not yet burned.
func _wave_travel() -> void:
	var frames: Array = Poses.ANIMS["wave"]
	var idx := clampi(_sprite.frame, 0, frames.size() - 1)
	for fx in frames[idx].get("fx", []):
		if fx[0] == "wave":
			_wave_reach(fx[2])


func _wave_reach(front: float) -> void:
	for body in _lane.get_overlapping_bodies():
		if body == self or _wave_hit.has(body) or not body.has_method("take_damage"):
			continue
		if _forward_of(body) <= front + WAVE_SLACK:
			_wave_hit[body] = true
			body.call("take_damage", contact_damage)


func take_damage(amount: int) -> void:
	super(amount)
	if has_conceded:
		return
	_hits = _hits + 1 if _hit_window > 0.0 else 1
	_hit_window = HIT_WINDOW
	if _hits >= 2:
		_slam_due = true
