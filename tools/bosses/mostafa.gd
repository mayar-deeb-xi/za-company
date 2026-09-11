extends RefCounted
## Paints Mostafa's sheet from game/bosses/mostafa/poses.gd.
##
## Same contract as tools/bosses/ahmed.gd: this runs ONLY when
## game/bosses/mostafa/src/mostafa.png is missing. From then on the PNG is
## hand-owned art and build_bosses.gd only slices it. Delete the PNG to start
## his art over from here.
##
## Unlike Ahmed, whose body is one ASCII block with an arm and an axe drawn
## over it, Mostafa is drawn entirely from measurements: the torso tapers from
## SHOULDERS to the waist, the head is stacked rows, and each arm is two
## segments from a fixed shoulder to a posed elbow and glove. That is what let
## the style pass move him with sliders, and it is why every frame here is six
## numbers rather than a picture.
##
## Cells are 128 px, because he is drawn at 2x density. The canvas lands at a
## FIXED offset in the cell - never centred per frame - so the body does not
## jitter between frames of the same row.

const Poses := preload("res://game/bosses/mostafa/poses.gd")

## Where the working canvas sits inside the cell: CX -> 64, FOOT -> 112.
const AT := Vector2i(Poses.CELL / 2 - Poses.CX, 112 - Poses.FOOT)

const SH := (Poses.SHOULDERS - 1) / 2
const HH := (Poses.HEAD_W - 1) / 2
const WAIST := SH - Poses.TAPER
const LW := (Poses.LEG_W - 1) / 2

## The vertical stack now lives in the poses beside the measurements it comes
## from, so the shoulder line the arms hang off is one number the painter and
## the live effect both read. Aliased here only to keep the drawing below
## readable.
const BOOT_TOP := Poses.BOOT_TOP
const LEG_TOP := Poses.LEG_TOP
const SHORTS_BOT := Poses.SHORTS_BOT
const SHORTS_TOP := Poses.SHORTS_TOP
const BAND_TOP := Poses.BAND_TOP
const BAND_BOT := Poses.BAND_BOT
const TORSO_BOT := Poses.TORSO_BOT
const TORSO_TOP := Poses.TORSO_TOP
const NECK_TOP := Poses.NECK_TOP
const HEAD_BOT := Poses.HEAD_BOT
const HEAD_TOP := Poses.HEAD_TOP


static func paint() -> Image:
	var cols := 0
	for anim in Poses.ORDER:
		cols = maxi(cols, (Poses.ANIMS[anim] as Array).size())
	var img := Image.create(cols * Poses.CELL, Poses.ORDER.size() * Poses.CELL,
		false, Image.FORMAT_RGBA8)
	for row in Poses.ORDER.size():
		var anim: String = Poses.ORDER[row]
		var frames: Array = Poses.ANIMS[anim]
		for col in frames.size():
			_blit(img, _frame(frames[col]),
				Vector2i(col * Poses.CELL, row * Poses.CELL))
	return img


## One frame as {Vector2i -> palette key}, outlined.
static func _frame(f: Dictionary) -> Dictionary:
	var L := {}          # pixel -> key
	var layer := {}      # pixel -> layer, so an arm gets an edge over the chest
	var bx: int = f.get("dx", 0)
	var by: int = f.get("dy", 0)
	var hx: int = bx + f.get("hdx", 0)
	var hy: int = by + f.get("hdy", 0)

	_legs(L, layer, f, bx, by)
	_shorts(L, layer, bx, by)
	_torso(L, layer, bx, by)
	_head(L, layer, f, hx, hy)
	_arms(L, layer, f, bx, by)
	return _outline(L, layer)


static func _put(L: Dictionary, layer: Dictionary, x: int, y: int, ch: String, l: int) -> void:
	if x < 0 or y < 0 or x >= Poses.W or y >= Poses.H:
		return
	var p := Vector2i(x, y)
	if layer.has(p) and layer[p] > l:
		return
	L[p] = ch
	layer[p] = l


static func _box(L: Dictionary, layer: Dictionary, x0: int, x1: int, y0: int, y1: int,
		ch: String, l: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_put(L, layer, x, y, ch, l)


## Detail paint: only onto a pixel that is already body and not already outline.
static func _over(L: Dictionary, x: int, y: int, ch: String) -> void:
	var p := Vector2i(x, y)
	if L.has(p) and L[p] != "A":
		L[p] = ch


## A limb segment, thick, from a to b.
static func _limb(L: Dictionary, layer: Dictionary, x0: float, y0: float,
		x1: float, y1: float, th: float, ch: String, l: int) -> void:
	var dx := x1 - x0
	var dy := y1 - y0
	var length := maxf(sqrt(dx * dx + dy * dy), 1.0)
	var px := -dy / length
	var py := dx / length
	var n := ceili(length * 3.0) + 1
	for i in n + 1:
		var t := float(i) / n
		var cx := x0 + dx * t
		var cy := y0 + dy * t
		var o := -th
		while o <= th:
			_put(L, layer, floori(cx + px * o), floori(cy + py * o), ch, l)
			o += 0.34


## A round mass - the mitt, or a bare fist on the concede.
static func _disc(L: Dictionary, layer: Dictionary, cx: int, cy: int, r: float,
		l: int, ramp: Array) -> void:
	var rr := ceili(r) + 1
	for y in range(-rr, rr + 1):
		for x in range(-rr, rr + 1):
			var nx := x / r
			var ny := y / (r * 1.04)
			if nx * nx + ny * ny > 1.0:
				continue
			var t := (x - y) / (r * 1.414)
			var ch: String = ramp[2] if t > 0.5 else (ramp[0] if t < -0.45 else ramp[1])
			_put(L, layer, cx + x, cy + y, ch, l)


static func _legs(L: Dictionary, layer: Dictionary, f: Dictionary, bx: int, by: int) -> void:
	var offs: Array = f.get("legs", [0, 0])
	var stance: int = f.get("stance", 0)
	var cl := Poses.CX - WAIST + LW
	var centres := [[cl, int(offs[0])], [2 * Poses.CX - cl, int(offs[1])]]
	for pair in centres:
		var c: int = pair[0]
		var off: int = pair[1]
		var cc: int = c + bx + stance * (-1 if c < Poses.CX else 1)
		# The thigh stays pinned to the hip and STRETCHES. Translating the whole
		# leg detaches the boots from the shorts on any lifted frame.
		_box(L, layer, cc - LW, cc + LW, LEG_TOP + by, BOOT_TOP - 1 + by + off, "S", 1)
		_box(L, layer, cc - LW + 1, cc + LW - 1, BOOT_TOP + by + off,
			Poses.FOOT + mini(0, off), "B", 1)
		var lace := BOOT_TOP + 2 + by + off
		for x in range(cc - LW + 1, cc + LW):
			_over(L, x, lace, "L")
			_over(L, x, lace + 1, "L")


static func _shorts(L: Dictionary, layer: Dictionary, bx: int, by: int) -> void:
	_box(L, layer, Poses.CX - WAIST - 2 + bx, Poses.CX + WAIST + 2 + bx,
		SHORTS_TOP + by, SHORTS_BOT + by, "W", 1)
	_box(L, layer, Poses.CX - WAIST + bx, Poses.CX + WAIST + bx,
		BAND_TOP + by, BAND_BOT + by, "T", 1)
	for y in range(SHORTS_TOP + by, SHORTS_BOT + by + 1):
		_over(L, Poses.CX + bx, y, "w")
		_over(L, Poses.CX + bx + 1, y, "w")
	# the gap between the legs
	for x in range(Poses.CX - 2 + bx, Poses.CX + 3 + bx):
		var p := Vector2i(x, SHORTS_BOT + by)
		L.erase(p)
		layer.erase(p)


static func _torso(L: Dictionary, layer: Dictionary, bx: int, by: int) -> void:
	for r in Poses.TORSO:
		var t := float(r) / (Poses.TORSO - 1)
		var half := roundi(SH - Poses.TAPER * t)
		if r < 2:
			half -= 2
		_box(L, layer, Poses.CX - half + bx, Poses.CX + half + bx,
			TORSO_TOP + r + by, TORSO_TOP + r + by, "S", 1)
	# sternum, pec line, abs - the muscle pass the style review asked for
	for y in range(TORSO_TOP + 4 + by, TORSO_BOT + by + 1):
		_over(L, Poses.CX + bx, y, "s")
		_over(L, Poses.CX + bx + 1, y, "s")
	var pec := TORSO_TOP + roundi(Poses.TORSO * 0.45) + by
	var abs_y := TORSO_TOP + roundi(Poses.TORSO * 0.75) + by
	for d: int in range(6, 12):
		for sg: int in [-1, 1]:
			for yy: int in [pec, pec + 1, abs_y, abs_y + 1]:
				_over(L, Poses.CX + sg * d + bx, yy, "s")


static func _head(L: Dictionary, layer: Dictionary, f: Dictionary, hx: int, hy: int) -> void:
	_box(L, layer, Poses.CX - 5 + hx, Poses.CX + 5 + hx, NECK_TOP + hy, HEAD_BOT + 1 + hy, "S", 1)
	for r in Poses.HEAD_H:
		var half := HH
		if r < 2:
			half = HH - 4
		elif r < 4:
			half = HH - 2
		elif r >= Poses.HEAD_H - 2:
			half = HH - 2
		_box(L, layer, Poses.CX - half + hx, Poses.CX + half + hx,
			HEAD_TOP + r + hy, HEAD_TOP + r + hy, "K" if r < Poses.HAIR else "S", 1)
	var ht := HEAD_TOP + hy
	var hc := Poses.CX + hx
	for sg: int in [-1, 1]:
		_over(L, hc + sg * 5, ht + 4, "k")
		_over(L, hc + sg * 5, ht + 5, "k")
		_over(L, hc + sg * 4, ht + 4, "k")
		for i in 2:
			_over(L, hc + sg * (HH - 1 - i), ht + 8, "S")
			_over(L, hc + sg * (HH - 1 - i), ht + 9, "S")
		for i in 4:
			_over(L, hc + sg * (3 + i), ht + 10, "K")
			_over(L, hc + sg * (3 + i), ht + 11, "K")
	var blink := 1 if f.get("blink", false) else 0
	for sg: int in [-1, 1]:
		for i in 2:
			for j in 2 - blink:
				_over(L, hc + sg * (5 - i), ht + 12 + j, "E")
		for j in 2:
			_over(L, hc + sg * 3, ht + 12 + j, "A")
			_over(L, hc + sg * 2, ht + 12 + j, "A")
	for j in 2:
		_over(L, hc, ht + 15 + j, "s")
		_over(L, hc + 1, ht + 15 + j, "s")
	# beard: the jaw strap only, never the cheek
	for y in range(ht + 16, ht + Poses.HEAD_H - 2):
		for sg: int in [-1, 1]:
			_over(L, hc + sg * 6, y, "K")
			_over(L, hc + sg * 7, y, "K")
	for x in range(hc - HH + 2, hc + HH - 1):
		_over(L, x, ht + Poses.HEAD_H - 2, "K")
		_over(L, x, ht + Poses.HEAD_H - 1, "K")
	for x in range(hc - 2, hc + 3):
		_over(L, x, ht + Poses.HEAD_H - 3, "A")


static func _arms(L: Dictionary, layer: Dictionary, f: Dictionary, bx: int, by: int) -> void:
	var sh_y := Poses.SHOULDER + by
	for side: int in [-1, 1]:
		var a: Dictionary = f.get("R" if side > 0 else "L", {})
		if a.is_empty():
			continue
		var sx := Poses.CX + side * (SH - 3) + bx
		var ex: int = Poses.CX + bx + int(a["ex"])
		var ey: int = sh_y + int(a["ey"])
		var gx: int = Poses.CX + bx + int(a["gx"])
		var gy: int = sh_y + int(a["gy"])
		_limb(L, layer, sx, sh_y, ex, ey, 4.0, "S", 3)
		_limb(L, layer, ex, ey, gx, gy, 3.4, "S", 3)
		for y in range(sh_y, sh_y + 7):
			_over(L, sx + side * 2, y, "h" if side < 0 else "s")
		var gs: float = float(a.get("gs", (Poses.GLOVE - 1) / 2))
		if gs > 0.0:
			_limb(L, layer, gx - side, gy + 3, gx - side, gy + 5, 2.6, "W", 3)
			_disc(L, layer, gx, gy, gs, 4, ["r", "R", "R"])
			_over(L, gx - 2, gy - int(gs) + 2, "p")
			_over(L, gx - 1, gy - int(gs) + 1, "p")
		else:
			_disc(L, layer, gx, gy, 3.2, 4, ["s", "S", "h"])


## A filled pixel becomes outline where a 4-neighbour is empty or on a LOWER
## layer, then the whole silhouette gets its contour. Same rule as Ahmed's.
static func _outline(L: Dictionary, layer: Dictionary) -> Dictionary:
	var edged := {}
	for p in L:
		var is_edge := false
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = p + d
			if not L.has(n) or layer.get(n, 0) < layer.get(p, 0):
				is_edge = true
				break
		edged[p] = "A" if is_edge else L[p]
	var out := edged.duplicate()
	for p in edged:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = p + d
			if not edged.has(n):
				out[n] = "A"
	return out


static func _blit(img: Image, cells: Dictionary, at: Vector2i) -> void:
	var clipped := 0
	for p in cells:
		var q: Vector2i = p + AT + at
		if q.x < at.x or q.y < at.y or q.x >= at.x + Poses.CELL or q.y >= at.y + Poses.CELL:
			clipped += 1
			continue
		if q.x < 0 or q.y < 0 or q.x >= img.get_width() or q.y >= img.get_height():
			clipped += 1
			continue
		img.set_pixelv(q, Color(Poses.PAL[cells[p]]))
	if clipped > 0:
		printerr("  %d pixels fall outside the %dpx cell" % [clipped, Poses.CELL])
