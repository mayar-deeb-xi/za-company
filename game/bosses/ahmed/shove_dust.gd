extends "res://game/bosses/ahmed/fx_node.gd"
## The SWEEP THAT SHOVES, seen from the feet of the person it shoved: dust
## kicked up where they skid, and speed lines streaming off them while they
## are still moving.
##
## The push itself is player.gd's `shove()`, capped by the player at 70 and
## decaying over half a second - about 18 px of skid, which from the axe's
## reach is just far enough to put you out of it and in front of him, where
## the fan wave goes. The preview had the player sliding 46 px; the cap is
## shared with the brute and the scrubbers, so it was not raised for this.
##
## Spawned on the sweep's impact at Ahmed's feet, handed the body it shoved
## as `victim`. The dust is laid where the victim WAS, every 0.06 s for the
## first six puffs; the streaks follow them.

const PUFFS := 6
const PUFF_EVERY := 0.06
const PUFF_LIFE := 0.4
const STREAK_SECONDS := 0.42
const DUST := Color("8d939f")
const LINE := Color(223 / 255.0, 227 / 255.0, 234 / 255.0, 0.5)

var victim: Node2D
var _trail: Array[Vector2] = []
var _away := 1.0


func _ready() -> void:
	life = PUFF_EVERY * PUFFS + PUFF_LIFE
	super()


func _tick(_delta: float) -> void:
	if victim == null or not is_instance_valid(victim):
		return
	_away = signf(victim.global_position.x - anchor.x)
	if _away == 0.0:
		_away = dir
	while _trail.size() < PUFFS and _t >= _trail.size() * PUFF_EVERY:
		_trail.append(victim.global_position - anchor)


func _draw() -> void:
	for k in _trail.size():
		var tk := k * PUFF_EVERY
		var v := (_t - tk) / PUFF_LIFE
		if v < 0.0 or v > 1.0:
			continue
		var at: Vector2 = _trail[k]
		Kit.disc(self, at.x - 2 * _away, at.y + 1, 0, 1 + v * 3, func(xx, yy, _d, _a) -> Color:
			return DUST if Kit.h(xx, yy, k) < 0.55 * (1.0 - v) else Color(0, 0, 0, 0))
	if _t >= STREAK_SECONDS or victim == null or not is_instance_valid(victim):
		return
	var p: Vector2 = victim.global_position - anchor
	for i in 3:
		var y := p.y - 4 - i * 4
		var n := 6 + int(Kit.h(i, floorf(_t * 20.0)) * 4.0)
		for x in n:
			Kit.px(self, p.x - _away * (8 + x + i * 2), y, Color.WHITE if x < 2 else LINE)
