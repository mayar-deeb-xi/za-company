extends "res://tests/helpers.gd"
## The hit feel - what a blow the player lands now does besides the damage -
## and the four picks from the Combo Lab preview that ride on it: STATIC CHARGE
## on the light hits, the JUGGLE on the rising slash, the THUNDERCLAP on the arc
## and the SUPERNOVA on the heavy.
##
## Three staged scenes in the empty lobby, the way test_arc.gd stages its crowd:
##
## - a full combo into three rooted guards, watched every frame for what it
##   leaves behind: the room held still, a white flash and a recoil on the body
##   struck, numbers over the enemies (white for the blade, the spark colour
##   for a jump), the charge the swing and the slash leave, the slash's launch
##   - with the BODY never moving, which is the promise that keeps every
##   placement band in the building - and then the thunderclap: the flash, the
##   crackle left on the bodies the bolt reached, the charge going off, and the
##   body it killed breaking apart instead of vanishing;
## - the one pick that changes logic, measured on its own: a charged body
##   beats a nearer uncharged one for the arc's first jump;
## - a held heavy: embers drawn into the ring while it fills, the supernova on
##   the floor and the room holding still when it fires.
##
## And last, that a boss never reels - he moves his own sprite.
##
## It watches by LATCHING rather than by frame number: every effect here is
## short-lived and the hit-stop itself stretches time, so the honest question
## is "was it ever seen", asked every frame and answered at the end.

const StaticCharge := preload("res://game/player/static_charge.gd")
const DamageNumber := preload("res://game/player/damage_number.gd")
const KillBurst := preload("res://game/player/kill_burst.gd")
const SparkBurst := preload("res://game/player/spark_burst.gd")
const Supernova := preload("res://game/player/supernova.gd")
const ScreenFlash := preload("res://game/player/screen_flash.gd")
const Roster := preload("res://game/player/characters/roster.gd")

const AT := Vector2(272, 140)

var _guards: Array[Node2D] = []
var _placed: Array[Vector2] = []
var _spark := ""
# What has been seen.
var _min_scale := 1.0
var _struck_white := false
var _recoiled := false
var _launched := false
var _drift := 0.0
var _charges := 0
var _numbers := {}
var _jump_colour := ""
var _flash := 0.0
var _shocked := 0
var _burst := false
var _sparked := false
var _first_jump := Vector2.INF
var _embers := 0
var _nova := false
## The slowest the room ran once the supernova was down - the heavy's own swing
## stops the room too, so the stop that counts is the one after it fires.
var _nova_scale := 1.0


func _tick(frame: int) -> void:
	_watch()
	match frame:
		2:
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		17:
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
			_spark = Roster.spark_hex(Roster.find("reem")["recipe"])
		32:
			_player().global_position = AT
			_stage([Vector2(14, 0), Vector2(38, -13), Vector2(42, 11)])
		40:
			_key(KEY_D, true)
		42:
			_key(KEY_D, false)
		44:
			_player().global_position = AT
		# The combo, on test_arc.gd's own timings.
		50:
			_key(KEY_SPACE, true)
		54:
			_key(KEY_SPACE, false)
		58:
			_key(KEY_SPACE, true)
		62:
			_key(KEY_SPACE, false)
		74:
			_key(KEY_SPACE, true)
		78:
			_key(KEY_SPACE, false)
		140:
			_combo_checks()
			_clear()
		# The charge decides the chain: the nearer body is uncharged, the
		# farther one charged, and the arc goes to the charged one first.
		150:
			_player().global_position = AT
			_stage([Vector2(14, 0), Vector2(32, 0), Vector2(14, 30)])
			StaticCharge.add_to(_guards[2], Color.WHITE)
			_first_jump = Vector2.INF
		152:
			_player().call("_start_attack", "attack3")
		190:
			var want := _guards[2].global_position + Vector2(0, -10) \
				if is_instance_valid(_guards[2]) else Vector2.ZERO
			_check("charge: the arc jumps to the charged body before the nearer one (%s vs %s)"
				% [_first_jump, want], _first_jump == want)
			_clear()
		# The heavy, held until it fires itself.
		200:
			_player().global_position = AT
			_stage([Vector2(10, 0)])
			_flash = 0.0
			_key(KEY_SPACE, true)
		290:
			_key(KEY_SPACE, false)
		320:
			_check("supernova: embers stream into the ring while it charges (%d)" % _embers,
				_embers > 0)
			_check("supernova: it leaves its blast on the floor", _nova)
			_check("supernova: the room holds still as it fires (%.2f)" % _nova_scale,
				_nova_scale < 0.5)
			_check("supernova: and the frame flashes (%.2f)" % _flash, _flash > 0.0)
			_check("supernova: the guard it caught is gone", not is_instance_valid(_guards[0]))
			_check("hit feel: and the room runs at full speed again (%.2f)" % Engine.time_scale,
				Engine.time_scale == 1.0)
			_boss_checks()
			_finish()


## Rooted guards at offsets from AT, in the lobby's props.
func _stage(offsets: Array) -> void:
	_guards.clear()
	_placed.clear()
	var gs := load("res://game/enemies/regular/regular.tscn") as PackedScene
	for at in offsets:
		var g := gs.instantiate() as Node2D
		_level().get_node("Props").add_child(g)
		g.global_position = AT + at
		g.set("speed", 0.0)
		_guards.append(g)
		_placed.append(g.global_position)


func _clear() -> void:
	for g in _guards:
		if is_instance_valid(g):
			g.queue_free()


## Every frame: latch whatever the room is showing.
func _watch() -> void:
	_min_scale = minf(_min_scale, Engine.time_scale)
	for i in _guards.size():
		var g := _guards[i]
		if not is_instance_valid(g) or g.is_queued_for_deletion():
			continue
		if float(g.get("_struck")) > 0.0:
			_struck_white = true
		if float(g.get("_recoil")) > 0.0:
			_recoiled = true
		if float(g.get("_juggle_height")) > 0.0:
			_launched = true
		_drift = maxf(_drift, g.global_position.distance_to(_placed[i]))
		var charge := StaticCharge.of(g)
		if charge != null:
			_charges = maxi(_charges, int(charge.get("charges")))
		if g.get_node_or_null("Shock") != null and not g.has_meta("seen_shock"):
			g.set_meta("seen_shock", true)
			_shocked += 1
	var level := _level()
	if level == null:
		return
	for node in level.get_node("Props").get_children():
		var script: Script = node.get_script()
		if script == DamageNumber:
			var text: String = node.get("text")
			_numbers[text] = true
			if text == "5" and (node.get("colour") as Color).to_html(false) == _spark:
				_jump_colour = text
		elif script == KillBurst:
			_burst = true
		elif script == SparkBurst:
			_sparked = true
	for child in _player().get_children():
		if child.get_script() == ScreenFlash:
			_flash = maxf(_flash, (child.get_child(0) as ColorRect).color.a)
		elif child.get_script() == Supernova:
			_nova = true
	if _nova:
		_nova_scale = minf(_nova_scale, Engine.time_scale)
	for ring in get_nodes_in_group("player_charge"):
		_embers = maxi(_embers, (ring.get("_embers") as Array).size())
	if _first_jump == Vector2.INF:
		for bolt in get_nodes_in_group("player_arcs"):
			var chains: Array = bolt.get("chains")
			if not chains.is_empty() and (chains[0] as PackedVector2Array).size() > 2:
				_first_jump = (chains[0] as PackedVector2Array)[2]


func _combo_checks() -> void:
	_check("hit feel: a blow that lands holds the room still (%.2f)" % _min_scale,
		_min_scale < 0.5)
	_check("hit feel: the body struck flashes white first", _struck_white)
	_check("hit feel: and jolts away from the blow", _recoiled)
	_check("hit feel: the amount flies off the enemy - 5, 7, 12 (%s)" % str(_numbers.keys()),
		_numbers.has("5") and _numbers.has("7") and _numbers.has("12"))
	_check("hit feel: a jump's number is in the spark colour (%s)" % _spark,
		_jump_colour == "5")
	_check("hit feel: a body that dies breaks apart instead of vanishing", _burst)
	_check("charge: the swing and the slash leave two charges (%d)" % _charges,
		_charges == 2)
	_check("juggle: the rising slash launches the body it reaches", _launched)
	_check("juggle: and the body itself never moves (%.2f px)" % _drift, _drift < 0.5)
	_check("thunderclap: the frame flashes when the arc lands (%.2f)" % _flash, _flash > 0.0)
	_check("thunderclap: both bodies the bolt jumped to are left crackling (%d)" % _shocked,
		_shocked == 2)
	_check("thunderclap: the charge on the body it struck goes off", _sparked)


## A boss moves his own sprite, so a blow must not.
func _boss_checks() -> void:
	var boss: Node = (load("res://game/bosses/boss_base.gd") as GDScript).new()
	var enemy: Node = (load("res://game/enemies/enemy_base.gd") as GDScript).new()
	_check("reel: an enemy reels from a blow", enemy.call("_reels") == true)
	_check("reel: a boss never does", boss.call("_reels") == false)
	boss.free()
	enemy.free()
