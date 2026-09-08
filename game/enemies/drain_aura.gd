extends Node2D
## The wraith's aura, drawn rather than animated - the same idea as the
## warden's field (game/enemies/charge_ring.gd), for a different harm.
##
## Two things the drawing has to say. *Where the edge is*: a dashed rim at the
## exact reach of the Touch shape, faint at rest and brighter while feeding, on
## an aura that is only 16 px and walks toward you. *Where your health is
## going*: a drain is a rate, not an event, so the picture beats with it - every
## whole point the wraith takes leaves the player as a mote that streams into
## the wraith's chest. One mote per point, spawned from the same spot in
## wraith.gd that calls the player's drain(), so a mote can only ever be drawn
## for health that was really taken.
##
## The rim is `drain_aura.gdshader` on the `Rim` child, so it is a hard pixel
## ring at 1x. The motes are drawn HERE with draw_rect, on a node with no
## material: they start at the player, outside the rim's quad, and a material
## on this node would run every mote through the rim shader and paint it
## transparent.
##
## It never carries the radius itself: wraith.gd copies in the Touch shape's
## radius and offset on _ready, so the ring cannot claim a reach the aura does
## not have. It sits at z 0 as the wraith's first child - above the floor,
## beneath the body. The level's Floor tilemap is at z 0 too, so a negative
## z_index here would draw under it and never be seen (the warden's ring did
## exactly that once).

const SHADER := preload("res://game/enemies/drain_aura.gdshader")

## Matches wraith.gd's FEED_TINT: the body glowing cold and the health leaving
## you are one reading, not two.
const FEED_TINT := Color(0.55, 0.85, 1.0)
const MOTE_START := Color(0.94, 0.96, 1.0)
## How long a point of health takes to cross from the player to the wraith.
## Shorter than the 0.33 s between points at 3/s, so motes never queue up.
const MOTE_SECONDS := 0.35
## The lift on the mote's path, so it arcs rather than slides along the floor.
const MOTE_ARC := 6.0
## Chest height above a body's position, for a 32 px sprite offset -8.
const CHEST := Vector2(0.0, -10.0)
## How fast the rim's dashes turn while feeding, in dashes per second.
const DASH_SPIN_HZ := 3.0

## Declared before `radius` so its setter can reach it.
var _material := ShaderMaterial.new()

## Set by wraith.gd from the Touch shape after this node's _ready, so it has to
## reach the shader whenever it changes, not only once at start.
@export var radius := 16.0:
	set(value):
		radius = value
		_material.set_shader_parameter("radius", radius)
		if is_node_ready():
			_rim.queue_redraw()

## Motes in flight: where each started (global, so a wraith that keeps walking
## does not drag the trail with it) and how long it has been flying.
var _motes: Array[Dictionary] = []

@onready var _rim: Node2D = $Rim


func _ready() -> void:
	_material.shader = SHADER
	_material.set_shader_parameter("radius", radius)
	_rim.material = _material
	_rim.draw.connect(_draw_rim)
	set_process(false)


func _process(delta: float) -> void:
	for mote in _motes:
		mote["age"] += delta
	_motes = _motes.filter(func(m: Dictionary) -> bool: return m["age"] < MOTE_SECONDS)
	queue_redraw()
	if _motes.is_empty():
		set_process(false)


## Whether the wraith is feeding this frame, and for how long it has been. The
## rim brightens and its dashes turn; both stop the moment contact breaks.
func set_feeding(feeding: bool, feed_time: float) -> void:
	_material.set_shader_parameter("feeding", feeding)
	_material.set_shader_parameter("spin", feed_time * DASH_SPIN_HZ)


## One point of health taken from the player standing at `player_global`. The
## mote leaves their chest now and arrives at the wraith's in MOTE_SECONDS.
func tick(player_global: Vector2) -> void:
	_motes.append({"from": player_global + CHEST, "age": 0.0})
	set_process(true)
	queue_redraw()


func _draw() -> void:
	var wraith := get_parent() as Node2D
	if wraith == null:
		return
	var to := to_local(wraith.global_position + CHEST)
	for mote in _motes:
		var k: float = mote["age"] / MOTE_SECONDS
		var pos: Vector2 = to_local(mote["from"]).lerp(to, k)
		pos.y -= sin(k * PI) * MOTE_ARC
		var color := MOTE_START.lerp(FEED_TINT, k)
		color.a = 0.95 - 0.3 * k
		# A 2 px square on whole pixels: a mote crosses the sprites, so it has to
		# stay small, and it must not shimmer against them as it moves.
		draw_rect(Rect2(pos.round() - Vector2.ONE, Vector2(2.0, 2.0)), color)


## The rim's quad; the shader decides every pixel in it. Two pixels of slack so
## the ring's outer edge is never clipped by the quad it is drawn on.
func _draw_rim() -> void:
	var half := radius + 2.0
	_rim.draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), Color.WHITE)
