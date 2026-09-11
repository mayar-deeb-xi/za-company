extends Node2D
## THE GLARE - the penthouse turned into a weapon, and the announcement that a
## phase has changed.
##
## He is a man made of mirror standing in a room that is glass on one side. The
## glare is him using it: he draws his own shine inward over the wind-up (the
## `dull` steps on the `glare` row - that dimming is the telegraph, and it is
## on the sheet because his resting rung is already the brightest he gets), and
## then spends the lot at once. The room whites out and a band of it crosses
## the floor.
##
## Two parts, one script, chosen by `part` - and the split is by SPACE, which
## is Ahmed's axe_fire.gd and Mostafa's bell.gd arrangement for the same
## reason:
##
## - **band** sits under the body: the bar of light travelling across the room
##   and the floor brightening under him as he loads. WORLD pixels, so it grows
##   with the zoom it is watched at.
## - **screen** hangs off a CanvasLayer: the wash, the vignette and the flash.
##   VIEWPORT pixels, because the edge of the screen is not a place in the
##   room. That layer sits BELOW the HUD - a white-out that takes his own
##   health bar with it hides the one number the player is reading while it
##   lands.
##
## Nothing tells either of them anything. Each walks up to the `bosses` group,
## reads the sprite's animation, frame and progress, and draws off poses.gd -
## so a reworded pose moves its light with it and no timing here can disagree
## with the telegraph it is drawing.
##
## **The band draws exactly the hitbox.** Its front comes from the boss's own
## `glare_front()`, the same function `_glare_reach()` moves the Area2D with,
## and its height is the `Band` shape's height. A sweep you can step out of has
## to be a sweep you can SEE the edges of, so the two are one number rather
## than two that look similar.
##
## The whole thing is hueless, like him. There is no hue anywhere in his
## palette and the city outside the glass is the only coloured thing in the
## room - which is what makes the room going white read as HIM rather than as
## a fire somewhere.

const Poses := preload("res://game/bosses/silverman/poses.gd")

@export_enum("band", "screen") var part := "band"

## His ramp, top three rungs. The glare is made of nothing else.
const W := Color(238.0 / 255.0, 244.0 / 255.0, 251.0 / 255.0)
const L := Color(195.0 / 255.0, 204.0 / 255.0, 216.0 / 255.0)
const S := Color(140.0 / 255.0, 151.0 / 255.0, 168.0 / 255.0)

## Below this an alpha is not worth a draw call.
const FAINT := 0.03

## Where the burst comes from - his chest, half the lane up - and the floor's
## own squash, since a circle on a floor seen from a slight elevation is an
## ellipse. The same 0.4 Ahmed's rings are drawn on.
const CHEST := -10.0
const SQUASH := 0.4

## The band: how tall the lane is, how wide its core, and the trailing copies
## that make a moving bar read as a sweep rather than a post.
const LANE_HEIGHT := 20.0
const CORE_WIDTH := 3.0
const TRAIL := 9
const TRAIL_STEP := 4.0

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


func _ready() -> void:
	# Walked rather than reached for by path: the screen part hangs off a
	# CanvasLayer, so its parent is not the boss the band sits under.
	var node: Node = self
	while node != null and not node.is_in_group("bosses"):
		node = node.get_parent()
	_boss = node as Node2D
	if _boss != null:
		_sprite = _boss.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	set_process(_sprite != null)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _sprite == null or _boss == null:
		return
	_flip = _sprite.flip_h
	var herald := float(_boss.get("herald"))
	var anim := String(_sprite.animation).trim_suffix("_side")
	if anim != "glare":
		# A phase arriving is the one thing this draws while he is not
		# glaring: he has no cuffs to adjust, so he spends a rung of his own
		# shine on the room instead. Only the screen carries it - a bar of
		# light crossing the floor would read as an attack nobody threw.
		if part == "screen" and herald > 0.0:
			_draw_herald(herald)
		return

	var frames: Array = Poses.ANIMS["glare"]
	var idx := clampi(_sprite.frame, 0, frames.size() - 1)
	# Seconds into the animation, off the same `dur` list the boss derives
	# windup_seconds from. Negative until the light lands, then seconds since.
	var into := Poses.into("glare", idx) \
		+ clampf(_sprite.frame_progress, 0.0, 1.0) * float(frames[idx]["dur"])
	var windup := Poses.windup_of("glare")
	var since := into - windup
	var loading := clampf(into / maxf(windup, 0.001), 0.0, 1.0)
	if part == "band":
		_draw_band(since, loading)
	else:
		_draw_screen(since, loading, herald)


# --- band: the room ----------------------------------------------------------


func _draw_band(since: float, loading: float) -> void:
	if since < 0.0:
		# Loading: the floor under him brightens, and that is all. The band
		# does not exist yet and a telegraph that draws where a blow will land
		# gives the whole sweep away.
		var glow := 0.10 + 0.35 * loading
		_bar(0.0, LANE_HEIGHT * (0.3 + 0.7 * loading), 1.0, Color(S, glow))
		return
	# THE BURST OFF HIM, which is `_flash_at_source()` drawn. That blow catches
	# anyone inside his own reach whatever line they stand on, and a hitbox
	# nothing draws is a hitbox nobody can learn - so it gets the same 0.12 s
	# the screen spends flashing, out to the reach it actually has.
	if since < FLASH_SECONDS:
		var k := since / FLASH_SECONDS
		_burst(4.0 + 22.0 * k, Color(W, 1.0 - k))
		_burst(2.0 + 16.0 * k, Color(L, (1.0 - k) * 0.7))
	# Travelling, and the front is the boss's own number - the one his Area2D
	# is moved to on this very frame.
	var front := float(_boss.call("glare_front", since))
	var fade := 1.0 - clampf(since / maxf(Poses.recover_of("glare"), 0.001), 0.0, 1.0)
	for i in TRAIL:
		var back := front - float(i) * TRAIL_STEP
		if back <= 0.0:
			break
		var k := float(i) / float(TRAIL)
		_bar(back, LANE_HEIGHT, CORE_WIDTH - k * 1.5,
			Color(W if i == 0 else (L if i < 4 else S), (1.0 - k) * (0.35 + 0.6 * fade)))
	# The two edges of the lane, held bright for as long as the sweep is out:
	# the player is being asked to step off a line, so the line is drawn.
	var edge := Color(S, 0.20 * fade)
	_bar_h(0.0, front, -LANE_HEIGHT, edge)
	_bar_h(0.0, front, 0.0, edge)


## A vertical bar of the lane, `x` world px ahead of him along his facing.
func _bar(x: float, height: float, width: float, col: Color) -> void:
	if col.a <= FAINT or width < 0.5:
		return
	var at := -x if _flip else x
	draw_rect(Rect2(roundf(at - width * 0.5), roundf(-height), roundf(width),
		roundf(height)), col)


## A ring off his chest, on the floor's own ellipse - the same squash Ahmed's
## rings are drawn on, since the floor is seen from a slight elevation. Not
## mirrored: a burst is round and does not care which way he faces.
func _burst(r: float, col: Color) -> void:
	if r < 0.5 or col.a <= FAINT:
		return
	var steps := maxi(16, roundi(r * 8.0))
	for i in steps + 1:
		var th := TAU * float(i) / float(steps)
		draw_rect(Rect2(roundf(cos(th) * r), roundf(CHEST + sin(th) * r * SQUASH),
			1.0, 1.0), col)


## One horizontal rule along the floor, from `x0` to `x1` ahead of him.
func _bar_h(x0: float, x1: float, y: float, col: Color) -> void:
	if col.a <= FAINT:
		return
	var a := -x0 if _flip else x0
	var b := -x1 if _flip else x1
	draw_rect(Rect2(roundf(minf(a, b)), roundf(y), roundf(absf(b - a)), 1.0), col)


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
