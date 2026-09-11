extends CharacterBody2D
class_name EnemyBase
## Base for every enemy type. An enemy stands guard until the player comes
## within sight, closes the ground to `stop_distance`, holds there facing them,
## and then attacks on a telegraph rather than simply by being in contact.
##
## ## The attack cycle
##
## CHASE -> WINDUP -> STRIKE -> RECOVER -> back round, and STAGGER hanging off
## WINDUP for an attack that got interrupted. The enemy only moves in CHASE;
## every other state roots it, which is what makes a swing something the player
## can see coming and step out of.
##
## **The blow lands on STRIKE, not on contact.** An enemy that is touching you is
## not hurting you - one that finished winding up is. That is what makes the
## telegraph mean anything, and it is how the wraith and the warden already
## worked; this brings the plain melee enemy in line with them rather than
## inventing a new idea.
##
## ## Interrupts, and the two rules that keep them from being a spam button
##
## Damage cancels a wind-up, which gives the player's sword a second job. Left
## unbounded that is a stun-lock - mashing would beat every enemy in the game,
## since a fresh wind-up can always be hit at its start. So:
##
## - **`commit_fraction`** - past that much of the wind-up the enemy is
##   committed. A late hit still damages it, but the blow lands anyway. The
##   interrupt becomes a timing decision instead of a check on button speed.
## - **`interrupt_cooldown`** - having been interrupted once, an enemy cannot be
##   interrupted again for a while. This is the load-bearing one: without it the
##   player just interrupts the restarted wind-up too, forever. With it, an
##   interrupt is a resource spent on the attack that most needs stopping.
##
## The player is deliberately NOT interruptible in return. Being staggered out of
## a combo by chip damage feels dreadful, and asymmetry in the player's favour is
## the right kind of unfair.
##
## ## Seams
##
## What a touch DOES is the seam between enemy types - the base deals damage on
## its strike, and a freezing, shoving or draining enemy overrides `_touch()`
## while inheriting everything else. An effect that sets its OWN rate takes the
## delta it is handed and presses the player's drain() instead, which is the
## entry point outside the grace window. `_attacks()` says whether a type uses
## the cycle above at all - the wraith and the warden do not.
##
## Three smaller seams travel with those, because an effect is rarely only
## damage: `_can_advance()` roots a type that is winding something up of its own,
## `_contact_state()` is what contact looks like, and `_resting_tint()` is how
## the enemy reads while it works.
##
## ## The noise
##
## Five cues, fired from the five moments the cycle above already has: `windup`
## as the telegraph starts, `hit` when a blow actually lands, `hurt` and
## `stagger` off the two ways a hit reads, and `die`. An enemy gets them by
## owning an `Audio` child with the files in it and NOTHING else - the same deal
## as the HUD bar a boss gets by standing in a group. An enemy with no `Audio`
## child, an id it was never given, and a fresh checkout whose WAVs have not
## been imported all land in the same null check in `_sfx` and play nothing, so
## the fight works before anybody has imported anything.
##
## **The stagger REPLACES the grunt**, which is the boss's rule inherited rather
## than re-decided (game/bosses/CLAUDE.md, The noise): the one thing the player
## needs off that hit is that the swing died, and two sounds on one frame is the
## fastest way to hear neither.
##
## **And `die` cannot be played the ordinary way.** It fires on the frame the
## body is freed, and a player parented to a freed node is freed with it - the
## sound would be cut before its first sample. `_sfx_detached` hands that one to
## the enemy's parent instead. Nothing else in the game has this problem, because
## a boss concedes rather than dying and is never freed at all.
##
## Stats are @exports so a level can retune the instance it places; the numbers
## below are the "regular" enemy the whole system is tuned around.

## The mechanism, shared with the bosses, who need it for exactly the same job:
## a boss IS an enemy (boss_base.gd extends this file), so its sounds live one
## level up from both of them by the placement rule in CLAUDE.md, the same way
## this script does.
const EnemyAudio := preload("res://game/enemies/enemy_audio.gd")

## And the things it SAYS, which arrived here by the same road on the same day
## its sounds did: a `Lines` child naming a file of them, one line at a time,
## a cooldown per cue, never the same line twice running, and the clip played
## positionally. A body with no `Lines` child says nothing, with no branch
## anywhere but `_say`.
const EnemyLines := preload("res://game/enemies/enemy_lines.gd")

## The one cue a plain enemy has, and it is unlike every cue a boss has.
##
## A boss's lines are ADDRESSED - he has seen you, he is swinging, he has lost
## - so each is pinned to a moment the fight makes. This one is pinned to
## nothing: it is what somebody says to themselves while they work, and the
## player is overhearing an office rather than being spoken to. There is no
## moment to fire it on, so it is polled.
const MUTTER_CUE := "mutter"
## How often the poll ASKS, which is not how often anything is said. The real
## pacing is the `Lines` child's own `cooldowns`, where every other line timing
## in the game already lives - asking often and being refused is free, and it
## keeps this file from growing a second set of dials that would then disagree
## with the first.
const MUTTER_POLL := 2.0

@export var max_health := 24
## Dealt by a completed strike, not by contact. Higher than it was when merely
## touching the player cost them health: a blow the player was shown coming and
## failed to answer should be worth answering, or eating it is cheaper than
## playing around it.
@export var contact_damage := 10
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

@export_group("Attack cycle")
## The telegraph. Long enough to read and step out of, short enough that an
## enemy standing next to you is a threat rather than a statue.
@export var windup_seconds := 0.45
## How much of the wind-up can still be interrupted. Past it the enemy is
## committed and the blow lands however hard it is hit.
@export_range(0.0, 1.0) var commit_fraction := 0.6
## Rooted after striking - the window the player is actually free in.
@export var recover_seconds := 0.35
## Rooted after being interrupted. Deliberately shorter than the player's own
## attack animation, so a stagger reads as a flinch rather than a free hit.
@export var stagger_seconds := 0.25
## After an interrupt, how long before this enemy can be interrupted again.
## Without this the whole mechanic collapses into mashing.
@export var interrupt_cooldown := 1.2

const HURT_FLASH_SECONDS := 0.15
const HURT_TINT := Color(1.0, 0.4, 0.4)
## Reads hotter the closer the swing is to landing, so a wind-up is legible even
## with the animation still playing behind it.
const WINDUP_TINT := Color(1.0, 0.72, 0.45)

enum Facing { DOWN, UP, SIDE }
## CHASE covers standing still as well - it is "not mid-attack", and the base's
## usual distance rules decide whether that means walking or holding station.
enum Phase { CHASE, WINDUP, RECOVER, STAGGER }

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _touch_area: Area2D = $Touch
@onready var _audio: EnemyAudio = get_node_or_null("Audio")
@onready var _lines: EnemyLines = get_node_or_null("Lines")

var health := 0
## True on every frame this enemy is in contact with the player. Settled before
## _contact_state() and _resting_tint() are asked, so an override can read it.
var touching_player := false

## Where in the attack cycle this enemy is. Public so a type that roots itself
## for its own reasons, or a test, can read it without guessing from animations.
var phase: Phase = Phase.CHASE

var _facing: Facing = Facing.DOWN
var _facing_left := false
var _flash := 0.0
## Time spent in the current phase, and the countdown on being interruptible.
var _phase_time := 0.0
var _interrupt_locked := 0.0
## Seconds until the next mutter is ASKED for. See `_ready` for why the first
## one is random.
var _mutter_in := 0.0


func _ready() -> void:
	health = max_health
	# Difficulty scales what the world DEALS, applied once at spawn. Health is
	# deliberately untouched: 24 / 17 / 36 are exact breakpoints on the player's
	# combo, and a multiplier would shred them on two of the three modes.
	contact_damage = roundi(contact_damage * Difficulty.damage_scale())
	# The first ask is scattered across a whole cooldown, and that is the one
	# line here that matters. Four of these spawn on the same frame with their
	# cooldowns all at zero, so a fixed first poll makes four people say four
	# different things simultaneously, once, and then settle into a rhythm -
	# which sounds like a bug and cannot be heard as an office.
	if _lines != null:
		_mutter_in = randf_range(0.0, maxf(_lines.cue_seconds, MUTTER_POLL))


func _physics_process(delta: float) -> void:
	_mutter(delta)
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
	if _interrupt_locked > 0.0:
		_interrupt_locked = maxf(_interrupt_locked - delta, 0.0)
	_phase_time += delta

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
			# close: an enemy rooted mid-swing should still turn to watch them.
			var direction := to_player / maxf(distance, 0.001)
			_face(direction)
			# Rooted by anything other than CHASE, so a wind-up cannot also be a
			# charge across the room.
			advancing = distance > stop_distance and phase == Phase.CHASE \
				and _can_advance()
			if advancing:
				velocity = direction * speed
	move_and_slide()

	touching_player = false
	for body in _touch_area.get_overlapping_bodies():
		if body.is_in_group("player"):
			touching_player = true
			_touch(body, delta)

	if _attacks():
		_advance_phase()

	_apply_animation(_animation_state(advancing))
	# Resolved last, so an effect that tints while it works has already seen this
	# frame's contact. Being hurt outranks everything; a swing about to land
	# outranks whatever a type wants to say the rest of the time.
	if _flash > 0.0:
		_sprite.modulate = HURT_TINT
	elif phase == Phase.WINDUP:
		_sprite.modulate = Color.WHITE.lerp(_windup_tint(), _windup_progress())
	else:
		_sprite.modulate = _resting_tint()


## 0..1 through the current wind-up; 0 when not winding up.
func _windup_progress() -> float:
	if phase != Phase.WINDUP or windup_seconds <= 0.0:
		return 0.0
	return clampf(_phase_time / windup_seconds, 0.0, 1.0)


func _enter(next: Phase) -> void:
	phase = next
	_phase_time = 0.0


## One step of CHASE -> WINDUP -> STRIKE -> RECOVER. STRIKE is a moment rather
## than a state: it happens on the frame the wind-up completes and hands
## straight over to RECOVER.
func _advance_phase() -> void:
	match phase:
		Phase.CHASE:
			# Reaching the player is what starts a swing, so an enemy that has
			# closed the ground commits to something rather than idling on you.
			if touching_player:
				# The telegraph, said out loud. A boss never reaches this line
				# - his override returns before `super()` on CHASE, because he
				# picks an attack first and names the sound after it - so the
				# two ways of announcing a wind-up do not stack.
				_sfx("windup")
				_enter(Phase.WINDUP)
		Phase.WINDUP:
			# A swing carries on into empty air - stepping back does not unwind
			# it, it just means the blow finds nothing. An effect that has to
			# HOLD the player, like the warden's area, says so and resets here.
			if _windup_needs_contact() and not touching_player:
				_enter(Phase.CHASE)
			elif _phase_time >= windup_seconds:
				_strike()
				_enter(Phase.RECOVER)
		Phase.RECOVER:
			if _phase_time >= recover_seconds:
				_enter(Phase.CHASE)
		Phase.STAGGER:
			if _phase_time >= stagger_seconds:
				_enter(Phase.CHASE)


## The blow, at the end of the telegraph - and only if the player is still
## standing there. Stepping out of the arc during the wind-up is the other half
## of the counterplay, the half that costs nothing but timing.
func _strike() -> void:
	var landed := false
	for body in _touch_area.get_overlapping_bodies():
		if body.is_in_group("player"):
			landed = true
			_touch_strike(body)
	# Only a blow that found somebody. A swing through empty air already said
	# everything it had to say on the wind-up, and an impact with nothing under
	# it teaches the player that the sound does not mean they were hit.
	#
	# Bosses pass through here without a word: theirs are named after the
	# attack (`chop_hit`), so `hit` is an id no boss owns and the call is one
	# more legal miss.
	if landed:
		_sfx("hit")


## What a completed strike does - the one thing melee enemy types differ in. The
## base deals damage and lets the player's grace window meter it against
## everything else hitting them; a freezing or shoving enemy overrides this.
func _touch_strike(player: Node2D) -> void:
	if player.has_method("take_damage"):
		player.call("take_damage", contact_damage)


## Whether this type uses the wind-up cycle at all. The wraith opts out: it
## drains by proximity, with no swing to telegraph and nothing to interrupt.
func _attacks() -> bool:
	return true


## Whether the wind-up demands unbroken contact. False for a swing, which lands
## on air if the player steps back; true for something that has to hold the
## player for the whole telegraph, where walking out is the counterplay.
func _windup_needs_contact() -> bool:
	return false


## How the enemy reads as its wind-up fills. Overridden by a type whose attack
## is not a swing, so the colour says which kind of trouble is coming.
func _windup_tint() -> Color:
	return WINDUP_TINT


## What the enemy is animated doing while it winds up. A type that never draws a
## weapon should not mime one.
func _windup_state() -> String:
	return "attack"


## Per-frame contact, which now does nothing by default: a melee enemy's damage
## comes from _touch_strike() at the end of its telegraph. Still here, and still
## handed `delta`, because a continuous effect with a rate of its own - the
## wraith's drain - is exactly what it is for.
func _touch(_player: Node2D, _delta: float) -> void:
	pass


func _animation_state(advancing: bool) -> String:
	match phase:
		Phase.WINDUP:
			return _windup_state()
		Phase.RECOVER, Phase.STAGGER:
			return "idle"
		_:
			# "walk" only while actually walking. An enemy that has arrived and
			# stopped is doing its contact state or simply standing there.
			return _contact_state() if touching_player \
				else ("walk" if advancing else "idle")


## Whether the enemy may close ground this frame. A type that roots itself -
## winding up an ability, recovering from one - returns false and holds where it
## stands, while still turning to face the player.
func _can_advance() -> bool:
	return true


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
		# Detached, because the next line frees the thing that would play it.
		_sfx_detached("die")
		queue_free()
		return
	if _interruptible():
		_interrupt_locked = interrupt_cooldown
		_enter(Phase.STAGGER)
		# Replaces the grunt rather than layering over it - see the header.
		_sfx("stagger")
	else:
		_sfx("hurt")


## Whether this hit cancels what the enemy is doing. Three ways it does not:
## the enemy is not mid-wind-up, it has been interrupted too recently, or it is
## already past the point of commitment - in which case the hit hurts but the
## swing still lands, and the player has simply been too slow.
func _interruptible() -> bool:
	return phase == Phase.WINDUP \
		and _interrupt_locked <= 0.0 \
		and _windup_progress() < commit_fraction


## What somebody says to themselves while they work. Polled rather than fired,
## because unlike every other line in this game it answers to nothing that
## happens - see MUTTER_CUE.
##
## It keeps going while the enemy is being hit, winding up and swinging, and
## that is deliberate on both counts: the mutter is not a reaction, and an
## office worker who stops complaining the moment a fight starts is an office
## worker who was only ever scenery. Death ends it by ending the enemy.
##
## Most asks are refused - `enemy_lines.say()` returns {} while the cue is
## cooling down or a line is still running - and being refused is the normal
## case, not a failure. An enemy with no `Lines` child never asks at all.
func _mutter(delta: float) -> void:
	if _lines == null:
		return
	_mutter_in -= delta
	if _mutter_in <= 0.0:
		_mutter_in = MUTTER_POLL
		_say(MUTTER_CUE)


## One line, if this body has any for that cue and a `Lines` child at all -
## `_sfx` below for the throat rather than the mouth, and every miss is legal
## for the same reasons. Returns whether it actually spoke, which is what lets
## a GRUNT stand down for a line: a grunt is a voice and so is a line, so
## playing both is one mouth making two sounds.
##
## The base only SPEAKS. A boss overrides this to also put the line on screen,
## because he is the one being listened to - an enemy muttering to itself is
## overheard, and a subtitle would turn eavesdropping into being addressed.
func _say(cue: String) -> bool:
	if _lines == null:
		return false
	return not _lines.say(cue).is_empty()


## One sound, if this enemy has one by that name and an `Audio` child at all.
## Every miss is legal: an enemy with no sounds yet, an id it was never given,
## and a checkout whose WAVs have not been imported all arrive here. Bosses use
## these four unchanged - they were written for one and moved up when the
## second needed them, which is the placement rule rather than a favour.
func _sfx(id: String) -> void:
	if _audio != null:
		_audio.play(id)


## The same deal for a sound that keeps going - the wraith's drain - and for
## taking one back down. Here rather than in each type so no type ever writes
## the null check above twice.
func _sfx_loop(id: String) -> void:
	if _audio != null:
		_audio.loop(id)


func _sfx_fade(id: String, seconds: float) -> void:
	if _audio != null:
		_audio.fade_out(id, seconds)


## A sound that has to outlive the thing making it. Only `die` needs this, and
## it needs it absolutely: `queue_free()` takes the `Audio` child and every
## player under it, so the ordinary path plays a death sound for zero frames.
## The level is handed a copy that buries itself.
func _sfx_detached(id: String) -> void:
	if _audio != null:
		_audio.play_detached(id, get_parent(), global_position)


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
