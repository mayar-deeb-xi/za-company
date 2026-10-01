extends Node2D
## THE GLARE - the penthouse turned into a weapon, and the announcement that a
## phase has changed.
##
## He is a man made of mirror standing in a room that is glass on one side. The
## glare is him using it: he draws his own shine inward over the wind-up (the
## `dull` steps on the `glare` row - that dimming is the telegraph, and it is
## on the sheet because his resting rung is already the brightest he gets), and
## then spends the lot at once. The room whites out and the light leaves him
## as a CROSS: a band along the floor the way he faces, and two shorter arms
## straight up and down.
##
## **The look and the cross were picked off the glare preview** ("Mirror
## flash" for the look, "Crossfire" for the shape) and are its drawing shipped
## number for number: light spiralling into him while he dims, a four-point
## star off his chest and his whole body flashing white as it fires, each arm
## a wall of light with a dithered wake, flare spikes either side of it and
## dust kicked off its front, sparks where each arm runs out.
##
## Three parts, one script, chosen by `part`, split by SPACE the way Ahmed's
## axe_fire.gd and Mostafa's bell.gd are:
##
## - **band** sits under the body at z 0: the walls of light crossing the room
##   and the floor brightening under him as he loads. WORLD pixels. z 0 rather
##   than below, because the level's Floor tilemap is at 0.
## - **air** draws over everything standing in the room (z 1): the light
##   spiralling in, the star, the white flash of his body, and the dust and
##   sparks. The flash is the `flash` row on his sheet - his impact pose with
##   every pixel his brightest rung - because a white-out is a picture, and a
##   modulate can only darken.
## - **screen** hangs off a CanvasLayer: the wash, the vignette and the flash.
##   VIEWPORT pixels, because the edge of the screen is not a place in the
##   room. That layer sits BELOW the HUD - a white-out that takes his own
##   health bar with it hides the one number the player is reading while it
##   lands. Unchanged by the preview: it already drew what the preview drew.
##
## Nothing tells any of them anything. Each walks up to the `bosses` group,
## reads the sprite's animation, frame and progress, and draws off poses.gd -
## so a reworded pose moves its light with it and no timing here can disagree
## with the telegraph it is drawing.
##
## **Every arm draws exactly its hitbox.** The band's front is the boss's own
## `glare_front()` and the arms' is `glare_arm_front()`, the same functions his
## Area2Ds are moved with, and every wall is the lane's 20 px. A sweep you can
## step out of has to be a sweep you can SEE the edges of.
##
## The whole thing is hueless, like him. There is no hue anywhere in his
## palette and the city outside the glass is the only coloured thing in the
## room - which is what makes the room going white read as HIM rather than as
## a fire somewhere.

const Poses := preload("res://game/bosses/silverman/poses.gd")
const Silverman := preload("res://game/bosses/silverman/silverman.gd")
const Px := preload("res://game/bosses/silverman/pixels.gd")

@export_enum("band", "air", "screen") var part := "band"

## His ramp. The glare is made of nothing else.
const W := Color(238.0 / 255.0, 244.0 / 255.0, 251.0 / 255.0)
const L := Color(195.0 / 255.0, 204.0 / 255.0, 216.0 / 255.0)
const S := Color(140.0 / 255.0, 151.0 / 255.0, 168.0 / 255.0)

## Below this an alpha is not worth a draw call.
const FAINT := 0.03

## Where the star and the gathering light sit - his chest - and the floor's
## own squash for the burst rings, since a circle on a floor seen from a
## slight elevation is an ellipse. The same 0.4 Ahmed's rings are drawn on.
const CHEST := Vector2(0.0, -20.0)
const RING_AT := Vector2(0.0, -10.0)
const SQUASH := 0.4

## A wall of light, as previewed: half the lane either side of its centre
## line, a wake of 28 px behind the front, and four pixels of flare spike
## beyond each edge.
const HALF := 10
const WAKE := 28
const SPIKE := 4
## The light spiralling in over the wind-up.
const MOTES := 16
const MOTE_FROM := 42.0
## The white flash of his body, and the star, after the light lands.
const WHITE_SECONDS := 0.15
const STAR_SECONDS := 0.22

## The screen: how white it gets while he loads, the flash on the frame it
## lands, and how long that flash holds.
const WASH_MAX := 0.34
const FLASH := 0.5
const FLASH_SECONDS := 0.12
## One CHUNKth of the frame's width - about 7 px at the 640x360 base viewport.
## The vignette is furniture of the FRAME, so it is sized as a fraction of the
## frame: in world pixels it would be invisible at 640 across and would change
## size with the zoom, which is the one thing something pinned to the edge of
## the screen must never do.
const CHUNK := 96.0

var _boss: Node2D
var _sprite: AnimatedSprite2D
var _flip := false
## Dust and sparks, air part only: [position, velocity, life, max, colour].
var _sparks: Array = []
## Seconds since the light landed on the last frame drawn, so the air part can
## tell the frame it fired, and the frame the arms ran out, from the rest.
var _last_since := -INF


func _ready() -> void:
	# Walked rather than reached for by path: the screen part hangs off a
	# CanvasLayer, so its parent is not the boss the band sits under.
	var node: Node = self
	while node != null and not node.is_in_group("bosses"):
		node = node.get_parent()
	_boss = node as Node2D
	if _boss != null:
		_sprite = _boss.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if part == "air":
		z_index = 1
	set_process(_sprite != null)


func _process(delta: float) -> void:
	if part == "air":
		_tick_sparks(delta)
	queue_redraw()


## Seconds into the glare animation, or -INF when he is not glaring. Off the
## same `dur` list the boss derives windup_seconds from.
func _into() -> float:
	if String(_sprite.animation).trim_suffix("_side") != "glare":
		return -INF
	var frames: Array = Poses.ANIMS["glare"]
	var idx := clampi(_sprite.frame, 0, frames.size() - 1)
	return Poses.into("glare", idx) \
		+ clampf(_sprite.frame_progress, 0.0, 1.0) * float(frames[idx]["dur"])


func _draw() -> void:
	if _sprite == null or _boss == null:
		return
	_flip = _sprite.flip_h
	var herald := float(_boss.get("herald"))
	var t := _into()
	if t == -INF:
		# A phase arriving is the one thing this draws while he is not
		# glaring: he has no cuffs to adjust, so he spends a rung of his own
		# shine on the room instead. Only the screen carries it - light
		# crossing the floor would read as an attack nobody threw.
		if part == "screen" and herald > 0.0:
			_draw_herald(herald)
		if part == "air":
			_draw_sparks()
		return
	var windup := Poses.windup_of("glare")
	var since := t - windup
	var loading := clampf(t / maxf(windup, 0.001), 0.0, 1.0)
	match part:
		"band":
			_draw_band(t, since, loading)
		"air":
			_draw_air(t, since, loading)
		"screen":
			_draw_screen(since, loading, herald)


# --- the cross -----------------------------------------------------------------


## The three arms in this node's space: the band the way he faces, and the
## two arms straight up and down. `main` is the band, the one lying along the
## floor, which is the one that throws a reflection on it.
func _arms(since: float) -> Array:
	var face := -1.0 if _flip else 1.0
	var band := float(_boss.call("glare_front", since))
	var arm := float(_boss.call("glare_arm_front", since))
	return [
		{"dir": Vector2(face, 0.0), "front": band, "reach": Silverman.GLARE_REACH, "main": true},
		{"dir": Vector2(0.0, -1.0), "front": arm, "reach": Silverman.GLARE_ARM, "main": false},
		{"dir": Vector2(0.0, 1.0), "front": arm, "reach": Silverman.GLARE_ARM, "main": false},
	]


## A point `along` an arm and `perp` across it, in this node's space.
static func _at(dir: Vector2, along: float, perp: float) -> Vector2:
	return Vector2(0.0, Silverman.GLARE_LANE_Y) + dir * along + Vector2(-dir.y, dir.x) * perp


## The room's own pixel parity, so a dither lands on the floor's grid wherever
## he is standing.
func _even(local: Vector2) -> bool:
	var p := (_boss.global_position + local).round()
	return posmod(int(p.x) + int(p.y), 2) == 0


# --- band: the room ----------------------------------------------------------


func _draw_band(t: float, since: float, loading: float) -> void:
	if since < 0.0:
		# Loading: the floor under him brightens, dithered, and that is all.
		# The arms do not exist yet, and a telegraph that drew where they will
		# land would give the whole cross away - his dimming is the warning.
		for y in range(-2, 3):
			var w := roundi((12.0 + 6.0 * loading) * sqrt(1.0 - pow(y / 3.0, 2.0)))
			for x in range(-w, w + 1):
				if posmod(x + y, 2) == 0:
					Px.px(self, Vector2(x, y), L, 0.12 + 0.3 * loading)
		return
	# THE BURST OFF HIM, which is `_flash_at_source()` drawn: anyone inside his
	# own reach when he spends his shine takes it, whatever line they are on.
	if since < FLASH_SECONDS:
		var k := since / FLASH_SECONDS
		var r := 4.0 + 26.0 * k
		Px.ring(self, RING_AT, r, r * SQUASH, W, 1.0 - k)
		r = 2.0 + 18.0 * k
		Px.ring(self, RING_AT, r, r * SQUASH, L, (1.0 - k) * 0.7)
	var travel := Poses.recover_of("glare")
	if since > travel:
		return
	var fade := 1.0 - clampf(since / maxf(travel, 0.001), 0.0, 1.0)
	for arm in _arms(since):
		_wall(arm, fade, t)


## One wall of light along one arm: the dithered wake behind the front, the
## front itself two pixels deep, the flare spikes beyond each edge, a faint
## streak down the middle of the lane, and - for the band along the floor -
## its reflection running along the floor line.
func _wall(arm: Dictionary, fade: float, t: float) -> void:
	var dir: Vector2 = arm["dir"]
	var front: float = arm["front"]
	var reach: float = arm["reach"]
	for dd in range(1, WAKE + 1):
		var a := front - float(dd)
		if a <= 0.0 or a > reach + 2.0:
			continue
		var col := W if dd < 6 else (L if dd < 14 else S)
		var alpha := (1.0 - float(dd) / float(WAKE)) * 0.7 * maxf(fade, 0.25)
		if alpha <= FAINT:
			continue
		for pp in range(-HALF, HALF):
			var p := _at(dir, a, pp)
			if _even(p):
				Px.px(self, p, col, alpha)
	for pp in range(-HALF, HALF):
		Px.px(self, _at(dir, front, pp), W, 0.95)
		Px.px(self, _at(dir, front - 1.0, pp), W, 0.65)
	var flicker := 0.6 + 0.4 * sin(t * 60.0)
	for k in range(1, SPIKE + 1):
		var alpha := (1.0 - k / 5.0) * flicker
		Px.px(self, _at(dir, front, -HALF - k), W, alpha)
		Px.px(self, _at(dir, front, HALF - 1 + k), W, alpha)
	var start := Silverman.GLARE_START
	Px.line(self, _at(dir, start, 0.0), _at(dir, front, 0.0), L, 0.18 * fade)
	if arm["main"]:
		var floor_line := Vector2(0.0, 1.0)
		Px.line(self, _at(dir, start, HALF) + floor_line, _at(dir, front, HALF) + floor_line,
			S, 0.35 * maxf(fade, 0.3))
		Px.line(self, _at(dir, maxf(start, front - 10.0), HALF) + floor_line,
			_at(dir, front, HALF) + floor_line, W, 0.6)


# --- air: over the body ---------------------------------------------------------


func _draw_air(t: float, since: float, loading: float) -> void:
	if since < 0.0:
		# The light coming in: motes spiralling onto his chest, faster and
		# brighter as he loads, and a point gathering where they land.
		for i in MOTES:
			var f := fmod(t * 1.4 + float(i) / MOTES, 1.0)
			var a := float(i) / MOTES * TAU + t * 2.2
			var r := MOTE_FROM * (1.0 - f)
			Px.px(self, CHEST + Vector2(cos(a) * r, sin(a) * r * 0.65),
				W if i % 3 == 0 else L, f * (0.4 + 0.6 * loading))
		Px.disc(self, CHEST, roundf(2.0 * loading), W, 0.5 + 0.5 * loading)
	else:
		if since < WHITE_SECONDS:
			_draw_white(0.85 * (1.0 - since / WHITE_SECONDS))
		if since < STAR_SECONDS:
			var k := since / STAR_SECONDS
			var h := 4.0 + 30.0 * (1.0 - k)
			var v := 2.0 + 13.0 * (1.0 - k)
			var d := 2.0 + 6.0 * (1.0 - k)
			Px.line(self, CHEST + Vector2(-h, 0), CHEST + Vector2(h, 0), W, 1.0 - k)
			Px.line(self, CHEST + Vector2(0, -v), CHEST + Vector2(0, v), W, 1.0 - k)
			Px.line(self, CHEST + Vector2(-h * 0.6, -1), CHEST + Vector2(h * 0.6, -1), L, 0.5 * (1.0 - k))
			Px.line(self, CHEST + Vector2(-h * 0.6, 1), CHEST + Vector2(h * 0.6, 1), L, 0.5 * (1.0 - k))
			Px.line(self, CHEST + Vector2(-d, -d), CHEST + Vector2(d, d), L, 0.7 * (1.0 - k))
			Px.line(self, CHEST + Vector2(-d, d), CHEST + Vector2(d, -d), L, 0.7 * (1.0 - k))
			Px.disc(self, CHEST, roundf(3.0 * (1.0 - k)), W, 1.0)
	_draw_sparks()


## His body, all white: the `flash` row, stamped over the real sprite where it
## stands and mirrored with it, the way copy.gd stamps the ghost.
func _draw_white(alpha: float) -> void:
	if alpha <= FAINT:
		return
	var frames := _sprite.sprite_frames
	if frames == null or not frames.has_animation("flash_side"):
		return
	var tex := frames.get_frame_texture("flash_side", 0)
	if tex == null:
		return
	var size := tex.get_size()
	var corner := Vector2(-size.x * 0.5, _sprite.offset.y - size.y * 0.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0 if _flip else 1.0, 1.0))
	draw_texture(tex, corner, Color(1.0, 1.0, 1.0, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_sparks() -> void:
	for s in _sparks:
		Px.px(self, s[0], s[4], minf(1.0, s[2] / s[3] * 1.5))


## The particles live here because they are pixels. A burst off his chest the
## frame the light lands, two motes of dust a frame off every arm's front while
## it travels, and a burst where each arm runs out.
func _tick_sparks(delta: float) -> void:
	for s in _sparks:
		s[0] += s[1] * delta
		s[2] -= delta
	_sparks = _sparks.filter(func(s: Array) -> bool: return s[2] > 0.0)
	var t := _into()
	if t == -INF:
		_last_since = -INF
		return
	_flip = _sprite.flip_h
	var since := t - Poses.windup_of("glare")
	var travel := Poses.recover_of("glare")
	if since >= 0.0 and _last_since < 0.0:
		_burst(CHEST, 10, [W, L], 30.0, 80.0, 0.2, 0.4)
	if since >= 0.0 and since <= travel:
		for arm in _arms(since):
			var dir: Vector2 = arm["dir"]
			for i in 2:
				var at := _at(dir, arm["front"], randf_range(-HALF, HALF))
				var vel := Vector2(dir.x * randf_range(20, 60) + randf_range(-8, 8),
					dir.y * randf_range(20, 60) + randf_range(-15, 5))
				var life := randf_range(0.3, 0.5)
				_sparks.append([at, vel, life, 0.5, [W, L, L].pick_random()])
	if since >= travel and _last_since < travel:
		for arm in _arms(travel):
			_burst(_at(arm["dir"], arm["reach"], 0.0), 12, [W, L, S], 20.0, 60.0, 0.3, 0.55)
	_last_since = since


func _burst(at: Vector2, count: int, cols: Array, v_min: float, v_max: float,
		l_min: float, l_max: float) -> void:
	for i in count:
		var a := randf() * TAU
		var life := randf_range(l_min, l_max)
		_sparks.append([at, Vector2.from_angle(a) * randf_range(v_min, v_max), life, life,
			cols.pick_random()])


# --- screen: the frame -------------------------------------------------------


func _draw_screen(since: float, loading: float, herald: float) -> void:
	var view := get_viewport_rect().size
	var chunk := maxf(1.0, roundf(view.x / CHUNK))
	if since < 0.0:
		_wash(view, WASH_MAX * loading * loading)
		_vignette(view, chunk, 0.05 + 0.28 * loading)
		return
	if since < FLASH_SECONDS:
		_wash(view, FLASH * (1.0 - since / FLASH_SECONDS) + WASH_MAX)
		return
	# Draining back out over the rest of the recover, so the room comes back
	# to him rather than snapping back.
	var left := clampf(1.0 - (since - FLASH_SECONDS)
		/ maxf(Poses.recover_of("glare") - FLASH_SECONDS, 0.001), 0.0, 1.0)
	_wash(view, WASH_MAX * left)
	_vignette(view, chunk, 0.18 * left)
	if herald > 0.0:
		_draw_herald(herald)


## A phase, announced. One pulse of the room, hueless and brief - the same
## trick as the glare's own wash and deliberately smaller, because it is not
## an attack and nothing about it hurts.
func _draw_herald(herald: float) -> void:
	var view := get_viewport_rect().size
	var chunk := maxf(1.0, roundf(view.x / CHUNK))
	var k := clampf(herald / 0.9, 0.0, 1.0)
	# Two pulses over the announcement rather than one long fade, so it reads
	# as something he DID instead of a light being left on.
	var beat := absf(sin(k * PI * 2.0))
	_wash(view, 0.12 * k * beat)
	_vignette(view, chunk, 0.30 * k)


func _wash(view: Vector2, alpha: float) -> void:
	if alpha <= FAINT:
		return
	draw_rect(Rect2(Vector2.ZERO, view), Color(W, minf(alpha, 0.75)))


## Hueless, and drawn as four bands rather than a gradient: a boss whose whole
## look is six exact values does not get a smooth ramp anywhere near him.
func _vignette(view: Vector2, chunk: float, alpha: float) -> void:
	if alpha <= FAINT:
		return
	for i in 4:
		var t := float(i) / 4.0
		var inset := chunk * float(i)
		var col := Color(L, alpha * (1.0 - t))
		draw_rect(Rect2(0.0, inset, view.x, chunk), col)
		draw_rect(Rect2(0.0, view.y - inset - chunk, view.x, chunk), col)
		draw_rect(Rect2(inset, 0.0, chunk, view.y), col)
		draw_rect(Rect2(view.x - inset - chunk, 0.0, chunk, view.y), col)
