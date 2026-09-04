extends CharacterBody2D
## Top-down player. Moves in 8 directions but animates in 3 (down / up / side),
## because the sheet only draws a right-facing profile - left is that, flipped.

const SPEED := 90.0
const ACCELERATION := 900.0
const FRICTION := 1100.0
const MAX_HEALTH := 100
## Damage one swing deals to each enemy it reaches. A constant for now; when
## characters grow their own stats this moves into the roster recipe the same
## way looks did.
const ATTACK_POWER := 5
## How many times health can hit zero before the run ends. The player node is
## built fresh by each new game scene, so a new run starts full again.
const MAX_LIVES := 3
## Grace period after a hit. Doubles as the drain rate for standing in a
## hazard: hazards push damage every physics frame and this window is what
## meters that pressure into discrete hits.
const HURT_GRACE_SECONDS := 0.8
## Floor on how far a slow may go. Below roughly this the player is not really
## playing any more, and no combination of sources should get there.
const MIN_SLOW_FACTOR := 0.2
## How a slowed character reads. Cold, and deliberately a tint rather than the
## blink the grace window owns, so being hurt and being slowed never look alike.
const SLOW_TINT := Color(0.6, 0.75, 1.0)

signal health_changed(health: int, max_health: int)
signal lives_changed(lives: int, max_lives: int)
signal died

## Preloaded by path rather than via `class_name`, like the rest of the project.
const Roster := preload("res://game/player/characters/roster.gd")

enum Facing { DOWN, UP, SIDE }

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _hitbox: Area2D = $Hitbox

var health := MAX_HEALTH
var lives := MAX_LIVES
## The movement multiplier currently in force and how long is left of it. Public
## because they are a readout: the sprite tint reads them now and a HUD status
## icon would read the same pair.
var slow_factor := 1.0
var slow_seconds := 0.0

var _facing: Facing = Facing.DOWN
var _facing_left := false
var _attacking := false
var _grace := 0.0
## Enemies already struck by the current swing, so a swing lands once per enemy
## rather than once per physics frame it overlaps them.
var _swing_hits := {}


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

	if slow_seconds > 0.0:
		slow_seconds = maxf(slow_seconds - delta, 0.0)
		if slow_seconds == 0.0:
			slow_factor = 1.0
		_sprite.modulate = SLOW_TINT if slow_seconds > 0.0 else Color.WHITE

	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if not _attacking and Input.is_action_just_pressed("attack"):
		_start_attack()

	if _attacking:
		# Attacks root the character in place.
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		_strike()
	elif direction != Vector2.ZERO:
		_face(direction)
		velocity = velocity.move_toward(direction * SPEED * slow_factor,
			ACCELERATION * delta)
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
	# A slowed walk played at full rate reads as skating across the floor. The
	# swing keeps its own timing - a slow takes your legs, not your sword.
	_sprite.speed_scale = slow_factor if state == "walk" else 1.0
	var anim := "%s_%s" % [state, _facing_suffix()]
	if restart:
		_sprite.animation = anim
		_sprite.frame = 0
		_sprite.play(anim)
	elif _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)


func _start_attack() -> void:
	_attacking = true
	_swing_hits.clear()
	_hitbox.position = _hitbox_offset()
	_apply_animation("attack", true)


## The hitbox sits one step ahead of the body in whatever direction the swing
## faces, and stays live for the whole animation.
func _hitbox_offset() -> Vector2:
	match _facing:
		Facing.UP:
			return Vector2(0, -14)
		Facing.SIDE:
			return Vector2(-11 if _facing_left else 11, -4)
		_:
			return Vector2(0, 6)


## Group + method rather than type, like every cross-feature touch in this
## project: the player never names an enemy script.
func _strike() -> void:
	for body in _hitbox.get_overlapping_bodies():
		if _swing_hits.has(body) or not body.is_in_group("enemies"):
			continue
		if body.has_method("take_damage"):
			_swing_hits[body] = true
			body.call("take_damage", ATTACK_POWER)


func _on_animation_finished() -> void:
	if _attacking:
		_attacking = false
		_apply_animation("idle")


## A blow: metered by the grace window, and it opens a fresh one.
func take_damage(amount: int) -> void:
	if _grace > 0.0 or health <= 0:
		return
	_grace = HURT_GRACE_SECONDS
	_lose_health(amount)


## Health lost to a continuous effect rather than a blow - an aura, a poison,
## anything that sets its own rate. Deliberately outside the grace window in
## both directions: it is not blocked by one and it does not open one.
##
## The grace window exists to stop discrete hits stacking every physics frame,
## which is the wrong meter for something that already knows how fast it should
## work. Routed through take_damage(), a drain would be swallowed for 0.8s
## every time an unrelated torch clipped the player, and would blink the sprite
## as though they were being struck once a second.
func drain(amount: int) -> void:
	if health <= 0:
		return
	_lose_health(amount)


## A status the player CARRIES, which is a third thing again: take_damage() and
## drain() both land and are over in the same frame, while this has a duration
## of its own and expires on its own. Outside the grace window for the same
## reason drain() is - it is not a blow, so a torch clip must not swallow it.
##
## Overlapping slows do not compound into a standstill: the strongest in force
## wins and the timer refreshes. Two wardens keep you slow for longer, never
## make you slower.
func apply_slow(factor: float, seconds: float) -> void:
	if health <= 0:
		return
	var strength := clampf(factor, MIN_SLOW_FACTOR, 1.0)
	if slow_seconds <= 0.0 or strength < slow_factor:
		slow_factor = strength
	slow_seconds = maxf(slow_seconds, seconds)


func _lose_health(amount: int) -> void:
	health = maxi(health - amount, 0)
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
	# Statuses die with the life that collected them: respawning into a room
	# still slowed by whatever killed you is a second punishment for one death.
	slow_factor = 1.0
	slow_seconds = 0.0
	_sprite.visible = true
	_sprite.modulate = Color.WHITE
	health_changed.emit(health, MAX_HEALTH)
