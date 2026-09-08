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

## The attack in progress, "" between attacks. Public for tests and for the
## effects that follow a swing.
var attack := ""
var has_conceded := false

var _damage_scale := 1.0


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
	if health == 0:
		_concede()
		return
	if _interruptible():
		_interrupt_locked = interrupt_cooldown
		_enter(Phase.STAGGER)


## Defeat. Rooted, harmless, still in the room; the door hears about it.
func _concede() -> void:
	has_conceded = true
	attack = ""
	_flash = 0.0
	remove_from_group("enemies")
	_touch_area.set_deferred("monitoring", false)
	_sprite.flip_h = _facing_left
	_sprite.play("concede_side")
	conceded.emit()
