extends "res://game/bosses/ahmed/fx_node.gd"
## THE ENORMOUS CHAIR's run across the room, start to finish: the sparks off
## its wheels while he spins it up, the double line of fire its castors burn
## into the floor on the way, and the crash - dust off the wall and three
## stars going round his head for as long as he is sitting there dizzy.
##
## The chair itself, and him on it, are the sheet and axe_fire.gd's: they
## move with him. This node is everything he LEAVES, so it is pinned to the
## spot the run started from and ahmed.gd tells it the two moments it cannot
## see - `launch()` as the chair goes, `crash()` as it stops.
##
## Drawing only. The charge hurts through ahmed.gd's Touch area, like his axe.
## The trail is a picture of where he went, not a hazard: the run already hit
## whoever was in the way, and burning floor behind it would be a second blow
## nobody could have seen coming.

const SPARK_EVERY := 0.1
const BURN_FADES := 0.6
const BURN_GONE := 1.8
const STARS_AFTER := 0.1
const STAR_HEIGHT := -38.0

var _launched := false
var _crashed := false
var _crash_t := 0.0
var _end := Vector2.ZERO
var _along := Vector2.RIGHT


func _ready() -> void:
	life = 30.0
	super()


func launch(heading: Vector2) -> void:
	_launched = true
	_along = heading.normalized()


func crash() -> void:
	if _crashed:
		return
	_crashed = true
	_crash_t = _t
	_end = boss.global_position - anchor


func _sitting() -> bool:
	return boss != null and is_instance_valid(boss) and boss.get("attack") == "chair"


func _tick(_delta: float) -> void:
	if not _crashed and _launched and is_instance_valid(boss):
		_end = boss.global_position - anchor
	# Stood down before it ever went (knocked off it mid-spin), or long done.
	if not _launched and not _sitting():
		queue_free()
	elif _crashed and _t > _crash_t + BURN_GONE and not _sitting():
		queue_free()


func _draw() -> void:
	var t := _t
	if not _launched:
		var k := floorf(t / SPARK_EVERY)
		Kit.parts(self, 0, 0, t, k * SPARK_EVERY, 4, k,
			{"spd": 20.0, "vz": 12.0, "g": 50.0, "life": 0.2, "cols": [Kit.R[0], Kit.R[1], Kit.R[2]]})
		return
	# The castors' two lines, either side of the way he went.
	var f := Kit.seg(t, _crash_t + BURN_FADES, _crash_t + BURN_GONE) if _crashed else 0.0
	var side := Vector2(-_along.y, _along.x)
	var steps := int(_end.length())
	for s in steps:
		var p := _along * s
		for off in [-1, 1]:
			if Kit.h(s, off, floorf(t * 10.0)) < f:
				continue
			var n := Kit.h(s, off, floorf(t * 12.0))
			var col: Color = Kit.SCORCH if f > 0.5 else \
				(Kit.R[1] if n < 0.3 else (Kit.R[2] if n < 0.7 else Kit.R[3]))
			Kit.px(self, p.x + side.x * off, p.y + side.y * off, col)
	if not _crashed:
		return
	var c := t - _crash_t
	var ahead := signf(_along.x) if _along.x != 0.0 else 1.0
	Kit.parts(self, _end.x + 8 * ahead, _end.y - 6, t, _crash_t, 18, 71,
		{"spd": 30.0, "vz": 30.0, "g": 80.0, "life": 0.7, "size": 2.0, "cols": Kit.STONE})
	if c >= STARS_AFTER and _sitting():
		for i in 3:
			var a := t * 6.0 + i * 2.09
			Kit.px(self, _end.x + cos(a) * 6, _end.y + STAR_HEIGHT + sin(a) * 2, Kit.R[0])
