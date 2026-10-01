extends "res://game/bosses/ahmed/fx_node.gd"
## The flash on every impact: a white star that holds for exactly as long as
## the hit-stop does, and is gone the frame the world moves again.
##
## The one effect here that keeps REAL time rather than the room's: the room
## is all but stopped while it shows (game.gd's `_freeze`), so a clock fed the
## scaled delta would hold it on screen for a second and a half.

const SIZE := 7

var seconds := 0.08
var _born := 0


func _ready() -> void:
	life = 10.0
	_born = Time.get_ticks_msec()
	z_index = 1
	super()


func _tick(_delta: float) -> void:
	if Time.get_ticks_msec() - _born >= seconds * 1000.0:
		queue_free()


func _draw() -> void:
	Kit.star(self, 0, 0, SIZE)
