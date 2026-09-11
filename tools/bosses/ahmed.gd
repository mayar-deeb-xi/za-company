extends RefCounted
## Paints Ahmed's sheet - body, arm and axe for every frame of every animation
## - from the poses in game/bosses/ahmed/poses.gd. The fire is deliberately
## NOT here: it is drawn live by axe_fire.gd from the same poses, so the sheet
## stays a clean body to hand-draw into.
##
## Run through tools/build_bosses.gd, and only when the PNG is missing: from
## then on the sheet is hand-owned art (see build_bosses.gd).
##
## Cells are 64 px. The body is centred in its cell horizontally so that a
## flipped frame stays where it was, and its feet stand on row 56, which is
## what the scene's sprite offset of -24 puts on the boss's origin.

const Poses := preload("res://game/bosses/ahmed/poses.gd")

const CELL := 64
## Widest animation is nine frames; every row is padded to it.
const COLS := 9
## Body column 0, row 0 in cell pixels.
const BODY_AT := Vector2i(25, 22)


static func paint() -> Image:
	var rows := Poses.ORDER.size()
	var img := Image.create(COLS * CELL, rows * CELL, false, Image.FORMAT_RGBA8)
	for row in rows:
		var anim: String = Poses.ORDER[row]
		var frames: Array = Poses.ANIMS[anim]
		for col in frames.size():
			_blit(img, _frame(frames[col]), Vector2i(col * CELL, row * CELL), anim, col)
	return img


## One frame as a dictionary of body-space pixel -> palette key, outlined.
## `dy` lowers the BODY onto its legs; the legs themselves stand on row 34
## whatever it is, so a leg variant's row count is the drop it pairs with
## (dy = 7 - rows) and the two always meet. `lift` is the other thing - both
## feet leaving the ground - and moves body and legs together.
static func _frame(f: Dictionary) -> Dictionary:
	var L := {}
	var lift: int = f.get("lift", 0)
	var off := Vector2i(f.get("dx", 0), f.get("dy", 0) + lift)
	var axe: Dictionary = f.get("axe", {})
	var arms: Array = f.get("arms", [])
	if not axe.is_empty() and axe.get("behind", false):
		_axe(L, axe)
	for a in arms:
		if a.get("behind", false):
			_arm(L, _shoulder(a, off), a["hand"], a["bend"])
	_stamp(L, Poses.TOP, off)
	var legs: Array = Poses.LEGS[f.get("legs", "stand")]
	_stamp(L, legs, Vector2i(off.x, 35 - legs.size() + lift))
	for a in arms:
		if not a.get("behind", false):
			_arm(L, _shoulder(a, off), a["hand"], a["bend"])
	if not axe.is_empty() and not axe.get("behind", false):
		_axe(L, axe)
	return _outline(L)


static func _shoulder(a: Dictionary, off: Vector2i) -> Vector2i:
	var s: Vector2i = Poses.BACK_SHOULDER if a["sh"] == "back" else Poses.FRONT_SHOULDER
	return s + off


static func _put(L: Dictionary, x: float, y: float, ch: String) -> void:
	L[Vector2i(floori(x), floori(y))] = ch


static func _stamp(L: Dictionary, rows: Array, off: Vector2i) -> void:
	for r in rows.size():
		var row: String = rows[r]
		for c in row.length():
			if row[c] != ".":
				_put(L, off.x + c, off.y + r, row[c])


static func _thick_line(L: Dictionary, x0: float, y0: float, x1: float, y1: float,
		ch: String, thick: int, shade := "") -> void:
	var dx := x1 - x0
	var dy := y1 - y0
	var len := maxf(sqrt(dx * dx + dy * dy), 1.0)
	var px := -dy / len
	var py := dx / len
	var n := ceili(len * 2.0) + 1
	for i in n + 1:
		var t := float(i) / float(n)
		var x := x0 + dx * t
		var y := y0 + dy * t
		for k in thick:
			var off := float(k) - float(thick - 1) / 2.0
			var c := shade if (shade != "" and k == thick - 1) else ch
			_put(L, x + px * off + 0.5, y + py * off + 0.5, c)


## One pixel of sleeve, one of forearm, a two-pixel fist. Skinny on purpose.
static func _arm(L: Dictionary, sh: Vector2i, hand: Vector2i, bend: float) -> void:
	var mx := (sh.x + hand.x) / 2.0
	var my := (sh.y + hand.y) / 2.0
	var dx := float(hand.x - sh.x)
	var dy := float(hand.y - sh.y)
	var len := maxf(sqrt(dx * dx + dy * dy), 1.0)
	var ex := mx - dy / len * bend
	var ey := my + dx / len * bend
	_thick_line(L, sh.x, sh.y, ex, ey, "W", 1)
	_thick_line(L, ex, ey, hand.x, hand.y, "s", 1)
	for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		_put(L, hand.x + d.x, hand.y + d.y, "t")


static func _inside(poly: Array, u: float, v: float) -> bool:
	var c := false
	var j := poly.size() - 1
	for i in poly.size():
		var xi: float = poly[i][0]
		var yi: float = poly[i][1]
		var xj: float = poly[j][0]
		var yj: float = poly[j][1]
		if ((yi > v) != (yj > v)) and (u < (xj - xi) * (v - yi) / (yj - yi) + xi):
			c = not c
		j = i
	return c


## Haft as a two-pixel line with a shaded edge, head as a wedge rasterised in
## the haft's own frame so it turns with the swing.
static func _axe(L: Dictionary, axe: Dictionary) -> void:
	var hand: Vector2i = axe["hand"]
	var len: float = axe["len"]
	var blade: float = axe.get("blade", 1)
	var a: float = deg_to_rad(axe["ang"])
	var ux := cos(a)
	var uy := sin(a)
	var vx := -uy * blade
	var vy := ux * blade
	var hx := hand.x + 1.0
	var hy := hand.y + 1.0
	_thick_line(L, hx - ux * 3.0, hy - uy * 3.0, hx + ux * (len + 1.0), hy + uy * (len + 1.0), "O", 2, "o")
	var head := [[len - 2, -1.5], [len + 2, -1.5], [len + 2, 0], [len + 2.5, 2], [len + 4.5, 7.5],
		[len - 5, 7.5], [len - 2.5, 2], [len - 2, 0]]
	var poll := [[len - 1.5, -3.5], [len + 1.5, -3.5], [len + 1.5, -1.5], [len - 1.5, -1.5]]
	var reach := int(len) + 10
	for y in range(int(hy) - reach, int(hy) + reach + 1):
		for x in range(int(hx) - reach, int(hx) + reach + 1):
			var cx := x + 0.5 - hx
			var cy := y + 0.5 - hy
			var u := cx * ux + cy * uy
			var v := cx * vx + cy * vy
			if _inside(head, u, v):
				_put(L, x, y, "X" if v > 6.3 else ("a" if v < 1.5 else "A"))
			elif _inside(poll, u, v):
				_put(L, x, y, "a")


## Every empty pixel touching a coloured one becomes outline, which is how the
## arm and axe get theirs; the body's ASCII already carries its own.
static func _outline(L: Dictionary) -> Dictionary:
	var out := L.duplicate()
	for p in L:
		if L[p] == "#":
			continue
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = p + d
			if not L.has(n):
				out[n] = "#"
	return out


static func _blit(img: Image, L: Dictionary, origin: Vector2i, anim: String, col: int) -> void:
	var clipped := 0
	for p in L:
		var at: Vector2i = BODY_AT + p
		if at.x < 0 or at.y < 0 or at.x >= CELL or at.y >= CELL:
			clipped += 1
			continue
		img.set_pixelv(origin + at, Color.html(Poses.PAL[L[p]]))
	if clipped > 0:
		printerr("  %s frame %d: %d pixels fall outside the 64px cell" % [anim, col, clipped])
