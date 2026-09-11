extends "res://game/bosses/mostafa/brush.gd"
## THE FULL ERUPTION - what happens to Mostafa at 72 HP, and what he is for the
## rest of the fight afterwards.
##
## Half his health is already a moment: his floor's biome cues a beat at
## `at_boss_health: 72`, so a call_center and a social_media walk in through
## the south door on the same frame. The fire goes up as the door opens.
##
## It is ONE flip, not a phase ladder - DESIGN.md gives the ladder to Khaled,
## and two bosses making the same argument is one boss too many. He never comes
## back down.
##
## **The eruption**, 0.95 s, and every beat lands on the start of a frame of
## `rage` in poses.gd, so the picture and the fire cannot drift:
##
## - three PULSES of light out of him, each brighter and each kicking a ring
##   off the floor and a ring off his chest. They are a count-in: the player
##   gets to learn that something is coming rather than being flashed at.
## - on the third sink, the BLAST - a white flash, the room already dark behind
##   it, and a ring of fire that crosses the whole arena leaving scorch and
##   standing flame where it passed.
## - he comes up through his own COLUMN with his arms flung open.
##
## **What he keeps** is the other half, and the half that is on screen for the
## rest of the fight: a fire skirt at his boots, eight flames orbiting him,
## both gloves burning, embers, heat, smoke, and a crimson rim along his whole
## silhouette read off the sheet's own alpha.
##
## Three parts on the three surfaces `bell.gd` already established - ground
## under the body, burst over it, screen on the CanvasLayer under the HUD. The
## rage does not invent a rig; it is a fourth job for the one that is there.
##
## Nothing tells it anything, with one exception it cannot avoid: the sustained
## fire has to outlive the animation that started it, so it asks the boss
## `is_raging` rather than trying to read a state off a sprite that has long
## since gone back to `idle_side`. The ERUPTION still comes entirely off the
## sprite, like every other effect in this folder.

## The beats, in seconds from the first frame of `rage`. These are the frame
## boundaries in poses.gd - pulses on frames 1, 2 and 4, the blast on 3.
const PULSES := [0.16, 0.40, 0.62]
const PULSE_SECONDS := 0.22
const BLAST := 0.51
const BLAST_SECONDS := 0.44
const COLUMN := 0.62
const COLUMN_SECONDS := 0.33

## The screen's share of it: the flash, and how long the room stays dark.
const FLASH_SECONDS := 0.16
const DARK := 0.55

## How far the arena ring travels. It is paint - it does not damage anything,
## and nothing in the room reacts to it.
const RING_REACH := 210.0

## What the sustained fire is built from.
const SKIRT := 5          # flames along his base
const ORBIT := 8          # flames going round him
const ORBIT_RADIUS := 20.0
const ORBIT_SPEED := 0.4

## The rim flickers at this many steps a second, like Ahmed's blade glow.
const FLICKER_HZ := 9.0

## Seconds the sustained fire takes to come up as the eruption ends.
const SETTLE := 0.36


func _draw() -> void:
	if _sprite == null or _boss == null:
		return
	var flag: Variant = _boss.get("is_raging")
	var raging: bool = flag if flag is bool else false
	var erupting := _anim() == "rage"
	if not raging and not erupting:
		return
	_flip = _sprite.flip_h

	var frame: Dictionary = {}
	var frames: Array = Poses.ANIMS[_anim()] if Poses.ANIMS.has(_anim()) else []
	var idx := 0
	if not frames.is_empty():
		idx = clampi(_sprite.frame, 0, frames.size() - 1)
		frame = frames[idx]

	# `since` is seconds into the eruption, and -1 once it is over: everything
	# below is written against it.
	var since := -1.0
	if erupting and not frames.is_empty():
		since = _into(frames, idx)
	# The sustained fire comes up over the back of the eruption rather than
	# snapping on, so the skirt is already burning when he stands up.
	var settled := 1.0
	if since >= 0.0:
		settled = clampf((since - (Poses.length_of("rage") - SETTLE)) / SETTLE, 0.0, 1.0)

	match part:
		"ground":
			if since >= 0.0:
				_erupt_ground(since)
			if settled > 0.0:
				_keep_ground(settled)
		"burst":
			if since >= 0.0:
				_erupt_burst(since)
			if settled > 0.0:
				_keep_burst(frame, settled)
		"screen":
			if since >= 0.0:
				_erupt_screen(since)


# --- the eruption ------------------------------------------------------------


## Under him: the pulse rings on the floor, the blast crossing the arena, and
## the scorch both leave behind.
func _erupt_ground(since: float) -> void:
	for i in PULSES.size():
		var age := since - float(PULSES[i])
		if age < 0.0 or age > PULSE_SECONDS:
			continue
		var k := age / PULSE_SECONDS
		var grow := 1.0 - pow(1.0 - k, 2.0)
		# Each pulse is bigger than the last. The third is the one that gives.
		var mag := 0.45 + float(i) * 0.27
		_ring(0.0, 0.0, 6.0 + 26.0 * grow * mag, 0.4,
			Color(_fcol(k * 0.6), (1.0 - k) * mag))

	var blast := since - BLAST
	if blast >= 0.0 and blast < BLAST_SECONDS:
		var k := blast / BLAST_SECONDS
		var grow := 1.0 - pow(1.0 - k, 2.2)
		_ring(0.0, 0.0, 10.0 + RING_REACH * grow, 0.4,
			Color(_fcol(k * 0.8), (1.0 - k) * 0.95))
		_ring(0.0, 0.0, 10.0 + RING_REACH * 0.81 * grow, 0.4,
			Color(_fcol(k * 0.5), (1.0 - k) * 0.55))
		# Standing flame riding the front of it.
		for i in 10:
			var ang := TAU * float(i) / 10.0 + 0.3
			var r := 24.0 + RING_REACH * 0.71 * grow
			_flame(cos(ang) * r, sin(ang) * r * 0.42 + 1.0,
				roundi(9.0 * (1.0 - k)), 5.0, i * 13, 1.0 - k)
		_scorch(0.0, 1.0, 26, 9, 1.0)

	var col := since - COLUMN
	if col >= 0.0 and col < COLUMN_SECONDS:
		var k := col / COLUMN_SECONDS
		_ring(0.0, 0.0, 8.0 + 58.0 * (1.0 - pow(1.0 - k, 2.0)), 0.4,
			Color(_fcol(k), (1.0 - k) * 0.95))
		_scorch(0.0, 1.0, 18, 7, 1.0 - k * 0.3)


## Over him: the pulses leaving his chest, and the column he stands up through.
func _erupt_burst(since: float) -> void:
	for i in PULSES.size():
		var age := since - float(PULSES[i])
		if age < 0.0 or age > PULSE_SECONDS:
			continue
		var k := age / PULSE_SECONDS
		var grow := 1.0 - pow(1.0 - k, 2.0)
		var mag := 0.45 + float(i) * 0.27
		_ring(0.0, -18.0, 4.0 + 22.0 * grow * mag, 1.0,
			Color(_fcol(k * 0.5), (1.0 - k) * 0.8 * mag))
		_embers(0.0, -20.0, 4 + i * 3, 8 + i * 3,
			roundi(since * 40.0) + i, (1.0 - k) * mag)

	var blast := since - BLAST
	if blast >= 0.0 and blast < BLAST_SECONDS:
		var k := blast / BLAST_SECONDS
		_column(0.0, 2.0, roundi(40.0 * (1.0 - k)), 16.0,
			roundi(since * 30.0), 1.0 - k)

	var col := since - COLUMN
	if col >= 0.0 and col < COLUMN_SECONDS:
		var k := col / COLUMN_SECONDS
		_column(0.0, 2.0, roundi(54.0 * minf(1.0, k * 2.2)), 13.0,
			roundi(since * 30.0), 1.0 - k * 0.4)


## The frame itself: the room going dark through the wind-up, and the flash the
## blast comes out of. Drawn under the HUD, so his own health bar survives it.
func _erupt_screen(since: float) -> void:
	var view := get_viewport_rect().size
	var length: float = Poses.length_of("rage")

	var ramp := minf(1.0, since / (length * 0.66))
	var lift := 1.0
	if since > length * 0.72:
		lift = maxf(0.0, 1.0 - (since - length * 0.72) / (length * 0.28))
	var dark := DARK * ramp * lift
	if dark > FAINT:
		draw_rect(Rect2(Vector2.ZERO, view), Color(0.024, 0.016, 0.024, dark))

	var blast := since - BLAST
	if blast >= 0.0 and blast < FLASH_SECONDS:
		draw_rect(Rect2(Vector2.ZERO, view),
			Color(HOT, 0.72 * (1.0 - blast / FLASH_SECONDS)))


# --- what he keeps -----------------------------------------------------------


## Under him: the skirt at his boots, the orbit's back half, and the scorch he
## is standing on.
func _keep_ground(alpha: float) -> void:
	var tick := floori(_time * FLICKER_HZ)
	_scorch(0.0, 1.0, 16, 3, alpha)
	for i in SKIRT:
		_flame(-8.0 + float(i) * 4.0, 0.0, 3 + _hash(tick, i) % 3, 3.0,
			tick * 7 + i, 0.85 * alpha)
	_ring(0.0, 0.0, 13.0, 0.4, Color(F[3], 0.18 * alpha))
	_orbit(tick, alpha, true)


## Over him: the orbit's front half, both gloves burning, the rim, and the
## heat and smoke coming off him.
func _keep_burst(frame: Dictionary, alpha: float) -> void:
	var tick := floori(_time * FLICKER_HZ)
	_orbit(tick, alpha, false)

	# The gloves caught, and they stay caught. This is the half that makes
	# every punch afterwards read harder.
	if not frame.is_empty():
		for key: String in ["L", "R"]:
			if frame.get(key, {}).is_empty():
				continue
			var at := _glove(frame, key)
			var seed := tick * 3 + roundi(at.x)
			_flame(at.x, at.y + 2.0, 6 + _hash(tick, roundi(at.x)) % 3, 5.0,
				seed, 0.95 * alpha)
			_embers(at.x, at.y - 3.0, 3, 4, seed + 7, 0.8 * alpha)

	_rim(alpha)
	_embers(0.0, -24.0, 5, 10, tick * 3, 0.7 * alpha)
	_haze(0.0, -30.0, 18.0, 22.0, 11, alpha)
	_smoke(-4.0, -26.0, 5, 7, alpha * 0.8)
	_smoke(5.0, -26.0, 9, 7, alpha * 0.8)


## Eight flames going round him, split front and back about the ellipse, which
## is the only thing that sells them as going ROUND rather than sitting in a
## row in front of him.
func _orbit(tick: int, alpha: float, behind: bool) -> void:
	for i in ORBIT:
		var ang := TAU * float(i) / float(ORBIT) + _time * ORBIT_SPEED
		if (sin(ang) < 0.0) != behind:
			continue
		_flame(cos(ang) * ORBIT_RADIUS, sin(ang) * ORBIT_RADIUS * 0.42,
			5 + _hash(tick, i) % 3, 4.0, tick * 5 + i,
			(0.6 if behind else 0.85) * alpha)


## A crimson edge along his whole silhouette, read off the SHEET's own alpha -
## so it follows whatever frame he is drawn in, including frames drawn long
## after this was written, and costs the art nothing.
##
## Computed ONCE per cell and kept. It is 16k pixel reads for a 128px cell,
## which is nothing as a one-off and would be a framerate as a per-frame job;
## the sheet cannot change under a running game, so the answer never goes
## stale. Keyed by animation and frame because that is what picks the cell.
static var _rims := {}

func _rim(alpha: float) -> void:
	var key := "%s:%d" % [_sprite.animation, _sprite.frame]
	var edge: PackedVector2Array = _rims.get(key, PackedVector2Array())
	if not _rims.has(key):
		edge = _trace(_sprite.animation, _sprite.frame)
		_rims[key] = edge
	var tick := floori(_time * FLICKER_HZ)
	for i in edge.size():
		# Broken up, and re-broken every flicker step, so the edge crawls
		# rather than sitting on him as a sticker.
		if _hash(tick, i) % 5 == 0:
			continue
		_put(edge[i].x, edge[i].y, Color(F[2], 0.5 * alpha))


## Every opaque pixel of a cell with a transparent 4-neighbour, in world pixels
## off his origin.
func _trace(anim: StringName, frame: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var tex := _sprite.sprite_frames.get_frame_texture(anim, frame) as AtlasTexture
	if tex == null or tex.atlas == null:
		return out
	var img := tex.atlas.get_image()
	if img == null:
		return out
	var at := Vector2i(tex.region.position)
	var size := Vector2i(tex.region.size)
	# The sprite's own offset is what puts the cell's origin on his feet, so
	# the geometry is read off the scene rather than restated as a number.
	var ox := float(size.x) * 0.5 - _sprite.offset.x
	var oy := float(size.y) * 0.5 - _sprite.offset.y
	var dens := _sprite.scale.x
	for y in size.y:
		for x in size.x:
			if not _solid(img, at.x + x, at.y + y):
				continue
			if _solid(img, at.x + x + 1, at.y + y) \
					and _solid(img, at.x + x - 1, at.y + y) \
					and _solid(img, at.x + x, at.y + y + 1) \
					and _solid(img, at.x + x, at.y + y - 1):
				continue
			out.append(Vector2((float(x) - ox) * dens, (float(y) - oy) * dens))
	return out


static func _solid(img: Image, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return false
	return img.get_pixel(x, y).a >= 0.5
