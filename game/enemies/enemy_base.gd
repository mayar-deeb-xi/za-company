extends CharacterBody2D
class_name EnemyBase
## Base for every enemy type. An enemy stands guard until the player comes
## within sight, closes the ground to `stop_distance` and holds there facing
## them, and presses its touch on them for every physics frame of contact.
##
## Touch damage deliberately carries no timer of its own, exactly like
## hazard_base.gd: the player's grace window is the one meter for all contact
## pressure in the game. What a touch DOES is the seam between enemy types -
## the base deals damage, and a freezing, shoving or draining enemy overrides
## _touch() while inheriting everything else. An effect that sets its OWN rate
## takes the delta it is handed and presses the player's drain() instead, which
## is the entry point that sits outside the grace window.
##
## Two smaller seams travel with it, because an effect is rarely only damage:
## _contact_state() is what contact looks like (the base lunges), and
## _resting_tint() is how the enemy reads while it works.
##
## Stats are @exports so a level can retune the instance it places; the numbers
## below are the "regular" enemy the whole system is tuned around.

@export var max_health := 10
@export var contact_damage := 5
@export var speed := 55.0
## Guard radius: asleep beyond it, chasing inside it. Kept modest so an enemy
## reads as owning a corner of the room rather than the whole map.
@export var sight_radius := 80.0
## How close it comes before it stops advancing and just holds station. Pressing
## on into the player's collision does not get an enemy any closer - the two
## bodies block at the sum of their radii - it only grinds them together and
## slides the enemy around the player in a circle.
##
## Bounded on both sides, and the upper bound is the easy one to break: it must
## be MORE than the two body radii (10 px for everything so far) or the enemy
## never stops short of the grind, and LESS than the reach of its own Touch
## shape, or it parks just outside its own effect and nothing ever happens.
@export var stop_distance := 12.0

const HURT_FLASH_SECONDS := 0.15
const HURT_TINT := Color(1.0, 0.4, 0.4)

enum Facing { DOWN, UP, SIDE }

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _touch_area: Area2D = $Touch

var health := 0
## True on every frame this enemy is in contact with the player. Settled before
## _contact_state() and _resting_tint() are asked, so an override can read it.
var touching_player := false

var _facing: Facing = Facing.DOWN
var _facing_left := false
var _flash := 0.0


func _ready() -> void:
	health = max_health


func _physics_process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)

	# Group + method rather than type, like hazards and pickups: nothing here
	# names the player's script.
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var advancing := false
	velocity = Vector2.ZERO
	if player != null:
		var to_player := player.global_position - global_position
		var distance := to_player.length()
		if distance <= sight_radius:
			# Keep facing the player whether or not there is still ground to
			# close: an enemy holding station should still turn to watch them.
			var direction := to_player / maxf(distance, 0.001)
			_face(direction)
			advancing = distance > stop_distance
			if advancing:
				velocity = direction * speed
	move_and_slide()

	touching_player = false
	for body in _touch_area.get_overlapping_bodies():
		if body.is_in_group("player"):
			touching_player = true
			_touch(body, delta)

	# "walk" only while it is actually walking. An enemy that has arrived and
	# stopped is either doing its contact state or simply standing there.
	_apply_animation(_contact_state() if touching_player
		else ("walk" if advancing else "idle"))
	# Resolved after _touch(), so an effect that tints while it works has
	# already seen this frame's contact. Being hurt outranks whatever it wants.
	_sprite.modulate = HURT_TINT if _flash > 0.0 else _resting_tint()


## What touching the player does - the one thing enemy types differ in. The
## base presses damage and lets the player's grace window meter it; an enemy
## that freezes, shoves or drains overrides this instead. `delta` is this
## frame's worth of contact, which is what an effect with its own rate needs.
func _touch(player: Node2D, _delta: float) -> void:
	if player.has_method("take_damage"):
		player.call("take_damage", contact_damage)


## The animation state contact puts the enemy in. The base lunges; a type whose
## harm is an aura rather than a blow keeps walking.
func _contact_state() -> String:
	return "attack"


## How the enemy reads when it is not mid-hurt-flash. White unless a type has
## something to show - the wraith glows while it feeds.
func _resting_tint() -> Color:
	return Color.WHITE


func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health = maxi(health - amount, 0)
	# The tint itself is applied by _physics_process, which is the one place
	# that decides how the sprite reads.
	_flash = HURT_FLASH_SECONDS
	if health == 0:
		queue_free()


func _face(direction: Vector2) -> void:
	# Horizontal wins ties, so a diagonal reads as the side profile.
	if absf(direction.x) >= absf(direction.y):
		_facing = Facing.SIDE
		_facing_left = direction.x < 0.0
	else:
		_facing = Facing.UP if direction.y < 0.0 else Facing.DOWN


func _apply_animation(state: String) -> void:
	_sprite.flip_h = _facing == Facing.SIDE and _facing_left
	var suffix := "down"
	match _facing:
		Facing.UP:
			suffix = "up"
		Facing.SIDE:
			suffix = "side"
	var anim := "%s_%s" % [state, suffix]
	# The attack animation does not loop; the is_playing() check restarts it
	# for as long as the enemy stays in contact.
	if _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)
