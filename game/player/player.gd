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
## Damage the thrust - the combo's second hit - deals. Reached only through a
## swing (a press during one, or just after), so it can never be spammed alone,
## which is what lets it outhit the swing without upsetting any balance.
const THRUST_POWER := 7
## After a swing ends, a press within this window still chains the thrust, so
## deliberate timing combos as reliably as mashing does.
const COMBO_GRACE_SECONDS := 0.2
## Damage the heavy attack - the charged spin plus its wildfire - deals to
## EVERY enemy inside the Spinbox circle. Costs a full second of rooted,
## interruptible charging, so it outhits the whole combo (5+7).
const HEAVY_POWER := 15
## How long the charge stance must be held before a release unleashes the
## heavy. The charge loop doubles speed as the ready cue.
const CHARGE_SECONDS := 1.0
## Forward push at the moment the thrust starts - the art lunges, so the body
## does too. FRICTION eats it in about a tenth of a second.
const LUNGE_SPEED := 130.0
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
@onready var _spinbox: Area2D = $Spinbox

var health := MAX_HEALTH
var lives := MAX_LIVES
## The movement multiplier currently in force and how long is left of it. Public
## because they are a readout: the sprite tint reads them now and a HUD status
## icon would read the same pair.
var slow_factor := 1.0
var slow_seconds := 0.0

var _facing: Facing = Facing.DOWN
var _facing_left := false
## The attack animation currently playing ("" when none), the one buffered to
## chain after it, and how long a late press can still chain a thrust. A press
## mid-attack is buffered rather than dropped - dropped inputs read as the game
## eating the button, and combos live or die on that feel.
var _attack := ""
var _buffered := ""
var _combo_grace := 0.0
## Charge stance: entered by still holding the button when an attack ends,
## rooted while it lasts. Releasing at CHARGE_SECONDS or more unleashes the
## heavy; releasing earlier just returns to idle - the press's swing already
## happened, so an early release loses nothing.
var _charging := false
var _charge := 0.0
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

	if _combo_grace > 0.0:
		_combo_grace = maxf(_combo_grace - delta, 0.0)

	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if not _charging and Input.is_action_just_pressed("attack"):
		if _attack == "":
			_start_attack("attack2" if _combo_grace > 0.0 else "attack")
		else:
			# Mid-swing chains the thrust; mid-thrust queues the next swing.
			_buffered = "attack2" if _attack == "attack" else "attack"

	if _charging:
		_charge += delta
		# The ready cue: the charge loop pulses at double speed.
		_sprite.speed_scale = 2.0 if _charge >= CHARGE_SECONDS else 1.0
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		if not Input.is_action_pressed("attack"):
			_charging = false
			_sprite.speed_scale = 1.0
			if _charge >= CHARGE_SECONDS:
				_start_attack("heavy")
			else:
				_apply_animation("idle")
	elif _attack != "":
		# Attacks root the character in place; the thrust's opening lunge
		# decays under the same friction.
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


func _start_attack(anim: String) -> void:
	_attack = anim
	_buffered = ""
	_combo_grace = 0.0
	_swing_hits.clear()
	if anim != "heavy":
		_hitbox.position = _hitbox_offset(anim == "attack2")
	if anim == "attack2":
		velocity = _facing_vector() * LUNGE_SPEED
	_apply_animation(anim, true)


## The hitbox sits one step ahead of the body in whatever direction the attack
## faces, and stays live for the whole animation. The thrust parks it further
## out: its blade visibly outreaches the swing's arc, and the hitbox keeps that
## promise - the reach is the reward the player feels immediately.
func _hitbox_offset(thrust := false) -> Vector2:
	match _facing:
		Facing.UP:
			return Vector2(0, -18) if thrust else Vector2(0, -14)
		Facing.SIDE:
			var reach := 16 if thrust else 11
			return Vector2(-reach if _facing_left else reach, -4)
		_:
			return Vector2(0, 10) if thrust else Vector2(0, 6)


func _facing_vector() -> Vector2:
	match _facing:
		Facing.UP:
			return Vector2.UP
		Facing.SIDE:
			return Vector2.LEFT if _facing_left else Vector2.RIGHT
		_:
			return Vector2.DOWN


## Group + method rather than type, like every cross-feature touch in this
## project: the player never names an enemy script. The heavy hits through the
## Spinbox circle - all around, as the spin and its fire ring promise - and its
## ledger spans the spin AND the wildfire, so it lands once per enemy total.
func _strike() -> void:
	var heavy := _attack == "heavy" or _attack == "wildfire"
	var area := _spinbox if heavy else _hitbox
	var power := ATTACK_POWER
	if heavy:
		power = HEAVY_POWER
	elif _attack == "attack2":
		power = THRUST_POWER
	for body in area.get_overlapping_bodies():
		if _swing_hits.has(body) or not body.is_in_group("enemies"):
			continue
		if body.has_method("take_damage"):
			_swing_hits[body] = true
			body.call("take_damage", power)


func _on_animation_finished() -> void:
	if _attack == "":
		return
	var finished := _attack
	# The heavy always erupts into its wildfire before anything else - the
	# ledger is NOT cleared, so the pair lands once per enemy between them.
	if finished == "heavy":
		_attack = "wildfire"
		_apply_animation("wildfire", true)
		return
	_attack = ""
	# Still holding when an attack ends (and nothing buffered) flows into the
	# charge stance; a tap has long since released by now.
	if _buffered == "" and finished != "wildfire" \
			and Input.is_action_pressed("attack"):
		_charging = true
		_charge = 0.0
		_apply_animation("charge", true)
		return
	if _buffered != "":
		_start_attack(_buffered)
		return
	# A late press can still chain off a swing; the thrust ends the chain.
	if finished == "attack":
		_combo_grace = COMBO_GRACE_SECONDS
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
	# So does whatever the player was mid-way through with the attack button.
	# Without this, a death during the charge stance respawns a player still
	# rooted in it - or, released during the fade, popping a wildfire at the
	# spawn - and a death mid-swing carries a live attack across the fade.
	_attack = ""
	_buffered = ""
	_charging = false
	_charge = 0.0
	_combo_grace = 0.0
	_swing_hits.clear()
	_sprite.speed_scale = 1.0
	_apply_animation("idle")
	_sprite.visible = true
	_sprite.modulate = Color.WHITE
	health_changed.emit(health, MAX_HEALTH)
