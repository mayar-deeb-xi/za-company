extends RefCounted
## The pixel kit Ahmed's new attack effects draw with, ported line for line
## from the attack preview they were picked from (the "Ahmed's New Moves"
## artifact). Same hash, same easing, same flame, same particle spray, so a
## number tuned on the preview means the same thing here.
##
## Kept apart from axe_fire.gd on purpose: that one draws the fire that lives
## on the AXE, off the poses, and keeps its own older kit for it. Everything
## in here is fire that has LEFT the axe - the fissure, the fan, the landing,
## the chair - and runs on its own clock in a node of its own.
##
## Rounding is JavaScript's `Math.round` (half up), not `roundf` (half away
## from zero): the two disagree on every negative half, and most of these
## coordinates are negative, being drawn left of the boss.

const R := [Color("fff3b0"), Color("ffb63a"), Color("ff6a2a"), Color("c8301c"), Color("5a1a14")]
const STONE := [Color("8d939f"), Color("5f6472"), Color("3c414e")]
const SCORCH := Color("2a1210")


static func h(a: float, b: float = 0.0, c: float = 0.0) -> float:
	var x := sin(a * 127.1 + b * 311.7 + c * 74.7) * 43758.5453
	return x - floorf(x)


static func rnd(v: float) -> float:
	return floorf(v + 0.5)


static func eo(u: float) -> float:
	return 1.0 - (1.0 - u) * (1.0 - u)


static func ei(u: float) -> float:
	return u * u


static func io(u: float) -> float:
	return 2.0 * u * u if u < 0.5 else 1.0 - 2.0 * (1.0 - u) * (1.0 - u)


static func seg(t: float, a: float, b: float) -> float:
	return clampf((t - a) / (b - a), 0.0, 1.0)


static func px(ci: CanvasItem, x: float, y: float, col: Color) -> void:
	ci.draw_rect(Rect2(rnd(x), rnd(y), 1, 1), col)


## Every pixel between radius r0 and r1 of (cx, cy), coloured by `fn(x, y, d,
## a)` - its pixel, its distance and its angle - or skipped when that returns
## a transparent colour. x and y are absolute, so a noise seeded on them holds
## still while the shape grows.
static func disc(ci: CanvasItem, cx: float, cy: float, r0: float, r1: float, fn: Callable) -> void:
	cx = rnd(cx)
	cy = rnd(cy)
	var n := ceili(r1)
	for y in range(-n, n + 1):
		for x in range(-n, n + 1):
			var d := sqrt(float(x * x + y * y))
			if d < r0 or d >= r1:
				continue
			var col: Color = fn.call(cx + x, cy + y, d, atan2(float(y), float(x)))
			if col.a <= 0.0:
				continue
			ci.draw_rect(Rect2(cx + x, cy + y, 1, 1), col)


static func ellipse(ci: CanvasItem, x: float, y: float, rx: float, ry: float, col: Color) -> void:
	x = rnd(x)
	y = rnd(y)
	var nx := ceili(rx)
	var ny := ceili(ry)
	for j in range(-ny, ny + 1):
		for i in range(-nx, nx + 1):
			if (i * i) / (rx * rx) + (j * j) / (ry * ry) <= 1.0:
				ci.draw_rect(Rect2(x + i, y + j, 1, 1), col)


## One tongue of flame standing on (x, y): `hgt` tall, `w` either side of its
## centre at the base, swaying and reseeded twelve times a second.
static func flame(ci: CanvasItem, x: float, y: float, hgt: float, w: float, t: float, s: float) -> void:
	x = rnd(x)
	y = rnd(y)
	var n := int(rnd(hgt))
	if n < 1:
		return
	var tk := floorf(t * 12.0)
	for r in n:
		var f := float(r) / n
		var ww := int(rnd(w * (1.0 - f * f) * (0.65 + 0.5 * h(s, r, tk))))
		var sw := rnd((h(s, r >> 1, tk) - 0.5) * 2.0 * f * 1.6)
		for i in range(-ww, ww + 1):
			var e := absf(i) / ww if ww > 0 else 0.0
			if f > 0.85 and h(s, i, tk) > 0.5:
				continue
			px(ci, x + i + sw, y - r, R[mini(4, floori(f * 2.6 + e * 1.6))])


## A spray of `n` specks thrown from (x, y) at t0. `o` takes the preview's
## keys: spd, vz (up), g (gravity; above 0 they land and stay), life, a0/a1
## (the arc they fly in), flat (how much the floor foreshortens them), size,
## cols (the colours they age through).
static func parts(ci: CanvasItem, x: float, y: float, t: float, t0: float, n: int, seed: float, o: Dictionary) -> void:
	var dt := t - t0
	var life: float = o.get("life", 0.6)
	if dt < 0.0 or dt > life:
		return
	var a0: float = o.get("a0", 0.0)
	var a1: float = o.get("a1", TAU)
	var size: float = o.get("size", 1.0)
	var spd: float = o.get("spd", 30.0)
	var vz: float = o.get("vz", 0.0)
	var g: float = o.get("g", 0.0)
	var flat: float = o.get("flat", 0.6)
	var cols: Array = o.get("cols", R)
	for i in n:
		var li := life * (0.6 + 0.4 * h(seed, i, 3))
		if dt > li:
			continue
		var a := a0 + (a1 - a0) * h(seed, i, 1)
		var sp := spd * (0.3 + 0.7 * h(seed, i, 2))
		var gx := x + cos(a) * sp * dt
		var gy := y + sin(a) * sp * dt * flat
		var z := vz * (0.5 + 0.5 * h(seed, i, 4)) * dt - 0.5 * g * dt * dt
		if g > 0.0 and z < 0.0:
			z = 0.0
		var col: Color = cols[mini(cols.size() - 1, floori(dt / li * cols.size()))]
		ci.draw_rect(Rect2(rnd(gx), rnd(gy - z), size, size), col)


## The impact flash: a white cross with yellow tips and a short yellow X.
static func star(ci: CanvasItem, x: float, y: float, n: int) -> void:
	x = rnd(x)
	y = rnd(y)
	ci.draw_rect(Rect2(x - 1, y - 1, 3, 3), Color.WHITE)
	for i in range(2, n + 1):
		var col: Color = R[0] if i > n - 2 else Color.WHITE
		for d in [Vector2(i, 0), Vector2(-i, 0), Vector2(0, i), Vector2(0, -i)]:
			ci.draw_rect(Rect2(x + d.x, y + d.y, 1, 1), col)
	var k := int(rnd(n / 2.5))
	for i in range(2, k + 1):
		for d in [Vector2(i, i), Vector2(-i, -i), Vector2(i, -i), Vector2(-i, i)]:
			ci.draw_rect(Rect2(x + d.x, y + d.y, 1, 1), R[0])
