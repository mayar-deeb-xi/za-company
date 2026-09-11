extends "res://tests/helpers.gd"
## The fourth archetype: `security`, the brute, and the slam that takes your
## POSITION rather than your health alone.
##
## Its own suite for the reason test_scrubber.gd is: what is under test is an
## effect that MOVES the player, and every other combat check in this project
## measures a player who stays put. test_combat.gd parks a body in front of a
## guard and reads health; do that here and the player is thrown out of the
## geometry the next check needs, which is exactly the coupling
## "one suite = one clean world" exists to prevent.
##
## ## Built in the lobby, like the beats and the steering
##
## Floor 1 is the one room with no enemies of its own, so anything standing in
## it was put there by this file: nothing else is moving, nothing else is
## draining, and a health check has exactly one cause. The marble hall has a
## real `security` in it, but it also has eight office boys and two beats, and
## a blow of 20 is not distinguishable from a blow of 20 plus a guard's 10 that
## the same grace window swallowed.
##
## ## What is checked, and why the damage one is exact
##
## - **The ring cannot lie.** Its radius is copied off the Touch shape, so the
##   circle the player reads and the circle that hurts are one number. This is
##   the check that catches somebody retuning the area in the editor and
##   leaving the drawing behind - which is a bug nobody can see, because the
##   drawing looks right and only the hitbox moved.
## - **The wind-up warns without hurting.** A telegraph that already costs you
##   something is not a telegraph.
## - **The blow is EXACTLY the node's own scaled damage**, not merely non-zero.
##   A slam that landed twice - once from `_touch_strike` and once from some
##   per-frame contact nobody meant to leave in - reads as "health went down"
##   to a looser check and as a doubled blow to the player.
## - **It moves you, and the push wears off.** Being moved is half the attack;
##   a push that did not decay would be a launch.
## - **Stepping out is free.** `_windup_needs_contact()` is false, so the slam
##   lands on air like a swing - which is only counterplay if leaving the ring
##   really costs nothing.
## - **48 is on the ladder.** The one check here that is pure arithmetic, read
##   off player.gd rather than asserted as a literal: 48 has to be a cumulative
##   breakpoint on the combo AND exactly two heavies, or the enemy the heavy was
##   made for stops dying to it.
## - **The lane.** Read off disk across every biome, the way test_music.gd reads
##   the finale rule: a 90 px sight has a placement band, and a future floor
##   putting one of these near the door line fails here rather than in play.

const SECURITY := "res://game/enemies/security/security.tscn"

## The building, kept here as a literal exactly as test_music.gd and
## test_dominique.gd keep it. Neither `tools/biomes.gd` nor `player.gd` may be
## preloaded into a --script file: this file is compiled before the autoload
## list reaches the compiler, so anything reaching `Difficulty` from here fails
## to compile with "Identifier not found". Constants come off live nodes'
## scripts instead, and the chain is read as built scenes off disk.
const CHAIN := ["lobby", "content_studio", "call_center", "ahmed_office",
		"the_hub", "marble_hall", "innovation_lab", "conflict_resolution",
		"asset_recovery", "hellfire", "executive_floor", "khaled_office"]

## Open lobby floor, well clear of the reception desk and both doorways.
const SPOT := Vector2(400, 150)
## Inside the 28 px ring and outside the 20 px stop distance, so the brute is
## already touching the player on the frame it spawns and neither body has to
## walk anywhere for the cycle to start.
const BESIDE := Vector2(422, 150)
## Far enough that the second brute's 90 px sight cannot reach the first check's
## leftovers, and far enough from the ring that leaving it is unambiguous.
const AWAY := Vector2(120, 280)

## The door lane, which no authored position's sight radius may reach.
const LANE_MIN := 246.0
const LANE_MAX := 300.0

var _brute: CharacterBody2D = null
var _t0 := 0
var _hp_before := 0
var _hp_after := -1
var _dealt := 0
var _pushed := 0.0
var _drift := 0.0
var _rest := Vector2.ZERO
var _second: CharacterBody2D = null
var _hp_at_stepout := 0


func _tick(frame: int) -> void:
	if _t0 == 0:
		if frame == 2:
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		elif frame == 17:
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
		elif frame > 20 and _level() != null:
			_t0 = frame
		return
	_lobby(frame - _t0)


func _lobby(at: int) -> void:
	match at:
		2:
			_player().global_position = SPOT
			_brute = _spawn(BESIDE)
			_shape()
			_ladder()
			_lane()
		3:
			# One frame on, so the brute's _ready has run and the ring has been
			# handed the Touch shape's own circle.
			_drawing()
			_hp_before = _player().health
		_:
			_slam(at)
			_stepout(at)


## The area and the drawing are one number, or the player is reading a circle
## that is not the circle that hurts.
func _drawing() -> void:
	var shape := _brute.get_node("Touch/CollisionShape2D") as CollisionShape2D
	var circle := shape.shape as CircleShape2D
	var ring := _brute.get_node("SlamRing") as Node2D
	_check("the ring draws the Touch shape's own reach (%.0f px)" % circle.radius,
		is_equal_approx(ring.get("radius"), circle.radius))
	_check("and sits on it", ring.position.is_equal_approx(shape.position))
	# Not a drawing check but the same class of mistake: a ring drawn under the
	# floor is a telegraph nobody ever sees, which is what the warden's field
	# shipped as once.
	_check("at z 0, above the floor tilemap and under the body",
		ring.z_index == 0)


## Both bounds on stop_distance, which is the one number a bigger body breaks.
func _shape() -> void:
	var body := (_brute.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	var reach := ((_brute.get_node("Touch/CollisionShape2D") as CollisionShape2D).shape as CircleShape2D).radius
	var player_radius := 5.0
	_check("stop_distance clears the two bodies (%.0f > %.0f)"
		% [_brute.stop_distance, body.radius + player_radius],
		_brute.stop_distance > body.radius + player_radius)
	_check("and stays inside its own ring (%.0f < %.0f)"
		% [_brute.stop_distance, reach + player_radius],
		_brute.stop_distance < reach + player_radius)


## 48 is not a round number and must never become one: it is the eighth rung of
## the player's combo and exactly two heavies. Read off player.gd so retuning
## either side fails here rather than silently.
func _ladder() -> void:
	# Off the live player's own script, the way helpers._zooms() reaches
	# Display's constants - a constant is not a property, so get() cannot see
	# it, and preloading player.gd here does not compile (see CHAIN above).
	var c: Dictionary = _player().get_script().get_script_constant_map()
	var light: int = c["ATTACK_POWER"]
	var thrust: int = c["THRUST_POWER"]
	var heavy: int = c["HEAVY_POWER"]
	var rungs: Array[int] = []
	var total := 0
	for i in 12:
		total += light if i % 2 == 0 else thrust
		rungs.append(total)
	_check("48 HP is a combo breakpoint (%s)" % str(rungs.slice(0, 9)),
		rungs.has(_brute.max_health))
	_check("and exactly two heavies (2 x %d)" % heavy,
		_brute.max_health == heavy * 2)
	_check("difficulty left the health alone", _brute.max_health == 48)


## The rule the marble hall is only one instance of: every `security` authored
## into any biome keeps its whole sight radius off the door lane. Read off disk,
## so a floor that places one badly fails here and not in play.
func _lane() -> void:
	var placed := 0
	var bad: Array[String] = []
	for name: String in CHAIN:
		var room := (load("res://game/levels/%s/%s.tscn" % [name, name])
			as PackedScene).instantiate()
		for node in room.get_node("Props").get_children():
			# Found the way everything in this game finds anything: by what it
			# can do, never by its type. `shove_force` is brute_base's and only
			# brute_base's, so this picks up a second big enemy the day one
			# exists without anybody adding it to a list here.
			if not node.is_in_group("enemies") or node.get("shove_force") == null:
				continue
			placed += 1
			var x: float = (node as Node2D).position.x
			var sight: float = node.get("sight_radius")
			if x + sight > LANE_MIN and x - sight < LANE_MAX:
				bad.append("%s at x %.0f (sight %.0f)" % [name, x, sight])
		room.free()
	_check("at least one floor stands a brute on it (%d)" % placed, placed > 0)
	_check("every one of them clears the door lane by its own sight%s"
		% ("" if bad.is_empty() else " -> " + ", ".join(bad)), bad.is_empty())


func _slam(at: int) -> void:
	# The whole wind-up: it is touching, it is winding up, and it has cost
	# nothing yet. Sampled across the window rather than on one frame, so a
	# telegraph that hurts on its last frame cannot slip through.
	if at >= 10 and at <= 45:
		if _player().health < _hp_before:
			_dealt = 1
	if at == 45:
		_check("the wind-up telegraphs without hurting (phase %d)" % _brute.phase,
			_dealt == 0)
		_check("and the ring is drawing it",
			float(_brute.get_node("SlamRing").get("progress")) > 0.0)
	# The blow, and what it cost - read as the drop from the health the player
	# went into the wind-up with.
	if at > 45 and at <= 110 and _hp_after < 0 and _player().health < _hp_before:
		_hp_after = _player().health
	# How far it threw them, as a PEAK: the push decays, so where they happen
	# to be standing when a later frame runs is not how far they went.
	if at > 45 and at <= 110:
		_pushed = maxf(_pushed, _player().global_position.distance_to(SPOT))
	match at:
		110:
			_check("the slam landed on the player standing in the ring",
				_hp_after >= 0)
			_check("for exactly its own scaled damage (%d, dealt %d)"
				% [_brute.contact_damage, _hp_before - maxi(_hp_after, 0)],
				_hp_before - _hp_after == _brute.contact_damage)
			_check("and threw them out of it (%.1f px)" % _pushed, _pushed > 8.0)
			# Out of the way, so the decay below measures the push and nothing
			# else - a brute still standing there would simply slam again.
			_brute.queue_free()
			_brute = null
		112:
			_rest = _player().global_position
		# A full SHOVE_SECONDS (0.5s = 30 frames) and then some, with no input
		# and nobody touching them.
		142:
			_drift = _player().global_position.distance_to(_rest)
			_check("the push wears off rather than carrying them (%.1f px after 0.5s)"
				% _drift, _drift < 2.0)


func _stepout(at: int) -> void:
	match at:
		150:
			_player().global_position = SPOT
			_second = _spawn(BESIDE)
		152:
			_hp_at_stepout = _player().health
		# Well past `commit_fraction` (0.65 of 0.9s = 35 frames): the blow is
		# committed and WILL be thrown. Leaving still costs nothing, because a
		# slam lands on air.
		190:
			_player().global_position = AWAY
		230:
			_check("a committed slam still lands on air when the ring is empty",
				_player().health == _hp_at_stepout)
			_check("and the brute is past it rather than stuck winding up",
				_second.phase != _second.Phase.WINDUP)
			_finish()


## Added to the level rather than to Props, so it is in the room on the same
## terms every other enemy is.
func _spawn(at: Vector2) -> CharacterBody2D:
	var enemy := (load(SECURITY) as PackedScene).instantiate() as CharacterBody2D
	_level().add_child(enemy)
	enemy.global_position = at
	return enemy
