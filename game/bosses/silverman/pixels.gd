extends RefCounted
## One-pixel drawing for Silverman's live effects - the dot, the stepped line,
## the ellipse and the disc both glare.gd and prism.gd are drawn in.
##
## It is here and not in either of them because the second effect wanted the
## first's exact pixels: both were picked off an attack preview that drew with
## these four routines, and shipping a preview verbatim means drawing the way
## it drew. Static, and handed the CanvasItem to draw on, so it can only ever
## be called from inside that item's own `_draw()`.
##
## His alone, like everything else in this folder: Big Mo's brush.gd draws
## fire, and nothing about the ART is shared between bosses.

## Below this an alpha is not worth a draw call.
const FAINT := 0.03


static func px(ci: CanvasItem, at: Vector2, col: Color, alpha: float) -> void:
	if alpha <= FAINT:
		return
	ci.draw_rect(Rect2(at.round(), Vector2.ONE), Color(col, alpha))


## Bresenham, and dotted when `dot` is set: `ceil(dot / 2)` on, the rest off,
## scrolled by `phase`.
static func line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, alpha: float,
		dot := 0, phase := 0.0) -> void:
	if alpha <= FAINT:
		return
	var c := Color(col, alpha)
	var x0 := roundi(a.x)
	var y0 := roundi(a.y)
	var x1 := roundi(b.x)
	var y1 := roundi(b.y)
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	var n := 0
	var on := ceili(dot / 2.0)
	var shift := floori(phase)
	for _guard in 2000:
		if dot == 0 or posmod(n + shift, dot) < on:
			ci.draw_rect(Rect2(x0, y0, 1, 1), c)
		n += 1
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


static func ring(ci: CanvasItem, at: Vector2, rx: float, ry: float, col: Color,
		alpha: float) -> void:
	if rx < 0.5 or alpha <= FAINT:
		return
	var c := Color(col, alpha)
	var steps := maxi(12, ceili((rx + ry) * 3.0))
	var seen := {}
	for i in steps:
		var th := TAU * float(i) / float(steps)
		var p := (at + Vector2(cos(th) * rx, sin(th) * ry)).round()
		if seen.has(p):
			continue
		seen[p] = true
		ci.draw_rect(Rect2(p, Vector2.ONE), c)


static func disc(ci: CanvasItem, at: Vector2, r: float, col: Color, alpha: float) -> void:
	if alpha <= FAINT:
		return
	var c := Color(col, alpha)
	var ri := int(r)
	var centre := at.round()
	for y in range(-ri, ri + 1):
		var w := floori(sqrt(float(ri * ri - y * y)))
		ci.draw_rect(Rect2(centre.x - w, centre.y + y, w * 2 + 1, 1), c)
