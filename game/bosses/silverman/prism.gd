extends Node2D
## THE PRISM - the city's light, taken in off the window and swept across the
## room as one white beam.
##
## Picked from the attack preview with one change asked for on the way in: the
## preview split the beam into a rainbow at its edges, and it ships WHITE. That
## is the better answer for him anyway - he is six exact greys and the city
## outside the glass is the only coloured thing in the room, so the light
## stays hueless the moment it is his. Everything else here is the preview's
## drawing, number for number.
##
## Three parts, one script, chosen by `part`, split by SPACE like glare.gd:
##
## - **floor** sits under the body at z 0: the fan, which is the telegraph and
##   the whole fairness of the attack - for the full second of the wind-up it
##   shows exactly the arc the beam will sweep, dithered over the floor - plus
##   the dotted line the sweep starts on and three motes running the way it
##   will turn. z 0 and not below, because the level's Floor tilemap is at 0
##   and a negative z draws under it (game/enemies/slam_ring.gd's lesson).
## - **air** draws above everything standing in the room (z 1): the light
##   being pulled in off the window, the point gathering on his chest, and the
##   beam itself with its afterimage and the sparks where it meets the wall.
## - **screen** hangs off his CanvasLayer at layer 1, under the HUD: one white
##   flash as it fires.
##
## Nothing tells any part anything. Each walks up to the `bosses` group, reads
## the sprite's animation, frame and progress against poses.gd, and asks the
## boss for the arc (`prism_from`, `prism_span`, `prism_angle()`) and for
## where the walls stop it (`prism_length()`) - the same function his hitbox
## measures with, so the beam you see is the beam that hits.

const Poses := preload("res://game/bosses/silverman/poses.gd")
const Silverman := preload("res://game/bosses/silverman/silverman.gd")

@export_enum("floor", "air", "screen") var part := "floor"

## His ramp. The prism is made of nothing else.
const W := Color("eef4fb")
const L := Color("c3ccd8")
const S := Color("8c97a8")

## The preview's own numbers.
## Light pulled in off the window: five threads, 44 px apart, from 70 px over
## his feet - the window's base, measured on the penthouse - to his chest.
const THREADS := 5
const THREAD_GAP := 44.0
const THREAD_FROM := -70.0
const THREAD_COLOURS := [W, L, W, L, W]
## The fan's ring: nothing inside 14 px, nothing past 175, and the dither's
## own alpha (150 of 255) under the fade it is drawn at.
const FAN_INNER := 14.0
const FAN_OUTER := 175.0
const FAN_SEGMENTS := 40
const FAN_INK := 150.0 / 255.0
const FAN_WINDUP := 0.55
const FAN_SWEEP := 0.22
## The dotted line the sweep starts on, and the motes that say which way.
const START_FROM := 10.0
const START_TO := 170.0
const MOTE_R := 30.0
## The beam: nine one-pixel lanes either side of a white core, outermost
## first so the core is drawn last and sits on top. Offsets across the beam.
const LANES := [[-4, S], [-3, L], [-2, W], [2, W], [3, L], [4, S], [-1, L], [1, L], [0, W]]
## The afterimage: the beam where it was, a sixtieth of a second apart.
const TRAIL := 11
const TRAIL_STEP := 1.0 / 60.0
## The flash as it fires.
const FLASH := 0.3
const FLASH_SECONDS := 0.16
const FAINT := 0.03

var _boss: Node2D
var _sprite: AnimatedSprite2D
## The fan for the cast it was built for, rebuilt when `prism_casts` moves.
var _fan_cast := -1
var _fan := PackedVector2Array()
var _fan_uv := PackedVector2Array()
## Sparks where the beam meets the wall: [position, velocity, life].
var _sparks: Array = []
var _checker: ImageTexture


func _ready() -> void:
	var node: Node = self
	while node != null and not node.is_in_group("bosses"):
		node = node.get_parent()
	_boss = node as Node2D
	if _boss != null:
		_sprite = _boss.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if part == "air":
		z_index = 1
	# The fan is a polygon textured with a 2x2 checker, repeated: one texel per
	# world pixel, so the dither lands on the room's own pixel grid.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	set_process(_sprite != null)


func _process(delta: float) -> void:
	if part == "air":
		_tick_sparks(delta)
	queue_redraw()


## Seconds into the prism animation, or -1 when he is not casting one. Off the
## same `dur` list the boss takes his wind-up and recover from, like glare.gd.
func _into() -> float:
	if String(_sprite.animation).trim_suffix("_side") != "prism":
		return -1.0
	var frames: Array = Poses.ANIMS["prism"]
	var idx := clampi(_sprite.frame, 0, frames.size() - 1)
	return Poses.into("prism", idx) \
		+ clampf(_sprite.frame_progress, 0.0, 1.0) * float(frames[idx]["dur"])


func _draw() -> void:
	if _sprite == null or _boss == null:
		return
	var t := _into()
	if t < 0.0:
		return
	var since := t - Poses.windup_of("prism")
	match part:
		"floor":
			_draw_floor(t, since)
		"air":
			_draw_air(t, since)
		"screen":
			if since >= 0.0 and since < FLASH_SECONDS:
				var alpha := FLASH * (1.0 - since / FLASH_SECONDS)
				draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(W, alpha))


# --- floor: the telegraph -----------------------------------------------------


func _draw_floor(t: float, since: float) -> void:
	var sweep := Silverman.PRISM_SWEEP
	if t < 0.25 or since >= sweep:
		return
	if int(_boss.get("prism_casts")) != _fan_cast:
		_build_fan()
	var fade := FAN_WINDUP * clampf((t - 0.25) / 0.2, 0.0, 1.0) if since < 0.0 else FAN_SWEEP
	if _fan.size() >= 3:
		draw_colored_polygon(_fan, Color(W, FAN_INK * fade), _fan_uv, _checker_texture())
	var chest := Silverman.PRISM_CHEST
	var from := float(_boss.get("prism_from"))
	var span := float(_boss.get("prism_span"))
	if since < 0.0:
		var dir := Vector2.from_angle(from)
		var reach := minf(START_TO, float(_boss.call("prism_length", from)))
		_line(chest + dir * START_FROM, chest + dir * reach, W, 0.55, 3, -t * 30.0)
		for k in 3:
			var f := fmod(t * 1.2 + float(k) / 3.0, 1.0)
			var a := from + span * f
			for r in [MOTE_R, MOTE_R + 1.0]:
				_px(chest + Vector2.from_angle(a) * r, W, 0.8 * sin(f * PI))
	_ring(Vector2.ZERO, 10.0 + sin(t * 20.0), 4.0, L, 0.3)


## The fan as a polygon: the arc out to the wall (or FAN_OUTER, whichever is
## nearer) and back along the inner ring. UVs are world pixels over the 2x2
## checker, so the dither keeps to the room's grid wherever he stands.
func _build_fan() -> void:
	_fan_cast = int(_boss.get("prism_casts"))
	var chest := Silverman.PRISM_CHEST
	var from := float(_boss.get("prism_from"))
	var span := float(_boss.get("prism_span"))
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in FAN_SEGMENTS + 1:
		var a := from + span * float(i) / float(FAN_SEGMENTS)
		var dir := Vector2.from_angle(a)
		var r := maxf(minf(FAN_OUTER, float(_boss.call("prism_length", a))), FAN_INNER + 1.0)
		outer.append(chest + dir * r)
		inner.append(chest + dir * FAN_INNER)
	inner.reverse()
	_fan = outer + inner
	_fan_uv = PackedVector2Array()
	for p in _fan:
		_fan_uv.append((_boss.global_position + p).round() * 0.5)


func _checker_texture() -> ImageTexture:
	if _checker == null:
		var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		img.set_pixel(0, 0, Color.WHITE)
		img.set_pixel(1, 1, Color.WHITE)
		_checker = ImageTexture.create_from_image(img)
	return _checker


# --- air: the light -----------------------------------------------------------


func _draw_air(t: float, since: float) -> void:
	var chest := Silverman.PRISM_CHEST
	var sweep := Silverman.PRISM_SWEEP
	var windup := Poses.windup_of("prism")
	var charge := clampf(t / windup, 0.0, 1.0) if since < 0.0 \
		else 1.0 - clampf(since / 0.2, 0.0, 1.0)
	if charge > 0.0:
		for k in THREADS:
			var from := Vector2((float(k) - 2.0) * THREAD_GAP, THREAD_FROM)
			_line(from, chest, THREAD_COLOURS[k],
				0.38 * charge * (0.7 + 0.3 * sin(t * 30.0 + float(k))), 2, t * 20.0)
	if since < sweep:
		var r := roundf(3.0 * clampf(t / windup, 0.0, 1.0)) if since < 0.0 else 3.0
		_disc(chest, r, W, 1.0)
		_ring(chest, r + 2.0, r + 2.0, L, 0.5)
	if since < 0.0 or since >= sweep:
		return
	for i in range(1, TRAIL + 1):
		var back := since - float(i) * TRAIL_STEP
		if back < 0.0:
			break
		var ghost := _beam(float(_boss.call("prism_angle", back)))
		_line(ghost[0], ghost[1], W, 0.16 * (1.0 - float(i) / 12.0))
	var a := float(_boss.call("prism_angle", since))
	var seg := _beam(a)
	var across := Vector2(-sin(a), cos(a))
	var flicker := 0.65 + 0.35 * sin(t * 50.0)
	for lane in LANES:
		var off := across * float(lane[0])
		_line(seg[0] + off, seg[1] + off, lane[1], 0.8 * flicker if absi(lane[0]) > 1 else 1.0)
	_disc(seg[1], 2.0, W, flicker)
	for s in _sparks:
		_px(s[0], s[3], minf(1.0, s[2] / 0.35 * 1.5))


## The boss's beam segment, in this node's space.
func _beam(angle: float) -> PackedVector2Array:
	var seg: PackedVector2Array = _boss.call("prism_beam", angle)
	return PackedVector2Array([seg[0] - _boss.global_position, seg[1] - _boss.global_position])


## Two sparks a frame off the wall while the beam is on it, each living a
## fraction of a second. Kept here rather than as nodes: they are pixels.
func _tick_sparks(delta: float) -> void:
	for s in _sparks:
		s[0] += s[1] * delta
		s[2] -= delta
	_sparks = _sparks.filter(func(s: Array) -> bool: return s[2] > 0.0)
	var t := _into()
	if t < 0.0:
		return
	var since := t - Poses.windup_of("prism")
	if since < 0.0 or since >= Silverman.PRISM_SWEEP:
		return
	var end := _beam(float(_boss.call("prism_angle", since)))[1]
	for i in 2:
		_sparks.append([end, Vector2(randf_range(-50, 50), randf_range(-50, 50)),
			randf_range(0.15, 0.35), [W, W, L, S].pick_random()])


# --- pixels -------------------------------------------------------------------


func _px(at: Vector2, col: Color, alpha: float) -> void:
	if alpha <= FAINT:
		return
	draw_rect(Rect2(at.round(), Vector2.ONE), Color(col, alpha))


## A one-pixel line, stepped like the preview's: Bresenham, and dotted when
## `dot` is set - `ceil(dot / 2)` on, the rest off, scrolled by `phase`.
func _line(a: Vector2, b: Vector2, col: Color, alpha: float, dot := 0, phase := 0.0) -> void:
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
			draw_rect(Rect2(x0, y0, 1, 1), c)
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


func _ring(at: Vector2, rx: float, ry: float, col: Color, alpha: float) -> void:
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
		draw_rect(Rect2(p, Vector2.ONE), c)


func _disc(at: Vector2, r: float, col: Color, alpha: float) -> void:
	if alpha <= FAINT:
		return
	var c := Color(col, alpha)
	var ri := int(r)
	var centre := at.round()
	for y in range(-ri, ri + 1):
		var w := floori(sqrt(float(ri * ri - y * y)))
		draw_rect(Rect2(centre.x - w, centre.y + y, w * 2 + 1, 1), c)
