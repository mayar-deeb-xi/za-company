extends CharacterBody2D
class_name EnemyBase
## Base for every enemy type. An enemy stands guard until the player comes
## within sight, chases while they stay there, and presses its touch on them
## for every physics frame of contact.
##
## Touch damage deliberately carries no timer of its own, exactly like
## hazard_base.gd: the player's grace window is the one meter for all contact
## pressure in the game. What a touch DOES is the seam between enemy types -
## the base deals damage, and a later freezing or shoving enemy overrides
## _touch() while inheriting everything else.
##
## Stats are @exports so a level can retune the instance it places; the numbers
## below are the "regular" enemy the whole system is tuned around.

@export var max_health := 10
@export var contact_damage := 5
@export var speed := 55.0
## Guard radius: asleep beyond it, chasing inside it. Kept modest so an enemy
## reads as owning a corner of the room rather than the whole map.
@export var sight_radius := 80.0

const HURT_FLASH_SECONDS := 0.15
const HURT_TINT := Color(1.0, 0.4, 0.4)

enum Facing { DOWN, UP, SIDE }

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _touch_area: Area2D = $Touch

var health := 0

var _facing: Facing = Facing.DOWN
var _facing_left := false
var _flash := 0.0


func _ready() -> void:
	health = max_health


func _physics_process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		if _flash == 0.0:
			_sprite.modulate = Color.WHITE

	# Group + method rather than type, like hazards and pickups: nothing here
	# names the player's script.
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var chasing := false
	if player != null and global_position.distance_to(player.global_position) <= sight_radius:
		var direction := global_position.direction_to(player.global_position)
		velocity = direction * speed
		_face(direction)
		chasing = true
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	var touching := false
	for body in _touch_area.get_overlapping_bodies():
		if body.is_in_group("player"):
			touching = true
			_touch(body)

	_apply_animation("attack" if touching else ("walk" if chasing else "idle"))


## What touching the player does - the one thing enemy types differ in. The
## base presses damage and lets the player's grace window meter it; an enemy
## that freezes, shoves or poisons instead overrides this.
func _touch(player: Node2D) -> void:
	if player.has_method("take_damage"):
		player.call("take_damage", contact_damage)


func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health = maxi(health - amount, 0)
	_flash = HURT_FLASH_SECONDS
	_sprite.modulate = HURT_TINT
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
