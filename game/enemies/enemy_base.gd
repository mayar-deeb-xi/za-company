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
## ## The leash
##
## `sight_radius` is how an enemy NOTICES the player and nothing else, which is
## the half of this that must not move: every authored position in
## tools/biomes/ is placed so that no sight radius reaches the door lane, so
## entering the circle stays the only way to be seen and the straight walk
## between the doors stays crossable. Widening it would break every floor at
## once.
##
## What used to be wrong was everything after. The chase was gated on the
## player being inside that circle THIS FRAME, so an enemy halted mid-stride
## the moment they stepped one pixel back over it - and at 90 against 45-55 the
## player owns that pixel whenever they want it. It read as an enemy that did
## not care, and it left the body standing wherever it gave up, so kiting one
## off its mark deformed the room permanently.
##
## Two numbers fix it, and neither touches detection:
##
## - **`patience_seconds`** - having seen the player, it keeps coming for that
##   long after losing sight. Escaping becomes a distance you have to make
##   rather than a line you step over.
## - **`leash_factor`** - it will not follow further than that multiple of its
##   sight from its POST, the spot it was placed on. Measured from the post and
##   never from where it currently stands, or it is not a leash at all: a bound
##   on the distance to the PLAYER travels with the enemy and so permits a
##   chase across the whole building.
##
## Then it walks back and stands where it was placed, because a room is an
## ARRANGEMENT and one that can be pulled apart once is a room whose shape only
## mattered on the first visit.
##
## **A body with no post has no leash**, which is `unleash()` and is exactly the
## reinforcements: CLAUDE.md already says they are the only enemies in the game
## with no authored position, and the leash is anchored to authored positions.
## One that walked in through a door came to find you and has nothing to defend.
## Bosses opt out of the whole thing through `_leashes()` - an arena holds one
## body and no arrangement, and a boss's own scripts read `sight_radius`
## directly for his dash, his taunt and his attack gates.
##
## ## Getting round the furniture
##
## Steering is one line - walk at the player - and that is enough until
## something solid is between the two. There is no pathfinding in this game and
## deliberately still is none: `move_and_slide` slides a blocked body along
## whatever it hit, which handles a glancing approach on its own.
##
## What it does NOT handle is the approach that ends square-on, and that is not
## the rare case but the ATTRACTOR. As a body slides it comes to face the
## player more and more directly, the sideways part of "walk at the player"
## decays towards zero, and it parks perpendicular to the obstacle with the
## player a few tiles beyond it - hunting, awake, and permanently unable to
## reach anybody. One desk does it. The attack cycle is gated on
## `touching_player`, so a body that cannot arrive never swings: a movement
## failure reads as an enemy that does not care.
##
## The fix is to keep sliding past the point where sliding stops paying:
##
## - **`BLOCKED_SECONDS`** - having asked for a frame's worth of ground and got
##   less than half of it for that long, something is in the way.
## - It then commits to ONE side, regardless of where the player has got to.
##   The commitment is the whole trick, because re-aiming every frame is
##   precisely what parks it. Which side is the way it was already sliding.
## - **The step ends when the way is OPEN**, which is one ray from here to the
##   target - not on a clock. A clock was tried first and is the version that
##   looks right and is not: the step has to be long enough to clear the widest
##   thing in the room, which makes it far too long for a chair, and a body
##   that walks a full second sideways past a pot plant reads worse than the
##   bug. The ray also gets the CLUTTER rule for free, because it is cast on
##   this body's own mask - a chair the enemy walks through is not a chair the
##   enemy walks around. `SIDESTEP_MIN` and `SIDESTEP_MAX` are only the floor
##   and ceiling on that: the floor so a step cannot end on the frame it began,
##   the ceiling so one can fail.
## - **`SIDESTEP_LIMIT`** - a step that runs to the ceiling without the way
##   opening was the wrong side, and the next one goes the other way round.
##   After that many it stops trying, because a heuristic that can be wrong has
##   to be able to lose. It gives up the hunt for `GIVE_UP_SECONDS` and walks
##   back to its post, so the worst case is a body standing on its mark rather
##   than one grinding into a corner for the rest of the run.
##
## **Only a body with a POST gives up**, which is the one line deciding who
## that last part applies to, and it falls out of what a post means rather than
## being a list of exceptions. A boss has none - his arena is the fight, and a
## boss who stopped hunting halfway through it would be a bug rather than a
## recovery. A reinforcement has none either: it came through a door to find
## the player and has nowhere to walk back to, so giving up would buy it
## nothing but standing still somewhere arbitrary.
##
## The walk home is steered the same way and has to be: a body that can be
## jammed on the way back is a body that can be parked off its mark for the
## rest of the run, which is the one thing the leash exists to prevent.
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

@export_group("The leash")
## How long it keeps coming after losing sight of the player. The escape, in
## seconds rather than in one pixel across the edge of the sight radius.
@export var patience_seconds := 2.5
## How far past its own sight it will follow, as a multiple of `sight_radius`
## and measured from its POST - so a guard owns 160 px around where it was
## placed, a wraith 240 and a warden 260. Under 1.0 is a body that will not
## leave the circle it watches.
@export var leash_factor := 2.0

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

## How close to the post counts as home. Without it a body jitters forever on
## the last half pixel, which is the same reason game/npcs/npc_base.gd has one.
const HOME_SLACK := 2.0

## Getting round the furniture - see the header. How long it has to be making
## no real ground before it accepts that something is in the way. Short, but
## not one frame: move_and_slide gives a little back to depenetration on
## perfectly ordinary frames, and grinding against the player is not an
## obstacle to be walked around.
const BLOCKED_SECONDS := 0.12
## Where the ray is cast from and to. Every body in this game - the player, all
## six enemies - carries its collision circle 4 px above the position it stands
## on, and a prop's box sits directly on top of its own, so a ray along the
## ground line grazes the bottom edge of everything it should be hitting.
const EYE := Vector2(0, -4.0)
## The floor and ceiling on one side-step, which normally ends on neither: the
## ray decides. The floor stops a step ending on the frame it started, which a
## body wedged on something that is NOT between it and the player would
## otherwise do sixty times a second. The ceiling is a little over what it
## takes to clear the widest prop in the catalogue from its middle - 92 px, so
## 46 of them at 45-55 px/s - because a step that has not worked by then is not
## going to.
const SIDESTEP_MIN := 0.2
const SIDESTEP_MAX := 1.5
## How many fruitless steps before it stops trying. Three, because the search
## alternates: one side, then the other, then the first again from wherever the
## other two left it standing.
const SIDESTEP_LIMIT := 3
## And how long it then leaves the player alone. Long enough to actually get
## home, so a give-up ends with the room back in its shape rather than with a
## body re-acquiring halfway there and jamming on the same corner again.
const GIVE_UP_SECONDS := 3.0

const HURT_FLASH_SECONDS := 0.15
const HURT_TINT := Color(1.0, 0.4, 0.4)
## Reads hotter the closer the swing is to landing, so a wind-up is legible even
## with the animation still playing behind it.
const WINDUP_TINT := Color(1.0, 0.72, 0.45)

enum Facing { DOWN, UP, SIDE }
## CHASE covers standing still and the walk back to the post as well - it is
## "not mid-attack", and the base's usual distance rules decide whether that
## means closing on the player, going home or holding station.
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
## True while this enemy is coming for the player - in sight, or inside the
## patience window after losing them. Public for the same reason `phase` is.
var hunting := false
## The spot it was placed on, which is what the leash is measured from and
## where it goes back to. `Vector2.INF` until the first physics frame has taken
## it, and again forever once `unleash()` says this body was never part of an
## arrangement.
var post := Vector2.INF

var _facing: Facing = Facing.DOWN
var _facing_left := false
var _flash := 0.0
## Time spent in the current phase, and the countdown on being interruptible.
var _phase_time := 0.0
var _interrupt_locked := 0.0
## Seconds of hunting left after losing sight, and whether this body has been
## told it has no post at all.
var _patience := 0.0
var _roaming := false
## Seconds until the next mutter is ASKED for. See `_ready` for why the first
## one is random.
var _mutter_in := 0.0
## Getting round the furniture: how long it has been making no ground, how much
## of the current side-step is left and which way it goes, how many have run
## out in a row, and how long it has sworn off hunting. `_slid` is the
## direction it last actually MOVED in, which is what picks the side -
## deliberately not the direction it asked for, which is the one that is
## useless here by definition.
var _blocked := 0.0
var _sidestep := 0.0
var _sidestep_dir := Vector2.ZERO
var _failed := 0
var _gave_up := 0.0
var _slid := Vector2.ZERO


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
	if _gave_up > 0.0:
		_gave_up = maxf(_gave_up - delta, 0.0)
	_phase_time += delta

	# Taken on the first frame rather than in _ready, because a reinforcement is
	# positioned by whoever spawned it one line AFTER add_child - so _ready
	# would pin the post to wherever the scene file happened to sit.
	if post == Vector2.INF and not _roaming and _leashes():
		post = global_position

	# Group + method rather than type, like hazards and pickups: nothing here
	# names the player's script.
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var advancing := false
	velocity = Vector2.ZERO
	if _hunt(player, delta):
		var to_player := player.global_position - global_position
		var distance := to_player.length()
		# Keep facing the player whether or not there is still ground to
		# close: an enemy rooted mid-swing should still turn to watch them.
		var direction := to_player / maxf(distance, 0.001)
		_face(direction)
		# Rooted by anything other than CHASE, so a wind-up cannot also be a
		# charge across the room - and bounded by the leash, which is the one
		# reason an enemy that CAN see the player still holds where it stands.
		advancing = distance > stop_distance and phase == Phase.CHASE \
			and _can_advance() and not _leashed()
		if advancing:
			var heading := _steer(player.global_position, delta)
			# Facing where it WALKS, while it walks. The line above stands for
			# every other frame, the rooted ones included - but a body edging
			# round a desk that is still staring at you is moonwalking.
			_face(heading)
			velocity = heading * speed
	elif phase == Phase.CHASE and _can_advance():
		# Nothing to hunt, so back to the post - if it has one and is off it.
		advancing = _walk_home(delta)
	var was := global_position
	move_and_slide()
	_measure(was, advancing, delta)

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


## Whether this enemy is coming for the player this frame, and the whole of when
## it gives up. See the header: detection is unchanged, and everything after it
## is what the leash is.
##
## It chases the player's CURRENT position through the patience window rather
## than their last known one, which is the small lie a game of this kind tells
## - two and a half seconds of it is 137 px for a guard, and the alternative is
## an enemy that walks confidently at the spot you used to be standing in.
func _hunt(player: Node2D, delta: float) -> bool:
	if player == null:
		hunting = false
		return false
	# Having tried to get round whatever is in the way and failed at it, this
	# body is not looking at the player at all for a while - see the header.
	if _gave_up > 0.0:
		hunting = false
		return false
	if global_position.distance_to(player.global_position) <= sight_radius:
		hunting = true
		_patience = patience_seconds
		return true
	# Out of sight. A body that never had a leash also never had the patience
	# that comes with one, so it stops here exactly as it always did.
	if not hunting or not _leashes():
		hunting = false
		return false
	_patience -= delta
	hunting = _patience > 0.0
	return hunting


## One frame of steering: straight at the target, unless straight at the target
## has stopped working. See the header - the commitment is the whole of it, and
## everything here is in service of holding one side long enough to get past
## the end of whatever is in the way.
func _steer(target: Vector2, delta: float) -> Vector2:
	var direction := (target - global_position).normalized()
	if _sidestep > 0.0:
		_sidestep -= delta
		if _sidestep <= 0.0:
			# Held one side for as long as it is worth holding one and the way
			# never opened, so that was the wrong side. The next one is the
			# other, and _around() reads `_failed` to know it.
			_failed += 1
			# Giving up is only for a body with somewhere to go back to, and
			# only while hunting. The walk home falls through and keeps
			# alternating, which is right: a body that cannot reach its own
			# mark has no third option to take.
			if _failed >= SIDESTEP_LIMIT and hunting and post != Vector2.INF:
				_give_up()
			return direction
		if SIDESTEP_MAX - _sidestep >= SIDESTEP_MIN and not _obstructed(target):
			# Round it. Straight on from here.
			_sidestep = 0.0
			_failed = 0
			return direction
		return _sidestep_dir
	if _blocked < BLOCKED_SECONDS:
		return direction
	_blocked = 0.0
	_sidestep = SIDESTEP_MAX
	_sidestep_dir = _around(direction)
	return _sidestep_dir


## Whether anything solid stands between this body and where it is going. One
## ray, cast on this body's OWN collision mask, which is what makes the clutter
## layer come out right for free: a chair an enemy walks through is not a chair
## it needs to walk around, and nobody had to say so twice.
##
## The player is not an obstruction, obviously - they are the target - and the
## ray stops on them rather than passing through, so reaching them at all is
## the answer.
func _obstructed(target: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
			global_position + EYE, target + EYE, collision_mask, [get_rid()])
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider := hit.get("collider") as Node
	return collider == null or not collider.is_in_group("player")


## Which way round. The way it was already sliding, because that is the way
## round the obstacle it had already started taking - and `_slid` is the
## movement that actually happened rather than the one that was asked for,
## which at the moment this is called is pointing squarely into the wall.
##
## A body that walked dead-on into something from a standstill has no slide to
## read, and the dot falls to zero. Both sides are genuinely equal there - this
## knows the obstacle is in the way and nothing whatever about its shape - so
## it takes the same one every time and finds out. Deterministic on purpose:
## two bodies stuck on one desk should peel off the same way rather than
## mirroring each other, and a coin flip would make the test of this a flake.
func _around(direction: Vector2) -> Vector2:
	var tangent := Vector2(-direction.y, direction.x)
	var pick := tangent if tangent.dot(_slid) >= 0.0 else -tangent
	# A step that bought nothing is not repeated: the next one goes the other
	# way round, and that alternation is the whole of the search.
	return -pick if _failed % 2 == 1 else pick


## What the last move was actually worth, measured after the fact because
## `move_and_slide` is the only thing that knows. Two readings come out of it:
## the direction that survived the slide, which picks the side to go round, and
## whether the ground asked for was ground got.
func _measure(was: Vector2, advancing: bool, delta: float) -> void:
	var moved := was.distance_to(global_position)
	if moved > 0.1:
		_slid = (global_position - was) / moved
	if not advancing:
		_blocked = 0.0
		return
	# Half a frame's worth rather than any shortfall at all: depenetration
	# takes a little back on ordinary frames, and a body that is merely walking
	# uphill against another body is not stuck behind furniture.
	if moved < speed * delta * 0.5:
		_blocked += delta
	else:
		_blocked = 0.0


## Stops trying. Not a state of its own - it clears the hunt and holds the
## player out of sight for a few seconds, which drops this body into the walk
## home it would take if the player had simply left the room.
func _give_up() -> void:
	_gave_up = GIVE_UP_SECONDS
	_sidestep = 0.0
	_blocked = 0.0
	_failed = 0
	hunting = false
	_patience = 0.0


## Whether the leash is out of slack. An enemy this far from its post holds
## where it stands and keeps watching, rather than being walked across the room
## by a player who has worked out that being followed is free.
func _leashed() -> bool:
	return post != Vector2.INF \
		and post.distance_to(global_position) >= sight_radius * leash_factor


## One frame of the walk back. Returns whether it is actually walking, which is
## what the animation reads - so a body already home stands there rather than
## miming a step over the last half pixel.
func _walk_home(delta: float) -> bool:
	if post == Vector2.INF:
		return false
	if post.distance_to(global_position) <= HOME_SLACK:
		return false
	# Steered exactly like the chase, and for a sharper reason - see the
	# header. Nothing gives up on going home: there is nowhere further back to
	# go, and `hunting` is false down this branch, which is what says so.
	var heading := _steer(post, delta)
	_face(heading)
	velocity = heading * speed
	return true


## Whether this body keeps a post at all: the patience, the leash and the walk
## home. False for a boss - see the header - and for anything else whose
## position was never authored, which says so through `unleash()` instead.
func _leashes() -> bool:
	return true


## Said to a body that was never part of an arrangement: it came through a door
## to find the player, so it has nothing to defend and nowhere to go back to.
## Called by game/levels/reinforcements.gd on every arrival.
func unleash() -> void:
	_roaming = true
	post = Vector2.INF


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
