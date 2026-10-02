extends Node2D
## A hit on Big Mo's shell: a hard white ring and four short spokes off his
## gloves, gone in a fifth of a second. It is the one thing that says the swing
## did NOTHING - no health came off, no flash, no stagger - so it is white and
## square-edged where every hit that lands is warm.
##
## Dropped into the room at his chest and left there, so it stays where the
## block happened if he moves into the counter. Told nothing: it frees itself.

const SECONDS := 0.18
const BONE := Color(233.0 / 255.0, 231.0 / 255.0, 226.0 / 255.0)

var _age := 0.0


func _ready() -> void:
	z_index = 1


func _process(delta: float) -> void:
	_age += delta
	if _age >= SECONDS:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _age / SECONDS
	var col := Color(BONE, 1.0 - k)
	var r := 3.0 + 9.0 * (1.0 - pow(1.0 - k, 2.0))
	var steps := maxi(16, roundi(r * 8.0))
	for i in steps:
		var th := TAU * float(i) / float(steps)
		draw_rect(Rect2(floorf(cos(th) * r), floorf(sin(th) * r * 0.8), 1.0, 1.0), col)
	# Four spokes on the diagonals: a block is a stop, not a burst.
	for i in 4:
		var th := TAU * (float(i) + 0.5) / 4.0
		for d in range(int(r) + 1, int(r) + 4):
			draw_rect(Rect2(floorf(cos(th) * d), floorf(sin(th) * d * 0.8), 1.0, 1.0), col)
