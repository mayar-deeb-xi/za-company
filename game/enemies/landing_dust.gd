extends Node2D
## The two puffs a juggled body kicks up when it lands - one each side of the
## feet, drifting outward, rising a little and thinning out over 0.35 s.
##
## Left in the body's parent rather than on the body, so a body that lands and
## walks straight off does not drag its own dust along. Top-level in world
## pixels; frees itself. Picked from the Combo Lab preview with the juggle.

const LIFE := 0.35
const SPREAD := 4.0
const DRIFT := 25.0
const INK := Color(200 / 255.0, 196 / 255.0, 210 / 255.0)

var _feet := Vector2.ZERO
var _age := 0.0
var _drift := DRIFT
var _out := 0.0


static func kick(body: Node2D) -> void:
	var world := body.get_parent()
	if world == null:
		return
	var node: Node2D = (load("res://game/enemies/landing_dust.gd") as GDScript).new()
	world.add_child(node)
	node.top_level = true
	node.global_position = Vector2.ZERO
	node._feet = body.global_position + Vector2(0, 1)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	_out += _drift * delta
	_drift *= 0.9
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFE
	var ink := Color(INK, 0.55 * (1.0 - t))
	var width := 3.0 + t * 5.0
	var height := 2 + roundi(t * 2.0)
	for side in [-1.0, 1.0]:
		_blob(_feet + Vector2(side * (SPREAD + _out), -t * 3.0), width, height, ink)


## A soft pixel ellipse, row by row.
func _blob(centre: Vector2, w: float, h: int, ink: Color) -> void:
	for j in h:
		var k := 1.0 - absf((j + 0.5) / h * 2.0 - 1.0)
		var ww := maxf(1.0, roundf(w * (0.55 + 0.45 * k)))
		draw_rect(Rect2(roundf(centre.x - ww / 2.0), roundf(centre.y - h / 2.0 + j), ww, 1), ink)
