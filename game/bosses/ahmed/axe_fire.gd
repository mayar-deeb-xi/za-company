extends Node2D
## Ahmed's fire, drawn live rather than baked into the sheet.
##
## The sheet is a clean body so it can be hand-drawn into; the fire is a layer
## of its own, and this node draws it pixel by pixel from the same poses the
## sheet was painted from. So the flame sits on the blade the frame actually
## shows, and a redrawn pose moves its fire with it. The pixels are the ones
## the approved mockup drew - same functions, same seeds, at game scale.
##
## Instanced twice in ahmed.tscn: `part` "floor" is the first child, under the
## body, for the slam's ring and cracks; "air" sits over the body for
## everything else, the glow on the blade included. Both read the sprite's
## current animation and frame and its flip, so they need no telling.
##
## The sheet is one profile; a frame facing left is drawn mirrored about the
## boss's origin, which is what puts the origin between the feet: a pixel at
## local x lands at -1 - x.

const Poses := preload("res://game/bosses/ahmed/poses.gd")

@export_enum("floor", "air") var part := "air"

## The glow on the blade is reseeded this often, so the idle fire moves while
## the body stands still.
const FLICKER_HZ := 8.0

const RAMP := {
	"1": Color("fff3b0"), "2": Color("ffb63a"), "3": Color("ff6a2a"),
	"4": Color("c8301c"), "5": Color("5a1a14"),
}
const SCORCH := Color(60 / 255.0, 22 / 255.0, 18 / 255.0)
const SMOKE := Color(160 / 255.0, 150 / 255.0, 160 / 255.0)
## Named floor colours, so the pose data reads as words.
const FLOOR := {
	"ember": Color(200 / 255.0, 70 / 255.0, 30 / 255.0, 0.8),
	"ember_fill": Color(200 / 255.0, 70 / 255.0, 30 / 255.0, 0.13),
	"hot": Color(1.0, 200 / 255.0, 120 / 255.0, 0.95),
	"flash": Color(1.0, 245 / 255.0, 200 / 255.0, 0.95),
	"flash_fill": Color(1.0, 220 / 255.0, 150 / 255.0, 0.5),
	"orange": Color(1.0, 180 / 255.0, 60 / 255.0, 0.95),
	"orange_fill": Color(1.0, 120 / 255.0, 40 / 255.0, 0.22),
	"warm": Color(1.0, 150 / 255.0, 60 / 255.0, 0.6),
	"fire": Color(1.0, 150 / 255.0, 50 / 255.0, 0.9),
	"fire_fill": Color(200 / 255.0, 60 / 255.0, 30 / 255.0, 0.14),
	"fire_dim": Color(230 / 255.0, 110 / 255.0, 40 / 255.0, 0.7),
	"dim": Color(90 / 255.0, 30 / 255.0, 22 / 255.0, 0.6),
	"scorch": Color(60 / 255.0, 22 / 255.0, 18 / 255.0, 0.4),
	"crack_hot": Color(1.0, 110 / 255.0, 40 / 255.0, 0.9),
	"crack_warm": Color(1.0, 90 / 255.0, 30 / 255.0, 0.85),
	"crack_dim": Color(200 / 255.0, 60 / 255.0, 30 / 255.0, 0.7),
	"crack_out": Color(120 / 255.0, 40 / 255.0, 25 / 255.0, 0.5),
}

var _time := 0.0
var _pixels := {}
var _sprite: AnimatedSprite2D


func _ready() -> void:
	_sprite = get_parent().get_node("AnimatedSprite2D") as AnimatedSprite2D


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var anim := String(_sprite.animation).trim_suffix("_side")
	if not Poses.ANIMS.has(anim):
		return
	var frames: Array = Poses.ANIMS[anim]
	var idx := clampi(_sprite.frame, 0, frames.size() - 1)
	var f: Dictionary = frames[idx]
	var seed := absi(anim.hash()) % 1000 + idx * 7
	_pixels.clear()
	if part == "floor":
		for d in f.get("floor", []):
			_floor_fx(d)
	else:
		var axe: Dictionary = f.get("axe", {})
		var glow: float = f.get("glow", 1.0)
		if not axe.is_empty() and glow > 0.0:
			_blade_fire(axe, seed + int(_time * FLICKER_HZ), glow)
		for d in f.get("fx", []):
			_air_fx(d, f, seed)
	var flip := _sprite.flip_h
	for p in _pixels:
		var x: int = -1 - p.x if flip else p.x
		draw_rect(Rect2(x, p.y, 1, 1), _pixels[p])


func _air_fx(d: Array, f: Dictionary, seed: int) -> void:
	var axe: Dictionary = f.get("axe", {})
	match d[0]:
		"sparks_edge":
			var e := _edge(axe)
			_sparks(e.x, e.y + d[3], d[1], d[2], seed)
		"haft":
			_haft(axe, seed, d[1])
		"trail":
			_trail(axe, axe["len"], d[1], d[2], seed)
		"trail_len":
			_trail(axe, d[1], d[2], d[3], seed + 100)
		"geyser":
			_geyser(d[1], d[2], d[3], d[4], seed)
		"splash":
			_splash(d[1], d[2], d[3], seed)
		"sparks":
			_sparks(d[1], d[2], d[3], d[4], seed)
		"scorch":
			_scorch(d[1], d[2], d[3], seed, d[4])
		"fissure":
			_fissure(d[1], d[2], d[3], seed, d[4])
		"patch":
			_patch(d[1], d[2], d[3], seed, d[4])
		"embers":
			_embers(d[1], d[2], d[3], d[4], seed)
		"drag":
			_drag(d[1], d[2], seed, d[3])
		"crescent":
			_crescent(d[1], d[2], d[3], d[4], d[5], d[6], seed, d[7])
		"flame":
			_flame(d[1], d[2], d[3], d[4], seed)
		"burst":
			_burst(d[1], d[2], d[3], seed)
		"pillars":
			_pillars(d[1], d[2], seed)
		"wave":
			_wave(d[1], d[2], seed)
		"wave_scorch":
			for x in range(d[1], d[1] + d[2], 3):
				_scorch(x, 0, 3, seed + x, d[3])
		"smoke":
			_put(d[1], d[2], Color(SMOKE, 0.5))
			_put(d[1] + 1, d[2] - 2, Color(SMOKE, 0.35))
			_put(d[1], d[2] - 4, Color(SMOKE, 0.2))


func _floor_fx(d: Array) -> void:
	match d[0]:
		"ring":
			_ring(d[1], d[2], d[3], d[4], FLOOR[d[5]], FLOOR[d[6]] if d[6] != "" else Color(0, 0, 0, 0))
		"cracks":
			_cracks(d[1], d[2], d[3], FLOOR[d[4]])


# --- the pixel kit -----------------------------------------------------------


static func _hash(a: int, b: int) -> int:
	return absi((a * 73856093) ^ (b * 19349663)) % 2147483647


static func _fcol(t: float) -> Color:
	if t < 0.3:
		return RAMP["1"]
	if t < 0.6:
		return RAMP["2"]
	if t < 0.85:
		return RAMP["3"]
	return RAMP["4"]


func _put(x: float, y: float, col: Color) -> void:
	_pixels[Vector2i(floori(x), floori(y))] = col


## The haft's frame in local pixels: unit vectors along and across it, and
## the centre of the two-pixel fist it is held in.
static func _axe_frame(axe: Dictionary) -> Dictionary:
	var hand: Vector2i = axe["hand"]
	var blade: float = axe.get("blade", 1)
	var a: float = deg_to_rad(axe["ang"])
	var h := Poses.local(hand.x, hand.y)
	return {"ux": cos(a), "uy": sin(a), "vx": -sin(a) * blade, "vy": cos(a) * blade,
		"hx": h.x + 1.0, "hy": h.y + 1.0}


## Where the blade's edge sits, for the fire that clings to it.
static func _edge(axe: Dictionary) -> Dictionary:
	var fr := _axe_frame(axe)
	var u: float = axe["len"]
	var v := 5.0
	return {"x": fr.hx + fr.ux * u + fr.vx * v, "y": fr.hy + fr.uy * u + fr.vy * v,
		"ux": fr.ux, "uy": fr.uy}


## One tongue of flame standing on (x, y), h tall, w wide at the base.
func _flame(x: float, y: float, h: int, w: float, seed: int) -> void:
	for k in h:
		var t := float(k) / float(h)
		var half := maxf(0.0, (w / 2.0) * (1.0 - t * t))
		var jit := (_hash(seed, k) % 3) - 1 if k > h / 3.0 else 0
		var hf := floori(half)
		for dx in range(-hf, hf + 1):
			var edge := absi(dx) >= hf and half > 0.5
			_put(x + dx + jit, y - k, _fcol(minf(1.0, t + 0.3)) if edge else _fcol(t))
	_put(x + (_hash(seed, 99) % 3) - 1, y - h - 1, RAMP["4"])


func _embers(x: float, y: float, n: int, spread: int, seed: int) -> void:
	for i in n:
		var hx := _hash(seed, i * 3 + 1)
		var hy := _hash(seed, i * 3 + 2)
		_put(x + hx % (spread * 2 + 1) - spread, y - hy % (spread + 4), RAMP[["2", "3", "4"][hy % 3]])


func _scorch(x: float, y: float, w: int, seed: int, alpha: float) -> void:
	for dx in range(-w, w + 1):
		for dy in range(-2, 3):
			if float(dx * dx) / float(w * w) + float(dy * dy) / 5.0 > 1.0:
				continue
			if _hash(seed, dx * 7 + dy) % 4 == 0:
				continue
			_put(x + dx, y + dy, Color(SCORCH, alpha))


## Fire swept behind the blade around the fist, from angle a0 to a1.
func _trail(axe: Dictionary, len: float, a0: float, a1: float, seed: int) -> void:
	var fr := _axe_frame(axe)
	var steps := ceili(absf(a1 - a0) / 4.0)
	for i in steps + 1:
		var t := float(i) / float(steps)
		var ang := deg_to_rad(a0 + (a1 - a0) * t)
		for r in range(int(len) + 1, int(len) + 7):
			var rr := (r - len - 1.0) / 5.0
			if _hash(seed + i, r) % 5 < 1 + rr * 2.0:
				continue
			_put(fr.hx + cos(ang) * r, fr.hy + sin(ang) * r, _fcol(0.2 + (1.0 - t) * 0.6 + rr * 0.2))


## The fire that lives on the blade in every frame.
func _blade_fire(axe: Dictionary, seed: int, size: float) -> void:
	var e := _edge(axe)
	for i in 3:
		var s := (i - 1) * 3.0
		_flame(e.x + e.ux * s, e.y + e.uy * s, roundi((3 + _hash(seed, i) % 3) * size), 3, seed + i * 11)
	_embers(e.x, e.y - 2, 2, 3, seed + 7)


func _burst(x: float, y: float, size: float, seed: int) -> void:
	_flame(x, y, roundi(8 * size), 6, seed)
	_flame(x - 5, y, roundi(5 * size), 4, seed + 1)
	_flame(x + 5, y, roundi(6 * size), 4, seed + 2)
	_flame(x - 9, y + 1, 3, 3, seed + 3)
	_flame(x + 10, y + 1, 4, 3, seed + 4)
	_embers(x, y - 6, 10, 9, seed + 5)


func _patch(x: float, y: float, w: int, seed: int, hgt: int) -> void:
	_scorch(x, y, w, seed, 1.0)
	for i in 4:
		_flame(x + _hash(seed, i) % (w * 2) - w, y + 1, hgt, 2, seed + i)


## A wave of fire rolling along the floor, its front at `front`.
func _wave(x0: float, front: float, seed: int) -> void:
	var x := x0
	while x < front - 10:
		_scorch(x, 0, 3, seed + int(x), 0.9)
		x += 3
	var heights := [3, 6, 9, 7, 5]
	for i in heights.size():
		_flame(front - 10 + i * 3, 1 - (i % 2), heights[i], 4, seed + i)
	_flame(front + 3, 0, 4, 3, seed + 9)
	_embers(front - 4, -6, 8, 8, seed + 20)


## Bright specks with a short streak, thrown upward.
func _sparks(x: float, y: float, n: int, spread: int, seed: int) -> void:
	for i in n:
		var hx := _hash(seed, i * 5 + 1)
		var hy := _hash(seed, i * 5 + 2)
		var px := x + hx % (spread * 2 + 1) - spread
		var py := y - hy % (spread + 6)
		_put(px, py, RAMP["1"] if hy % 2 == 1 else RAMP["2"])
		_put(px, py + 1, RAMP["3"])
		if hx % 3 == 0:
			_put(px, py + 2, RAMP["4"])


## Flames licking down the haft toward the hands.
func _haft(axe: Dictionary, seed: int, n: int) -> void:
	var fr := _axe_frame(axe)
	var len: float = axe["len"]
	for i in n:
		var u := len - 2.0 - i * 2.5 - (_hash(seed, i) % 2)
		_flame(fr.hx + fr.ux * u, fr.hy + fr.uy * u, 2 + _hash(seed, i + 9) % 2, 1, seed + i)


## The chop's column of fire out of the impact.
func _geyser(x: float, y: float, h: int, w: float, seed: int) -> void:
	for k in h:
		var t := float(k) / float(h)
		var half := maxi(1, roundi((w / 2.0) * (1.0 - t * 0.6)))
		var jit := (_hash(seed, k) % 3) - 1 if k > 2 else 0
		for dx in range(-half, half + 1):
			var core := absi(dx) <= half - 1 and t < 0.55
			_put(x + dx + jit, y - k, (RAMP["1"] if t < 0.25 else RAMP["2"]) if core else _fcol(t + 0.15))
	_flame(x - 1, y - h, 4, 2, seed + 3)
	_flame(x + 2, y - h + 1, 3, 2, seed + 4)


func _splash(x: float, y: float, reach: float, seed: int) -> void:
	for dir in [-1, 1]:
		for i in range(2, int(reach)):
			var t := i / reach
			var py := y - roundi(sin(t * PI) * reach * 0.45)
			if _hash(seed + dir * 7, i) % 4 == 0:
				continue
			_put(x + dir * i, py, _fcol(t * 0.9))
			if i % 3 == 0:
				_put(x + dir * i, py - 1, RAMP["4"])


## A jagged burning crack running forward along the floor.
func _fissure(x: float, y: float, len: int, seed: int, hot: bool) -> void:
	var yy := y
	for i in len:
		if i % 3 == 0:
			yy = y + _hash(seed, i) % 3 - 1
		_put(x + i, yy, (RAMP["2"] if i % 4 == 0 else RAMP["3"]) if hot else RAMP["5"])
		_put(x + i, yy + 1, RAMP["5"])
		if hot and _hash(seed, i + 40) % 4 == 0:
			_flame(x + i, yy, 2 + _hash(seed, i) % 3, 1, seed + i)


## The sweep's crescent, between radii r0..r1 over angles a0..a1, breaking up
## as `decay` rises.
func _crescent(cx: float, cy: float, r0: int, r1: int, a0: float, a1: float, seed: int, decay: int) -> void:
	var steps := ceili((a1 - a0) / 3.0)
	for i in steps + 1:
		var t := float(i) / float(steps)
		var ang := deg_to_rad(a0 + (a1 - a0) * t)
		var lead := 1.0 - absf(t - 0.5) * 2.0
		for r in range(r0, r1 + 1):
			var rr := float(r - r0) / maxf(1.0, r1 - r0)
			if _hash(seed + i, r) % 5 < decay + rr * 2.0:
				continue
			var heat := rr * 0.7 + (1.0 - lead) * 0.4 + decay * 0.12
			_put(cx + cos(ang) * r, cy + sin(ang) * r, _fcol(minf(1.0, heat)))


## The low blade dragging fire across the floor behind him.
func _drag(x0: int, x1: int, seed: int, hgt: int) -> void:
	for x in range(x0, x1 + 1, 2):
		_scorch(x, 0, 2, seed + x, 0.8)
		if _hash(seed, x) % 3 == 0:
			_flame(x, 0, hgt + _hash(seed, x + 1) % 2, 2, seed + x)


## Flames standing round the slam's ring at radius r.
func _pillars(r: float, h: int, seed: int) -> void:
	for i in 8:
		var a := (i / 8.0) * TAU + 0.3
		var x := cos(a) * r
		var y := -1.0 + sin(a) * r * 0.42
		_flame(x, y + 1, roundi(h * (0.7 + (_hash(seed, i) % 4) / 6.0)), 4, seed + i)


## An elliptical ring on the floor, seen from the game's slight elevation.
func _ring(cx: float, cy: float, r: float, th: float, col: Color, fill: Color) -> void:
	var ry := r * 0.42
	for y in range(floori(cy - ry) - 1, ceili(cy + ry) + 2):
		for x in range(floori(cx - r) - 1, ceili(cx + r) + 2):
			var d := Vector2((x + 0.5 - cx) / r, (y + 0.5 - cy) / ry).length()
			if absf(d - 1.0) * r < th:
				_put(x, y, col)
			elif fill.a > 0.0 and d < 1.0:
				_put(x, y, fill)


func _cracks(cx: float, cy: float, r: float, col: Color) -> void:
	var angs := [-160, -120, -60, -20, 20, 60, 120, 160]
	for i in angs.size():
		var rad := deg_to_rad(angs[i])
		var len := r * (0.6 + 0.4 * ((i * 7) % 5) / 4.0)
		for k in range(3, int(len)):
			_put(cx + cos(rad) * k, cy + sin(rad) * k * 0.42, col)
