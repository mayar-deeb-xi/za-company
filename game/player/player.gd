extends CharacterBody2D
## Top-down player. Moves in 8 directions but animates in 3 (down / up / side),
## because the sheet only draws a right-facing profile - left is that, flipped.

const SPEED := 90.0
const ACCELERATION := 900.0
const FRICTION := 1100.0
const MAX_HEALTH := 100
## How many times health can hit zero before the run ends. The player node is
## built fresh by each new game scene, so a new run starts full again.
const MAX_LIVES := 3
## Grace period after a hit. Doubles as the drain rate for standing in a
## hazard: hazards push damage every physics frame and this window is what
## meters that pressure into discrete hits.
const HURT_GRACE_SECONDS := 0.8

signal health_changed(health: int, max_health: int)
signal lives_changed(lives: int, max_lives: int)
signal died

## Preloaded by path rather than via `class_name`, like the rest of the project.
const Roster := preload("res://game/player/characters/roster.gd")

enum Facing { DOWN, UP, SIDE }

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

var health := MAX_HEALTH
var lives := MAX_LIVES

var _facing: Facing = Facing.DOWN
var _facing_left := false
var _attacking := false
var _grace := 0.0


func _ready() -> void:
	_apply_character()
	_sprite.animation_finished.connect(_on_animation_finished)
	_apply_animation("idle")


## Every character shares the same animation set, so becoming one is a frames
## swap. An unknown saved id keeps the scene's default look rather than crashing.
func _apply_character() -> void:
	var id: String = Settings.get_value(&"player", &"character", Roster.DEFAULT_ID)
	var path := Roster.frames_path(id)
	if path != "" and path != _sprite.sprite_frames.resource_path:
		_sprite.sprite_frames = load(path)


func _physics_process(delta: float) -> void:
	if _grace > 0.0:
		_grace = maxf(_grace - delta, 0.0)
		# Blink for as long as the grace lasts, so a hit reads on the character
		# and not only on the HUD bar.
		_sprite.visible = _grace == 0.0 or fmod(_grace, 0.2) >= 0.1

	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if not _attacking and Input.is_action_just_pressed("attack"):
		_start_attack()

	if _attacking:
		# Attacks root the character in place.
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	elif direction != Vector2.ZERO:
		_face(direction)
		velocity = velocity.move_toward(direction * SPEED, ACCELERATION * delta)
		_apply_animation("walk")
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		_apply_animation("idle")

	move_and_slide()


func _face(direction: Vector2) -> void:
	# Horizontal wins ties, so a diagonal reads as the side profile.
	if absf(direction.x) >= absf(direction.y):
		_facing = Facing.SIDE
		_facing_left = direction.x < 0.0
	else:
		_facing = Facing.UP if direction.y < 0.0 else Facing.DOWN


func _facing_suffix() -> String:
	match _facing:
		Facing.UP:
			return "up"
		Facing.SIDE:
			return "side"
		_:
			return "down"


func _apply_animation(state: String, restart := false) -> void:
	_sprite.flip_h = _facing == Facing.SIDE and _facing_left
	var anim := "%s_%s" % [state, _facing_suffix()]
	if restart:
		_sprite.animation = anim
		_sprite.frame = 0
		_sprite.play(anim)
	elif _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)


func _start_attack() -> void:
	_attacking = true
	_apply_animation("attack", true)


func _on_animation_finished() -> void:
	if _attacking:
		_attacking = false
		_apply_animation("idle")


func take_damage(amount: int) -> void:
	if _grace > 0.0 or health <= 0:
		return
	health = maxi(health - amount, 0)
	_grace = HURT_GRACE_SECONDS
	health_changed.emit(health, MAX_HEALTH)
	if health == 0:
		died.emit()


## Returns false when nothing was healed, so a pickup can stay on the floor
## for a player who is already full.
func heal(amount: int) -> bool:
	if health >= MAX_HEALTH or health <= 0:
		return false
	health = mini(health + amount, MAX_HEALTH)
	health_changed.emit(health, MAX_HEALTH)
	return true


## One life gone. Returns how many remain, so game.gd can choose respawn or
## game over from the same call instead of racing a second signal.
func lose_life() -> int:
	lives = maxi(lives - 1, 0)
	lives_changed.emit(lives, MAX_LIVES)
	return lives


## Back to full, called by game.gd when it respawns the player after a death.
func revive() -> void:
	health = MAX_HEALTH
	_grace = 0.0
	_sprite.visible = true
	health_changed.emit(health, MAX_HEALTH)
