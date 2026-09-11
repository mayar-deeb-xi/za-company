extends Node2D
## The kit Mostafa's two live effects draw with - `bell.gd` for his punches and
## `rage.gd` for what happens at 72 HP. Not a base class for bosses: a base
## class for HIS effects.
##
## Ahmed carries his own copy of most of this inside `axe_fire.gd`, and that is
## deliberate rather than an oversight waiting to be tidied. Nothing about the
## ART is shared between bosses - see roster.gd - and a flame is art: the
## SHAPES here are the same as his, because one game should have one fire, but
## the RAMP is the whole point of drawing it twice. Ahmed's fire is yellow and
## amber, fuel burning on an axe. Mostafa's is crimson and white, a body
## overheating. Nobody should have to check which boss they are fighting.
##
## If a third consumer ever needs these shapes, that is the moment they bubble
## up to `game/bosses/` as a shared kit taking a ramp - not before.
##
## Every subclass gets, for free:
##
## - the boss and his sprite, found by walking UP to the `bosses` group, so an
##   instance can sit under a CanvasLayer as easily as under the body
## - `part`, the surface it draws on: ground under the body, burst over it,
##   screen for the frame itself
## - `_time`, a free-running clock for anything that has to flicker while the
##   body stands still
## - `_into()`, seconds into the current animation, summed from the same `dur`
##   list the boss script derives its timings from
## - the pixel kit, quantized to whole world pixels and mirrored for a
##   left-facing frame the way axe_fire.gd does it: local x lands at -1 - x

const Poses := preload("res://game/bosses/mostafa/poses.gd")

@export_enum("ground", "burst", "screen") var part := "burst"

## His fire, hottest first: a white core through his own glove red to char.
## Deliberately NOT Ahmed's amber - see the header.
const F: Array[Color] = [
	Color(1.0, 253.0 / 255.0, 247.0 / 255.0),
	Color(1.0, 217.0 / 255.0, 200.0 / 255.0),
	Color(245.0 / 255.0, 112.0 / 255.0, 79.0 / 255.0),
	Color(224.0 / 255.0, 80.0 / 255.0, 60.0 / 255.0),
	Color(166.0 / 255.0, 52.0 / 255.0, 36.0 / 255.0),
	Color(74.0 / 255.0, 18.0 / 255.0, 14.0 / 255.0),
]
const HOT := Color(1.0, 253.0 / 255.0, 247.0 / 255.0)
const BONE := Color(233.0 / 255.0, 231.0 / 255.0, 226.0 / 255.0)
const GLOVE := Color(224.0 / 255.0, 80.0 / 255.0, 60.0 / 255.0)
const GLOVE_LO := Color(166.0 / 255.0, 52.0 / 255.0, 36.0 / 255.0)
const SMOKE := Color(125.0 / 255.0, 111.0 / 255.0, 112.0 / 255.0)
const SMOKE_LO := Color(74.0 / 255.0, 65.0 / 255.0, 66.0 / 255.0)

## Below this an alpha is not worth a draw call, let alone a pixel.
const FAINT := 0.03

var _boss: Node2D
var _sprite: AnimatedSprite2D
var _flip := false
var _time := 0.0


func _ready() -> void:
	# Walked rather than reached for by path: a "screen" part hangs off a
	# CanvasLayer, so its parent is not the boss the others sit directly under.
	var node: Node = self
	while node != null and not node.is_in_group("bosses"):
		node = node.get_parent()
	_boss = node as Node2D
	if _boss != null:
		_sprite = _boss.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	set_process(_sprite != null)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## The animation the sprite is playing, with the side suffix off.
func _anim() -> String:
	return String(_sprite.animation).trim_suffix("_side")


## Seconds from an animation's first frame to now. The sheet is sliced at
## Poses.FPS with each frame's `dur` as its duration multiplier, so a frame
## lasts exactly its own `dur` and this sum is the very clock the boss script
## takes its timings off. Holding the sprite still holds this too, which is
## what keeps a hit-stop from tearing an effect off the picture.
func _into(frames: Array, idx: int) -> float:
	var t := 0.0
	for i in idx:
		t += float(frames[i]["dur"])
	return t + clampf(_sprite.frame_progress, 0.0, 1.0) * float(frames[idx]["dur"])


## A glove in world pixels off his origin, straight out of the `gx/gy` the
## painter drew the sheet from. No new numbers, so a redrawn pose moves its
## fire with it.
func _glove(frame: Dictionary, key: String) -> Vector2:
	var arm: Dictionary = frame.get(key, {})
	if arm.is_empty():
		return Vector2.ZERO
	# One source pixel is half a world pixel - he is drawn at 2x density and
	# the scene halves it back. Read off the sprite rather than restated here.
	var dens := _sprite.scale.x
	return Vector2(
		(float(frame.get("dx", 0)) + float(arm["gx"])) * dens,
		float(Poses.SHOULDER + int(frame.get("dy", 0)) + int(arm["gy"])
			- Poses.FOOT) * dens)


# --- the pixel kit -----------------------------------------------------------


static func _hash(a: int, b: int) -> int:
	return absi((a * 73856093) ^ (b * 19349663)) % 2147483647


## Somewhere on the ramp, 0 hottest.
static func _fcol(t: float) -> Color:
	return F[clampi(roundi(t * (F.size() - 1)), 0, F.size() - 1)]


## One world pixel. A left-facing frame is mirrored about the origin - local x
## lands at -1 - x - which is what puts the origin between his feet.
func _put(x: float, y: float, col: Color) -> void:
	if col.a <= FAINT:
		return
	var px := floori(x)
	draw_rect(Rect2(float(-1 - px) if _flip else float(px), float(floori(y)),
		1.0, 1.0), col)


## A circle at `squash` 1, or the floor seen from the game's slight elevation
## at 0.4 - the same ellipse Ahmed's rings are drawn on.
func _ring(cx: float, cy: float, r: float, squash: float, col: Color) -> void:
	if r < 0.5 or col.a <= FAINT:
		return
	var steps := maxi(16, roundi(r * 9.0))
	for i in steps + 1:
		var th := TAU * float(i) / float(steps)
		_put(roundi(cx + cos(th) * r), roundi(cy + sin(th) * r * squash), col)


func _seg(x0: float, y0: float, x1: float, y1: float, col: Color) -> void:
	if col.a <= FAINT:
		return
	var n := maxi(2, ceili(Vector2(x1 - x0, y1 - y0).length()) + 1)
	for i in n + 1:
		var t := float(i) / float(n)
		_put(roundi(x0 + (x1 - x0) * t), roundi(y0 + (y1 - y0) * t), col)


## One tongue of flame standing on (x, y), `h` tall and `w` wide at the base.
func _flame(x: float, y: float, h: int, w: float, seed: int, alpha: float) -> void:
	if h < 1 or alpha <= FAINT:
		return
	for k in h:
		var t := float(k) / float(h)
		var half := maxf(0.0, (w / 2.0) * (1.0 - t * t))
		var jit := (_hash(seed, k) % 3) - 1 if k > h / 3 else 0
		var hf := floori(half)
		for dx in range(-hf, hf + 1):
			var edge := absi(dx) >= hf and half > 0.5
			var col := _fcol(minf(1.0, t + 0.3)) if edge else _fcol(t * 0.85)
			_put(x + dx + jit, y - k, Color(col, alpha))
	_put(x + (_hash(seed, 99) % 3) - 1, y - h - 1, Color(F[3], alpha))


func _embers(x: float, y: float, n: int, spread: int, seed: int, alpha: float) -> void:
	for i in n:
		var hx := _hash(seed, i * 3 + 1)
		var hy := _hash(seed, i * 3 + 2)
		_put(x + hx % (spread * 2 + 1) - spread, y - hy % (spread + 4),
			Color(F[1 + hy % 3], alpha))


## The column that comes up through him - a geyser with a white core.
func _column(x: float, y: float, h: int, w: float, seed: int, alpha: float) -> void:
	if h < 1 or alpha <= FAINT:
		return
	for k in h:
		var t := float(k) / float(h)
		var half := maxi(1, roundi((w / 2.0) * (1.0 - t * 0.55)))
		var jit := (_hash(seed, k) % 3) - 1 if k > 2 else 0
		for dx in range(-half, half + 1):
			var core: bool = absi(dx) <= half - 1 and t < 0.6
			var col := F[0 if t < 0.3 else 1] if core else _fcol(t + 0.2)
			_put(x + dx + jit, y - k, Color(col, alpha))
	_embers(x, y - h, 8, 7, seed + 5, alpha)


## Burnt floor, an ellipse of it, broken up.
func _scorch(x: float, y: float, w: int, seed: int, alpha: float) -> void:
	for dx in range(-w, w + 1):
		for dy in range(-2, 3):
			if float(dx * dx) / float(w * w) + float(dy * dy) / 5.0 > 1.0:
				continue
			if _hash(seed, dx * 7 + dy) % 4 == 0:
				continue
			_put(x + dx, y + dy, Color(F[5], 0.45 * alpha))


## Heat coming off him. No displacement to bend the room with, so it is sparse
## pixels rising - which is what reads as heat at this size anyway.
func _haze(cx: float, top: float, w: float, h: float, seed: int, alpha: float) -> void:
	for i in 14:
		var age := fposmod(_time * 0.7 + float(_hash(seed, i) % 100) / 100.0, 1.0)
		var off := float(_hash(seed, i + 50) % 100) / 100.0 - 0.5
		_put(cx + off * w, top - age * h, Color(F[1], (1.0 - age) * 0.22 * alpha))


## A plume off one shoulder.
func _smoke(x: float, y: float, seed: int, count: int, alpha: float) -> void:
	for i in count:
		var age := fposmod(_time * 0.5 + float(i) / float(count), 1.0)
		var jitter := float(_hash(seed, i) % 100) / 100.0 - 0.5
		var sx := x + jitter * 6.0 + sin(age * 4.0 + float(i)) * 3.0
		var sy := y - age * 26.0
		_put(sx, sy, Color(SMOKE_LO if age > 0.5 else SMOKE, (1.0 - age) * 0.5 * alpha))
