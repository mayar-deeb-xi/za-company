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
## Damage the arc - the combo's third and last hit - deals to everything the
## blade reaches, and what its lightning then deals to each body it jumps to.
## 5 + 7 + 12 is 24: one full cycle is exactly a guard and exactly the heavy,
## so every enemy HP in the game still dies on a whole hit (guard 3, wraith 3,
## warden 5, security 6). The jump is a SWING's worth so a body the bolt reached
## stays on the same 5 / 7 / 12 lattice as one the blade did - retune it and
## the breakpoints walk.
const ARC_POWER := 12
const ARC_JUMP_POWER := 5
## How far the lightning looks for its next body, from the one it just left,
## and how many times it may jump. World pixels; two jumps is three bodies, and
## it is the combo's whole answer to a crowd that does not cost the heavy's
## rooted seconds.
const ARC_JUMP_RANGE := 40.0
const ARC_JUMPS := 2
## Which light attack follows which: swing, rising slash, arc. The arc ends the
## chain, so the press after it is a fresh swing - see _on_animation_finished.
const LIGHT_NEXT := {"attack": "attack2", "attack2": "attack3", "attack3": "attack"}
## After a swing or a rising slash ends, a press within this window still
## chains the next hit, so deliberate timing combos as reliably as mashing does.
const COMBO_GRACE_SECONDS := 0.2
## Damage the heavy attack - the charged spin plus its wildfire - deals to
## EVERY enemy inside the Spinbox circle. Exactly a regular's health on purpose:
## an AoE that does not KILL the basic enemy thins no crowd and so never repays
## the ~1.9 rooted seconds it costs - at 15 it was strictly the wrong button.
## At 24 it one-shots a guard and a wraith while its single-target rate
## (~15.6/s counting the entry swing) stays below the light combo's 21, so the
## combo is still right against one enemy and the heavy right against a crowd.
const HEAVY_POWER := 24
## How long the attack button must be HELD before the heavy goes off - counted
## from the press, not from the swing's end, and it fires itself the moment it
## lands rather than waiting for a release.
##
## Both halves of that sentence are fixes for the same complaint: the hold was
## hard to do. It was 1.0s that only STARTED when the press's swing finished,
## so the real cost was 1.3s of standing in a room with four enemies in it,
## and it then asked for a release timed against a cue (the charge animation
## doubling speed) that nobody watching the enemies could see. Releasing a
## fraction early threw the whole hold away with no sign it had been close.
##
## So the swing is now INSIDE the charge instead of a tax before it, the total
## is 0.75 rather than 1.0, and the release is gone: hold, and it happens. What
## a player has to do is hold the button down, which is the one input nobody
## can get wrong. The cue moved off the eyes and onto the floor - see
## game/player/charge_ring.gd.
##
## The number is bounded by the same arithmetic the heavy has always been
## bounded by, and it still holds. Press to wildfire is now 0.75 + 0.29 + 0.29
## = 1.32s, so the heavy's single-target rate with its entry swing is
## (5 + 24) / 1.32 = 21.9/s against the light combo's (5 + 7 + 12) / 0.86 =
## 28/s. The combo stays the right answer to one enemy and the heavy to a
## crowd, which is the invariant - not the 1.0 itself.
const CHARGE_SECONDS := 0.75
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

## Ceiling on a single shove, in pixels per second. Below the walking speed of
## 90 on purpose: a push has to be something you feel and then walk out of, not
## something that takes the character away from you. It is also the guarantee
## that a shove can never post anybody through a wall - it is applied through
## `move_and_collide()`, and at this speed one physics frame moves about 1.2 px,
## nowhere near a 16 px tile.
const MAX_SHOVE := 70.0
## How long a shove takes to decay away, ramping linearly to nothing. The two
## numbers together are the whole feel: half a second off a 70 ceiling is about
## 17 px, which is a tile - far enough to read as being moved, near enough that
## a push you are still fighting a second later never happens.
const SHOVE_SECONDS := 0.5

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
const Arc := preload("res://game/player/arc.gd")
const ChargeRing := preload("res://game/player/charge_ring.gd")

## Attack animation -> the cue it opens with. The two lights are named for the
## MOVEMENT rather than for the animation because that is what they are: air,
## not impact. Nothing has been struck on the frame a swing starts, so `hit`
## belongs to `_strike()` and to the frame something is actually reached - the
## enemies' rule (game/enemies/CLAUDE.md, The noise) pointed the other way.
const ATTACK_SOUNDS := {
	"attack": "swing",
	"attack2": "swing2",
	# The arc opens on the swing's own air until it has a cue of its own: a
	# `swing3` entry in tools/sfx/player.py, its stream in player.tscn, and
	# this line. Reusing a real cue rather than naming a missing one, because a
	# body that declares a cue with no file behind it is what test_player_sfx
	# exists to catch.
	"attack3": "swing",
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

## The shove the player is currently carrying, and how long is left of it.
## Private where the slow pair is public because nothing reads this but the
## movement below - a push has no tint and no HUD row: you find out about it by
## ending up somewhere else.
var _shove := Vector2.ZERO
var _shove_seconds := 0.0

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
## Which light attack a press inside the grace window chains into - the next
## link after whichever one just ended. Only read while _combo_grace > 0.
var _combo_next := ""
## The colour this character's weapon effects are drawn in, off the roster
## recipe at spawn: the bolt the arc throws between enemies has to match the
## sparks baked into the sheet, and Roster.spark_hex is the one rule both read.
var _spark := Color(Roster.SPARK_BALD)
## How long the attack button has been down, counted from the PRESS. It needs
## no reset of its own: a press can only follow a release, and a release zeroes
## it, so the frame `just_pressed` fires is already a fresh count. This is what
## makes the opening swing part of the charge rather than a tax before it.
var _hold := 0.0
## Charge stance: entered by still holding the button when an attack ends, and
## rooted while it lasts. It starts at whatever `_hold` has already reached, so
## the swing counts; at CHARGE_SECONDS the heavy fires ITSELF. Letting go before
## then just returns to idle - the press's swing already happened, so an early
## release loses nothing.
var _charging := false
var _charge := 0.0
## The ring drawn at the feet while charging, or null. Owned here rather than
## placed in player.tscn because it exists only for the length of a stance.
var _ring: Node2D = null
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
	var entry := Roster.find(id)
	if entry.has("recipe"):
		_spark = Color(Roster.spark_hex(entry["recipe"]))


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

	# A shove decays on its own clock, up here with the other things the player
	# is CARRYING rather than down in the movement - so it runs out at the same
	# rate whether the player is walking out of it, swinging, or stood still.
	if _shove_seconds > 0.0:
		_shove_seconds = maxf(_shove_seconds - delta, 0.0)
		_shove = _shove.move_toward(Vector2.ZERO,
			MAX_SHOVE / SHOVE_SECONDS * delta)

	# Scripted movement short-circuits everything below: no stick, no attack,
	# no combo. The timers above still run, because a blow landed during a
	# conversation still has its grace window to spend.
	if _scripted:
		_scripted_step(delta)
		return

	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if Input.is_action_pressed("attack"):
		_hold += delta
	else:
		_hold = 0.0

	if not _charging and Input.is_action_just_pressed("attack"):
		if _attack == "":
			_start_attack(_combo_next if _combo_grace > 0.0 else "attack")
		else:
			# Mid-attack queues the next link of the chain; mid-heavy queues a
			# fresh swing.
			_buffered = LIGHT_NEXT.get(_attack, "attack")

	if _charging:
		_charge += delta
		var filled := clampf(_charge / CHARGE_SECONDS, 0.0, 1.0)
		# Progress, twice, because a fight gives the player nowhere to look: the
		# ring on the floor fills, and the stance winds up towards double speed
		# as it goes. The old cue SNAPPED to double at the ready point and said
		# nothing before it, which is a cue that only helps somebody already
		# counting.
		_sprite.speed_scale = lerpf(1.0, 2.0, filled)
		if _ring != null:
			_ring.progress = filled
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		if _charge >= CHARGE_SECONDS:
			# It fires ITSELF. There is no release to time and no way to hold
			# past it into nothing - the stance ends the only way it can end
			# well, and the ring flares on the frame it does.
			_end_charge(true)
			_start_attack("heavy")
		elif not Input.is_action_pressed("attack"):
			# Let go early and nothing happened, so nothing flashes: the ring
			# is dropped rather than flared. The hum is faded rather than cut,
			# because an early release loses nothing (the press's swing already
			# happened) and so must not sound like something broke.
			_end_charge(false)
			_apply_animation("idle")
	elif _attack != "":
		if LIGHT_NEXT.has(_attack) and direction != Vector2.ZERO:
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

	# The shove rides ON TOP of whatever the player was doing rather than
	# replacing it: a stumble you can still walk against is a stumble, and one
	# that takes the stick away for half a second is a cutscene. Applied after
	# the ordinary move and to every branch above alike - walking, sliding
	# through a light attack, rooted in the heavy - because being rooted is not
	# being bolted down.
	#
	# It is a SEPARATE displacement and deliberately never added to `velocity`.
	# Velocity is carried between frames and only bled off at FRICTION, so
	# adding the push to it every frame compounds: a 70 px/s shove held for a
	# third of a second reaches several hundred, then coasts the player across
	# the room long after the shove itself is over. `move_and_collide` keeps the
	# one guarantee that matters - the room's own walls stop it - without
	# touching the state the stick owns.
	if _shove_seconds > 0.0:
		move_and_collide(_shove * delta)


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
	_hold = 0.0
	# Dropped, never fired: a conversation must not open with a heavy going off
	# in it, however full the charge was on the frame the world took over.
	_end_charge(false)
	_swing_hits.clear()
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
	elif _attack == "attack3":
		power = ARC_POWER
	var struck: Array[Node2D] = []
	for body in area.get_overlapping_bodies():
		if _swing_hits.has(body) or not body.is_in_group("enemies"):
			continue
		if body.has_method("take_damage"):
			_swing_hits[body] = true
			body.call("take_damage", power)
			struck.append(body)
	if struck.is_empty():
		return
	if _attack == "attack3":
		_arc(struck)
	# Once for the frame, not once per enemy: a heavy landing on four bodies is
	# one impact, and four copies of one clip started together is a click.
	_sfx("hit")


## The arc's lightning. From each body the blade reached it jumps to the
## nearest enemy within ARC_JUMP_RANGE that nothing in this attack has touched
## yet, and once more from there, ARC_JUMPS times. The ledger is the same
## `_swing_hits`, which buys two things at once: the bolt can never double back
## onto the body it left, and the hitbox cannot land a second 12 on a body the
## bolt already reached for 5 if that body is standing in it on a later frame.
## A conceded boss is skipped rather than jumped to - he is in the group and
## takes nothing, and a jump spent on him is a jump the crowd did not get.
##
## The bolt is drawn by game/player/arc.gd in this character's spark colour,
## the way a boss draws his effects live rather than off a sheet: a line
## between two bodies has no fixed shape a sheet could hold.
func _arc(struck: Array[Node2D]) -> void:
	var chains: Array[PackedVector2Array] = []
	for primary in struck:
		var chain := PackedVector2Array([_hitbox.global_position, _chest(primary)])
		var from := primary
		for _jump in ARC_JUMPS:
			var next := _nearest_enemy(from.global_position)
			if next == null:
				break
			_swing_hits[next] = true
			next.call("take_damage", ARC_JUMP_POWER)
			chain.append(_chest(next))
			from = next
		chains.append(chain)
	var bolt := Arc.new()
	bolt.setup(chains, _spark)
	get_parent().add_child(bolt)


## The nearest enemy the arc may still jump to, or null. Group + method, never
## type, like everything else here that reaches across to the enemies.
func _nearest_enemy(at: Vector2) -> Node2D:
	var best: Node2D = null
	var best_distance := ARC_JUMP_RANGE
	for node in get_tree().get_nodes_in_group("enemies"):
		if _swing_hits.has(node) or not node.has_method("take_damage"):
			continue
		if node.get("has_conceded") == true:
			continue
		var distance: float = (node as Node2D).global_position.distance_to(at)
		if distance <= best_distance:
			best_distance = distance
			best = node
	return best


## Where a bolt lands on a body: chest height above the feet the position marks.
func _chest(body: Node2D) -> Vector2:
	return body.global_position + Vector2(0, -10)


## Leaves the charge stance, one way or the other. `fired` flares the ring and
## hands it its own death; anything else drops it on the spot, because a ring
## that flashes on a cancelled charge tells the player something happened when
## nothing did. Every exit from the stance goes through here - the auto-fire,
## an early release, a conversation taking the wheel and a death - so the ring
## can never outlive the stance that built it.
func _end_charge(fired: bool) -> void:
	_charging = false
	_charge = 0.0
	_sprite.speed_scale = 1.0
	if _ring != null:
		if fired:
			_ring.fire()
		else:
			_ring.queue_free()
		_ring = null
	# Faded either way: an early release must not sound like something broke,
	# and a release into the heavy is masked by the heavy's own swing.
	_sfx_fade("charge", 0.08)


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
		# NOT zero: the button has been down since before this attack started,
		# and that time is part of the charge. This one line is what stops the
		# heavy charging the player twice for the same swing.
		_charge = _hold
		_apply_animation("charge", true)
		_ring = ChargeRing.new()
		_ring.setup(_spark)
		add_child(_ring)
		# Still a loop rather than a one-shot. The stance now has an end, but
		# not a LENGTH: it runs for CHARGE_SECONDS minus however much of the
		# swing the player had already held through, which is different every
		# time, and an early release can cut it anywhere.
		_sfx_loop("charge")
		return
	if _buffered != "":
		_start_attack(_buffered)
		return
	# A late press can still chain off a swing or a rising slash; the arc ends
	# the chain, so the press after it is a fresh swing rather than a fourth
	# hit - 5 + 7 + 12 is the whole cycle, and it is exactly one guard.
	if finished == "attack" or finished == "attack2":
		_combo_grace = COMBO_GRACE_SECONDS
		_combo_next = LIGHT_NEXT[finished]
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


## A FOURTH thing, and the first one that does not touch health at all: being
## moved. The hub's floor scrubbers are heavy machines that bump into people,
## and what a bump costs is not blood, it is your position.
##
## It is shaped like apply_slow() rather than like take_damage(), and the shape
## is the whole of what makes it safe to add. A shove is something the player
## CARRIES for a moment and which expires on its own, so it sits outside the
## grace window in both directions - it is not a blow, so a torch clip must not
## swallow it, and being pushed must not buy immunity from the guard winding up
## behind you. Where a scrubber also wants to hurt, it calls take_damage() too,
## and the two meter themselves independently, which is correct: the damage is
## a blow and the push is not.
##
## Like a slow, overlapping shoves REFRESH rather than compound - the strongest
## push wins and the clock resets. Two machines catching a player between them
## must not add up to a launch across the room, and, more to the point, must
## never be able to post somebody through a wall: the impulse is fed through
## `move_and_slide()` with everything else, so the room's own collision is what
## stops it, and a velocity big enough to tunnel a 16px wall in one frame is the
## one way that guarantee could be lost.
func shove(direction: Vector2, force: float) -> void:
	if health <= 0 or direction == Vector2.ZERO:
		return
	var push := direction.normalized() * minf(force, MAX_SHOVE)
	if _shove_seconds <= 0.0 or push.length() > _shove.length():
		_shove = push
	_shove_seconds = SHOVE_SECONDS


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
	_hold = 0.0
	_end_charge(false)
	_combo_grace = 0.0
	_swing_hits.clear()
	_sfx_stop("charge")
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
