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


func _physics_process(delta: float) -> void:
	_rush_timer = maxf(_rush_timer - delta, 0.0)
	_breath = maxf(_breath - delta, 0.0)
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


## The rush opens from CHASE without contact: the player is in the lane, out of
## reach, and the last dash has cooled down. Everything else is the base's.
func _advance_phase() -> void:
	if phase == Phase.CHASE and not touching_player and _rush_timer <= 0.0 \
			and _breath <= 0.0 and _player_in_lane():
		_rush_timer = rush_cooldown
		_begin_attack("rush")
		return
	super()


func _player_in_lane() -> bool:
	for body in _lane.get_overlapping_bodies():
		if body.is_in_group("player") and _forward_of(body) >= rush_min_distance:
			return true
	return false


## How far ahead of him a body stands, along the way he faces.
func _forward_of(body: Node2D) -> float:
	var dx := body.global_position.x - global_position.x
	return -dx if _facing_left else dx
