extends Node2D
## The ring at the player's feet while the heavy is charging - the charge's
## only readable cue, and the reason the stance stopped being guesswork.
##
## The heavy used to say nothing about itself. The one signal was the charge
## animation doubling speed at the ready point, which is two pixels of eye on a
## 32 px body in a room with four enemies in it, so the stance was held blind
## and released on a count in the player's head. This is that count, drawn: a
## ring that TIGHTENS as the charge fills and flares white as it goes off, so
## "how much longer" is a thing you can see rather than a thing you remember.
##
## It is a child of the player, so it follows the body without being told
## anything, and it draws at `z_index` -1 - under the feet, where gathering
## power belongs and where it cannot hide the body the player is steering. The
## colour is the character's spark, which is `Roster.spark_hex()` for the third
## time: the sheet's sparks, the arc's bolt and this ring are one rule, so
## Mayar charges violet and Anas gold with nothing here knowing who they are.
##
## player.gd owns its life: it sets `progress` every frame of the stance, calls
## `fire()` when the heavy goes off (the node then flares and frees itself) and
## frees it outright on an early release, where nothing happened and nothing
## should flash.

## The ring's radius at an empty charge and at a full one. It closes INWARD -
## a ring that grows would read as something already happening, and this is a
## thing being gathered.
const RADIUS_FROM := 20.0
const RADIUS_TO := 7.0
## Top-down, so the ring is an ellipse lying on the floor rather than a circle
## standing up in the air. The same squash the shadows use.
const SQUASH := 0.45
## Points around the ring. 24 is enough that a 20 px ellipse reads as round and
## few enough that the segments stay whole pixels apart.
const SEGMENTS := 24
## The four sparks orbiting the ring, which are what make the fill legible at
## a glance: the ring's SIZE says how full it is and the sparks' SPEED says the
## same thing again, for a player whose eyes are on the enemies.
const TICKS := 4
const TICK_TURNS := 1.5
## The flare when it goes off: the ring snapping outward, white, and gone.
const FLASH_SECONDS := 0.14
const FLASH_TO := 28.0
## Found by tests through this group; nothing in the game looks a ring up.
const GROUP := "player_charge"

## 0 at the press, 1 at the ready point. Written by player.gd every frame.
var progress := 0.0
var colour := Color.WHITE
## Seconds into the flare, or -1 while still charging.
var _flash := -1.0


func setup(spark: Color) -> void:
	colour = spark
	z_index = -1
	# Two pixels up from the origin, which is where the feet are: the ring
	# should look like it is drawn on the floor the body is standing on.
	position = Vector2(0, -2)
	add_to_group(GROUP)


## The heavy just went off. Flare and die - this is the one frame of the whole
## stance that is worth a flash, because it is the one the player did not have
## to time.
func fire() -> void:
	_flash = 0.0


func _process(delta: float) -> void:
	if _flash >= 0.0:
		_flash += delta
		if _flash >= FLASH_SECONDS:
			queue_free()
			return
	queue_redraw()


func _draw() -> void:
	if _flash >= 0.0:
		var t := _flash / FLASH_SECONDS
		var flare := Color(1.0, 1.0, 1.0, 1.0 - t)
		draw_polyline(_ellipse(lerpf(RADIUS_TO, FLASH_TO, t)), flare, 2.0)
		return
	var filled := clampf(progress, 0.0, 1.0)
	var radius := lerpf(RADIUS_FROM, RADIUS_TO, filled)
	# The ring brightens towards white as it closes, so the last quarter of the
	# charge is visibly the last quarter rather than merely a smaller circle.
	var ink := colour.lerp(Color.WHITE, filled * 0.6)
	ink.a = 0.5 + 0.5 * filled
	draw_polyline(_ellipse(radius), ink, 1.0)
	var spin := filled * TAU * TICK_TURNS
	for i in TICKS:
		var angle := TAU * i / TICKS + spin
		var at := Vector2(cos(angle) * radius, sin(angle) * radius * SQUASH).round()
		draw_rect(Rect2(at, Vector2(2, 2)), Color(1.0, 1.0, 1.0, ink.a))


## A flat ellipse of `r` world pixels across, snapped to whole pixels so the
## ring stays crisp on a 640x360 viewport.
func _ellipse(r: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in SEGMENTS + 1:
		var angle := TAU * i / SEGMENTS
		points.append(Vector2(cos(angle) * r, sin(angle) * r * SQUASH).round())
	return points
