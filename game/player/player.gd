extends CharacterBody2D
## Top-down player. Moves in 8 directions but animates in 3 (down / up / side),
## because the sheet only draws a right-facing profile - left is that, flipped.

const SPEED := 90.0
const ACCELERATION := 900.0
## How much of walking speed the two light attacks keep. They used to root the
## body; a third lets a swing step in or drift back without letting the player
## dance out of a guard's finish, which the grace window and the interrupt
## tuning both assume. The stick also steers: facing follows it mid-attack and
## the hitbox re-parks (see _turn_attack). The charge stance and the heavy stay
## rooted - the heavy's ~1.9 rooted seconds are part of its damage maths.
const ATTACK_SLIDE := 0.35
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
## EVERY enemy inside the Spinbox circle. Exactly a regular's health on purpose:
## an AoE that does not KILL the basic enemy thins no crowd and so never repays
## the ~1.9 rooted seconds it costs - at 15 it was strictly the wrong button.
## At 24 it one-shots a guard and a wraith while its single-target rate
## (~15.6/s counting the entry swing) stays below the light combo's 21, so the
## combo is still right against one enemy and the heavy right against a crowd.
const HEAVY_POWER := 24
## How long the charge stance must be held before a release unleashes the
## heavy. The charge loop doubles speed as the ready cue.
const CHARGE_SECONDS := 1.0
## How many times health can hit zero before the run ends. The player node is
## built fresh by each new game scene, so a new run starts full again.
const MAX_LIVES := 3
## Grace period after a hit - set per difficulty mode from Difficulty at spawn.
## It meters ALL blows: hazards and enemies push damage with no timers of their
## own and this window is what turns that pressure into discrete hits. It is
## also the crowd dial, which is why difficulty owns it: a guard's attack cycle
## is 0.8s, so grace at 0.8 (EASY) means extra guards' strikes are swallowed and
## N enemies hit like one, while 0.5 (HARD) lets a crowd interleave.
var _grace_window := 0.8
## Floor on how far a slow may go. Below roughly this the player is not really
## playing any more, and no combination of sources should get there.
const MIN_SLOW_FACTOR := 0.2
## How a slowed character reads. Cold, and deliberately a tint rather than the
## blink the grace window owns, so being hurt and being slowed never look alike.
const SLOW_TINT := Color(0.6, 0.75, 1.0)

## How close the player has to get to a scripted destination before it counts
## as arrived. Six pixels rather than one: the escort's destination MOVES (it
## trails whoever is being followed), and a tighter ring makes the walk stutter
## between walking and idle every time the guide slows down.
const LEAD_STOP := 6.0

signal health_changed(health: int, max_health: int)
signal lives_changed(lives: int, max_lives: int)
signal died

## Preloaded by path rather than via `class_name`, like the rest of the project.
const Roster := preload("res://game/player/characters/roster.gd")
const PlayerAudio := preload("res://game/player/player_audio.gd")

## Attack animation -> the cue it opens with. The two lights are named for the
## MOVEMENT rather than for the animation because that is what they are: air,
## not impact. Nothing has been struck on the frame a swing starts, so `hit`
## belongs to `_strike()` and to the frame something is actually reached - the
## enemies' rule (game/enemies/CLAUDE.md, The noise) pointed the other way.
const ATTACK_SOUNDS := {
	"attack": "swing",
	"attack2": "swing2",
	"heavy": "heavy",
}

enum Facing { DOWN, UP, SIDE }

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _hitbox: Area2D = $Hitbox
@onready var _spinbox: Area2D = $Spinbox
## The noise this body makes, or null. Optional on exactly an enemy's terms: a
## cue with no `Audio` child, or with no file behind it, is silence with no
## branch anywhere - so a fresh checkout runs before anybody has imported a WAV.
@onready var _audio: PlayerAudio = get_node_or_null("Audio")

var health := MAX_HEALTH
var lives := MAX_LIVES
## The movement multiplier currently in force and how long is left of it. Public
## because they are a readout: the sprite tint reads them now and a HUD status
## icon would read the same pair.
var slow_factor := 1.0
var slow_seconds := 0.0

## Cutscene control. While the world has the wheel the stick and the attack
## button are ignored outright - not merely unread: an attack in progress is
## cancelled on the way in, so a conversation cannot start with a sword already
## swinging through it. Deliberately NOT `set_physics_process(false)`, which is
## what a door transition uses: a frozen body cannot walk, and being led on a
## tour is the one time the player moves without touching the keyboard.
var _scripted := false
## Where the world is currently walking the player to, or null to stand still.
## Re-set every frame by whoever is leading, so following a moving guide is the
## same mechanism as walking to a fixed mark.
var _lead = null
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
	# Read once at spawn, like every difficulty number: the mode can only change
	# at the main menu, and a new run builds a fresh player.
	_grace_window = Difficulty.grace_seconds()
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

	# Scripted movement short-circuits everything below: no stick, no attack,
	# no combo. The timers above still run, because a blow landed during a
	# conversation still has its grace window to spend.
	if _scripted:
		_scripted_step(delta)
		return

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
			# Faded rather than cut: an early release loses nothing (the
			# press's swing already happened), so it must not sound like
			# something broke. A release into the heavy is masked by the swing.
			_sfx_fade("charge", 0.08)
			if _charge >= CHARGE_SECONDS:
				_start_attack("heavy")
			else:
				_apply_animation("idle")
	elif _attack != "":
		if (_attack == "attack" or _attack == "attack2") and direction != Vector2.ZERO:
			# Light attacks steer and slide at a fraction of walking speed.
			_turn_attack(direction)
			velocity = velocity.move_toward(
				direction * SPEED * slow_factor * ATTACK_SLIDE, ACCELERATION * delta)
		else:
			# The heavy, its wildfire, and a light attack with no stick held
			# brake to a stop.
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


## The world takes the wheel. Any swing, thrust, charge or heavy in flight is
## dropped here rather than allowed to finish: a cutscene that begins on frame
## two of a combo would otherwise play out over the top of it, hitbox and all.
##
## Health, grace and slows are untouched - being talked at is not a safe room.
func take_control() -> void:
	_scripted = true
	_lead = null
	_attack = ""
	_buffered = ""
	_combo_grace = 0.0
	_charging = false
	_charge = 0.0
	_swing_hits.clear()
	_sprite.speed_scale = 1.0
	velocity = Vector2.ZERO
	_apply_animation("idle", true)
	# Cut, not faded: a hum trailing into the first line of a conversation is
	# the cutscene starting on top of the combat it just cancelled.
	_sfx_stop("charge")


func release_control() -> void:
	_scripted = false
	_lead = null


func scripted() -> bool:
	return _scripted


## Walk here, under the player's own legs and at the player's own speed. Only
## obeyed while the world has the wheel, so nothing can drag a player who is
## still playing. Call again to redirect - an escort re-calls it every frame
## with a point that trails the guide - and `null` to stand still.
func lead_to(point) -> void:
	_lead = point


## Turn to look at something without moving. Used at the start of a
## conversation, so the player is not delivering their half of it to a wall.
func face_towards(point: Vector2) -> void:
	var to_point := point - global_position
	if to_point == Vector2.ZERO:
		return
	_face(to_point)
	_apply_animation("idle")


## One frame of being led. The same walk the stick produces - same speed, same
## acceleration, same animation - with the direction coming from a destination
## instead of the keyboard, so being escorted looks exactly like walking.
func _scripted_step(delta: float) -> void:
	var direction := Vector2.ZERO
	if _lead != null:
		var to_lead: Vector2 = _lead - global_position
		if to_lead.length() > LEAD_STOP:
			direction = to_lead.normalized()
	if direction != Vector2.ZERO:
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


## Mid-attack the stick steers: facing follows it, the hitbox re-parks, and the
## sprite switches to the new facing's row of the SAME attack at the SAME frame
## and progress, so a swing that turns keeps its timing and its telegraph. The
## hit ledger is untouched - turning cannot land one swing twice on one enemy.
func _turn_attack(direction: Vector2) -> void:
	var before := _facing
	var before_left := _facing_left
	_face(direction)
	if _facing == before and _facing_left == before_left:
		return
	_hitbox.position = _hitbox_offset()
	var frame := _sprite.frame
	var progress := _sprite.frame_progress
	_apply_animation(_attack)
	_sprite.set_frame_and_progress(frame, progress)


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
		_hitbox.position = _hitbox_offset()
	_apply_animation(anim, true)
	_sfx(ATTACK_SOUNDS.get(anim, ""))


## The hitbox sits one step ahead of the body in whatever direction the attack
## faces, and stays live for the whole animation. Both light attacks share it:
## the second hit (attack2) is a rising slash on the spot - a launcher, not a
## thrust - whose arc covers the same reach as the swing's, and it no longer
## lunges, since the jump is its movement.
func _hitbox_offset() -> Vector2:
	match _facing:
		Facing.UP:
			return Vector2(0, -14)
		Facing.SIDE:
			return Vector2(-11 if _facing_left else 11, -4)
		_:
			return Vector2(0, 6)


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
	var landed := false
	for body in area.get_overlapping_bodies():
		if _swing_hits.has(body) or not body.is_in_group("enemies"):
			continue
		if body.has_method("take_damage"):
			_swing_hits[body] = true
			body.call("take_damage", power)
			landed = true
	# Once for the frame, not once per enemy: a heavy landing on four bodies is
	# one impact, and four copies of one clip started together is a click.
	if landed:
		_sfx("hit")


func _on_animation_finished() -> void:
	if _attack == "":
		return
	var finished := _attack
	# The heavy always erupts into its wildfire before anything else - the
	# ledger is NOT cleared, so the pair lands once per enemy between them.
	if finished == "heavy":
		_attack = "wildfire"
		_apply_animation("wildfire", true)
		_sfx("wildfire")
		return
	_attack = ""
	# Still holding when an attack ends (and nothing buffered) flows into the
	# charge stance; a tap has long since released by now.
	if _buffered == "" and finished != "wildfire" \
			and Input.is_action_pressed("attack"):
		_charging = true
		_charge = 0.0
		_apply_animation("charge", true)
		# A loop, because the stance is held for as long as the button is and
		# so has no length of its own. The READY cue stays on the eyes, where
		# it already was - the animation doubles speed at CHARGE_SECONDS.
		_sfx_loop("charge")
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
	_grace = _grace_window
	_lose_health(amount)
	# Metered for free by the window above, so a crowd cannot stack gasps. Only
	# on a blow that was SURVIVED: `_lose_health` plays `die` at zero, and a
	# gasp laid over the death breath in one frame is one muddy sound rather
	# than two clear ones.
	if health > 0:
		_sfx("hurt")


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
		# Here rather than in take_damage() so that a drain kills as audibly as
		# a blow does - `drain()` is otherwise deliberately silent, but a death
		# is not a drain tick, it is the end of the run.
		_sfx("die")
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
	_sfx_stop("charge")
	_sprite.speed_scale = 1.0
	_apply_animation("idle")
	_sprite.visible = true
	_sprite.modulate = Color.WHITE
	health_changed.emit(health, MAX_HEALTH)


## One sound, if the scene gave this body an `Audio` child and that child has
## one by that name. Every miss is legal and silent by design, which is what
## lets a cue be wired here before its WAV exists - and what makes a fresh
## checkout playable before an --import pass has ever been run.
##
## Deliberately the same four names `enemy_base` uses. They are not the same
## code (see player_audio.gd for why the player's node is not the enemies'),
## but somebody reading both should not have to learn two vocabularies for one
## idea. An empty id is a no-op, so ATTACK_SOUNDS can miss without a branch.
func _sfx(id: String) -> void:
	if _audio != null and id != "":
		_audio.play(id)


## The same deal for a sound that keeps going - the charge stance - and for the
## two ways of taking one back down. Faded where stopping is part of the move,
## cut where the move itself was cancelled.
func _sfx_loop(id: String) -> void:
	if _audio != null:
		_audio.loop(id)


func _sfx_fade(id: String, seconds: float) -> void:
	if _audio != null:
		_audio.fade_out(id, seconds)


func _sfx_stop(id: String) -> void:
	if _audio != null:
		_audio.stop(id)
