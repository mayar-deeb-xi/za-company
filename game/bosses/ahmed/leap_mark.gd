extends "res://game/bosses/ahmed/fx_node.gd"
## The LEAP SLAM's telegraph: where he is going to land, and where he is now.
##
## The slam used to be a ring of embers creeping out from his own feet, which
## told you to step away from HIM. Now he jumps, and lands on the spot you
## were standing on when he left the ground - so the thing to read is on the
## floor where he is GOING, and that is what this draws: a dashed ring the
## size of the slam's own Ring area (r 40, the radius that hurts), blinking,
## with a dot at its centre. And his shadow on the floor under him, growing as
## he comes down, so the moment of the landing can be read off the ground.
##
## The ring is a CIRCLE, where the old slam drew an ellipse: the Ring area is
## a circle, and the drawing that tells you to get out has to be the shape
## that hits you.
##
## Spawned by ahmed.gd the frame he leaves the ground, at the target; gone the
## frame he is no longer in the air - landed, or knocked out of it.

const RING := 40.0
const SHADE := Color(0, 0, 0, 0.45)


func _ready() -> void:
	life = 5.0
	super()


func _tick(_delta: float) -> void:
	if boss == null or not is_instance_valid(boss) or not boss.call("is_leaping"):
		queue_free()


func _draw() -> void:
	if boss == null or not is_instance_valid(boss):
		return
	var on := int(floorf(_t * 10.0)) % 2 == 1
	Kit.disc(self, 0, 0, RING - 1.0, RING + 0.2, func(_x, _y, _d, a) -> Color:
		if int(floorf((a + PI) * 6.0)) % 2 == 0:
			return Color(0, 0, 0, 0)
		return Kit.R[2] if on else Kit.R[3])
	Kit.disc(self, 0, 0, 0, 2, func(_x, _y, _d, _a) -> Color: return Kit.R[2])
	# 0 at the top of the jump, 1 on the ground.
	var s: float = boss.call("leap_shadow")
	var under: Vector2 = boss.global_position - anchor
	Kit.ellipse(self, under.x, under.y, 5 + 5 * s, 2 + 1.5 * s, SHADE)
