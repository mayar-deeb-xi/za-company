extends "res://game/enemies/enemy_base.gd"
## Base for every boss. A boss IS an enemy - it runs enemy_base's
## CHASE -> WINDUP -> STRIKE -> RECOVER cycle, so the interrupt rules
## (`commit_fraction`, `interrupt_cooldown`) hold for it unchanged - with three
## things a plain enemy never needed:
##
## - **More than one attack.** Reaching the player asks `_pick_attack()` which
##   one, and `_begin_attack()` loads that attack's wind-up, recover and damage
##   into the base's own dials before entering WINDUP. The cycle itself is
##   untouched: one attack at a time, telegraph first, blow at the end.
## - **The animation IS the telegraph.** An attack's frames run from the first
##   wind-up frame to the last recover frame with their own timing baked into
##   the SpriteFrames, so the base's `windup_seconds` and `recover_seconds` for
##   that attack are derived from the same frame list. The sword can read the
##   swing off the picture.
## - **Bosses concede instead of dying.** At zero health a boss stops fighting,
##   leaves the `enemies` group, plays its concede animation, and says so with
##   `conceded`, which is what a boss floor's locked door is waiting for. It is
##   never `queue_free`d: it is still standing in the room when you leave.
##
## Bosses face left or right only. Every boss sheet draws one profile - four
## attacks in three directions is twelve rows of art for a fight that reads
## fine sideways - so `_face()` never picks up or down.
##
## Nothing about the ART is shared between bosses (see roster.gd); this script
## is the shared RULES, the way enemy_base.gd is for the enemy types.

signal conceded
## Every boss floor puts his health on the HUD. Shaped exactly like the
## player's own health_changed rather than inventing a second shape for the
## same job: game.gd wires both to the HUD the same way, and neither the
## boss nor the bar learns anything about the other.
signal health_changed(health: int, max_health: int)
## A boss may shake the room. Shaped like health_changed above and wired the
## same way: he says a blow landed hard and does not learn who is listening -
## game.gd is, because game.gd is what owns a camera. `strength` is in world
## pixels of throw and decays to nothing over `seconds`. A boss that never
## emits it simply never shakes anything.
signal shook(strength: float, seconds: float)
## A boss may also talk, and this is the third signal in that shape and wired
## the same way for the third time: he shouts, and never learns that a subtitle
## exists. game.gd listens, because game.gd is what owns the screen. `seconds`
## is how long the line was written to stay up, decided where the line was
## chosen - the only place that can know whether it has a clip whose length
## should set it (see boss_lines.gd). A boss with no `Lines` child never emits
## it and fights in silence.
signal said(speaker: String, text: String, seconds: float)

## The three moments every boss has a sound for, if he owns the files: a hit
## that hurt, a hit that STOPPED something, and the end. A boss with an
## `Audio` child gets them by existing - the same deal as the HUD bar - and a
## boss without one is silent with no branch anywhere but `_sfx`.
##
## The mechanism itself is no longer here. A boss IS an enemy, and the plain
## enemies wanted the identical node for the identical job, so it bubbled up
## to `game/enemies/enemy_audio.gd` beside `enemy_base.gd` - the placement
## rule in CLAUDE.md, and the same journey `wraith_base.gd` made. `_sfx`,
## `_sfx_loop` and `_sfx_fade` came with it and are inherited; what stays here
## is only WHERE a boss fires them.

## And the things he shouts, on exactly those terms: a `Lines` child naming a
## file of them, four cues wired by the base for free - `spot`, `hurt`,
## `stagger` and `concede` - plus `taunt`, plus one named after each attack as
## it begins. A boss without the child says nothing, with no branch anywhere
## but `_say`.
const BossLines := preload("res://game/bosses/boss_lines.gd")

## How long the player must stay out of his reach before he complains about it.
## Long enough that closing the ground normally never trips it - at Ahmed's
## speed 40 the walk in is about a second and a half - so it only ever fires on
## someone who is deliberately keeping away.
const TAUNT_SECONDS := 3.5

## His theme, and it is his the way his grunts are: game.gd starts it when it
## finds him in the `bosses` group and takes it back down when he concedes,
## on exactly the moments it raises and clears his HUD bar. It is declared
## HERE rather than added to Music's catalogue because that catalogue exists
## for the one track THREE front-end screens ask for by name; a boss theme is
## asked for by one thing in the game - the boss - so it belongs on him. A
## boss who names no track fights to whatever the floor was already playing,
## which today is silence, with no branch anywhere but game.gd's one `if`.
@export_file("*.wav") var music := ""

## The attack in progress, "" between attacks. Public for tests and for the
## effects that follow a swing.
var attack := ""
var has_conceded := false

var _damage_scale := 1.0
var _spotted := false
var _out_of_reach := 0.0

@onready var _lines: BossLines = get_node_or_null("Lines")


func _ready() -> void:
	super()
	# Read once at spawn, like the base's contact_damage: the mode cannot
	# change mid-fight, and each attack applies it when it is chosen.
	_damage_scale = Difficulty.damage_scale()


func _physics_process(delta: float) -> void:
	if has_conceded:
		velocity = Vector2.ZERO
		_sprite.modulate = Color.WHITE
		return
	super(delta)
	_watch_player(delta)


## The two things worth saying that no step of the cycle is in a position to
## notice: the frame he first lays eyes on the player, and the player refusing
## to come near him. Everything else he says hangs off a moment that already
## exists - an attack beginning, a hit landing, the end.
##
## The taunt is measured from his REACH and not from his sight, and that is the
## whole of what makes it read as a taunt: at the far edge of his sight radius
## he is walking towards you, and a man walking towards you has nothing to
## complain about yet. It is standing just outside his swing and staying there
## that earns "come here".
func _watch_player(delta: float) -> void:
	# Group + method, like everything else that reaches across: nothing here
	# names the player's script.
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	if global_position.distance_to(player.global_position) > sight_radius:
		_out_of_reach = 0.0
		return
	if not _spotted:
		_spotted = true
		_say("spot")
		return
	# Mid-attack does not count as being kept away - he is busy, and the attack
	# has its own line.
	if touching_player or attack != "":
		_out_of_reach = 0.0
		return
	_out_of_reach += delta
	if _out_of_reach >= TAUNT_SECONDS:
		_out_of_reach = 0.0
		_say("taunt")


## The name the HUD's boss bar announces him by. Read off his own SCENE and
## not his node name, which build_levels.gd overwrites with "Boss" so the
## floor's north door can find him - a bar reading BOSS is the one thing it
## must not say. A boss built from script rather than instanced has no scene
## path and gets an empty name, which is a blank bar rather than a crash.
func title() -> String:
	return scene_file_path.get_file().get_basename().to_upper()


## Which attack to open with when the player is in reach. A boss returns one of
## its own ids, or "" to hold off this frame.
func _pick_attack() -> String:
	return ""


## The numbers for one attack: {"windup", "recover", "damage"}. Seconds and
## MEDIUM damage; the difficulty scale is applied here in the base.
func _attack_spec(_id: String) -> Dictionary:
	return {}


func _begin_attack(id: String) -> void:
	var spec := _attack_spec(id)
	attack = id
	windup_seconds = spec["windup"]
	recover_seconds = spec["recover"]
	contact_damage = roundi(spec["damage"] * _damage_scale)
	# Said on the wind-up rather than on the blow, so the shout is part of the
	# telegraph instead of a note on what already happened. The cue IS the
	# attack id, which is what gets a new boss lines for a new attack without
	# either file learning the other's vocabulary.
	_say(id)
	# And the noise of it, on the same cue as the shout and by the same trick:
	# the id IS the attack, so `chop` looks for `chop_windup`. A boss who has
	# not been given that file is silent here and nothing branches - the deal
	# every sound in `_sfx` gets. The telegraph is separate from the impact
	# below on purpose: a wind-up can be interrupted, so one clip covering a
	# whole swing would play a blow that never landed.
	#
	# Unlike the grunts in take_damage, this one does NOT stand down for a
	# line, and the split is where the sound comes from rather than how loud
	# the frame is: a grunt and a line are one mouth making two sounds, while
	# an axe and a line are a man shouting as he swings, which is what he is
	# supposed to sound like.
	_sfx(id + "_windup")
	_enter(Phase.WINDUP)


## CHASE is the one step that differs: contact picks an attack rather than
## starting the single one the base has. Everything after that is the base's.
func _advance_phase() -> void:
	if phase == Phase.CHASE:
		if touching_player:
			var id := _pick_attack()
			if id != "":
				_begin_attack(id)
		return
	super()


func _enter(next: Phase) -> void:
	# Out of the attack the moment the cycle leaves it, whether it landed or
	# was interrupted; the fire and the animation both key off this.
	if next == Phase.CHASE or next == Phase.STAGGER:
		attack = ""
	super(next)


## The attack's own animation carries the whole cycle, wind-up through recover.
func _animation_state(advancing: bool) -> String:
	if attack != "" and (phase == Phase.WINDUP or phase == Phase.RECOVER):
		return attack
	return super(advancing)


## Arrived and between attacks, a boss stands: the base's "attack" contact
## state is the one animation a boss sheet does not have, since each attack
## carries its own.
func _contact_state() -> String:
	return "idle"


## Side profile only; a boss turns to face the player but never shows its back.
func _face(direction: Vector2) -> void:
	_facing = Facing.SIDE
	if absf(direction.x) > 0.01:
		_facing_left = direction.x < 0.0


## The base restarts a finished non-looping animation for as long as the state
## holds; an attack animation must instead hold its last frame until the phase
## moves on, or the blow would replay.
func _apply_animation(state: String) -> void:
	var anim := "%s_side" % state
	_sprite.flip_h = _facing_left
	if _sprite.animation == anim:
		if _sprite.is_playing() or not _sprite.sprite_frames.get_animation_loop(anim):
			return
	_sprite.play(anim)


func take_damage(amount: int) -> void:
	if health <= 0 or has_conceded:
		return
	health = maxi(health - amount, 0)
	_flash = HURT_FLASH_SECONDS
	# Before the concede below: the bar must show him reaching zero, not stop
	# at whatever he had left on the second-to-last blow.
	health_changed.emit(health, max_health)
	if health == 0:
		_concede()
		return
	if _interruptible():
		_interrupt_locked = interrupt_cooldown
		_enter(Phase.STAGGER)
		# The stagger REPLACES the grunt rather than layering over it: the one
		# thing the player needs to hear off this hit is that the swing died,
		# and two sounds on one frame is the fastest way to hear neither. What
		# he SAYS splits on the same line and for the same reason - being hurt
		# and being interrupted are two different insults.
		#
		# And a LINE replaces the grunt in turn, on the same rule carried one
		# step further: a grunt is his voice and so is a line, so playing both
		# is one mouth making two sounds at once. Most hits still grunt,
		# because most hits find the cue cooling down - he grunts, and now and
		# then he has something to say about it instead.
		if not _say("stagger"):
			_sfx("stagger")
	else:
		if not _say("hurt"):
			_sfx("hurt")


## Defeat. Rooted, harmless, still in the room; the door hears about it.
func _concede() -> void:
	has_conceded = true
	attack = ""
	_flash = 0.0
	remove_from_group("enemies")
	_touch_area.set_deferred("monitoring", false)
	_sprite.flip_h = _facing_left
	_sprite.play("concede_side")
	# His last line always lands - `concede` jumps every queue in boss_lines -
	# so on a boss who has the line this grunt never plays, and on one who does
	# not it is still the sound of him going down.
	if not _say("concede"):
		_sfx("concede")
	conceded.emit()


## One line, if this boss has any for that cue and a `Lines` child at all -
## `_sfx` above for the mouth rather than the throat, and every miss is legal
## for the same reasons. Most calls come back with nothing to say: the cue is
## still cooling down, or he is already mid-sentence, and the fight carries on
## either way (see boss_lines.gd).
## Returns whether he actually spoke, which is what lets a GRUNT stand down for
## a line - see the three call sites. Most calls return false: the cue is still
## cooling down, or he is already mid-sentence.
func _say(cue: String) -> bool:
	if _lines == null:
		return false
	var line := _lines.say(cue)
	if line.is_empty():
		return false
	said.emit(title(), String(line["text"]), float(line["seconds"]))
	return true
