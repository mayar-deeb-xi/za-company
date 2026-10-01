extends "res://game/bosses/ahmed/fx_node.gd"
## Where the LEAP SLAM comes down: the ring of fire, the cracks it leaves, and
## the flames standing round its edge.
##
## Drawing only - the damage is ahmed.gd's, off the Ring area that landed with
## him, so it cannot be a different size from this. A circle of r 40 for the
## same reason the telegraph is one (see leap_mark.gd): the old slam drew an
## ellipse round a circular hitbox.
##
## The preview's numbers: the front reaches 40 px in 0.15 s, flashing white
## for the first tenth of a second, then burns down over 0.9 s; nine cracks
## run out to 0.6-1.0 of 32 px and break up over the next 1.2 s; twelve
## flames stand on the edge for 0.8 s, and twenty embers drift off it.

const RADIUS := 40.0
const FLASH_FILL := Color(1.0, 230 / 255.0, 160 / 255.0, 0.55)


func _ready() -> void:
	life = 1.8
	super()


func _draw() -> void:
	var t := _t
	var front := RADIUS * Kit.eo(clampf(t / 0.15, 0.0, 1.0))
	var fade := clampf((t - 0.15) / 0.9, 0.0, 1.0)
	var tk := floorf(t * 12.0)
	Kit.disc(self, 0, 0, 0, front + 1.0, func(x, y, d, _a) -> Color:
		if t < 0.1:
			return Kit.R[0] if d > front - 2.0 else FLASH_FILL
		if d > front - 1.5 and fade < 1.0:
			return Kit.R[1 if fade < 0.5 else 2]
		var n := Kit.h(x, y, tk)
		if n < (1.0 - fade) * 0.45:
			return Kit.R[1] if n < 0.15 else (Kit.R[2] if n < 0.3 else Kit.R[3])
		return Color(0, 0, 0, 0))
	var cf := clampf((t - 0.6) / 1.2, 0.0, 1.0)
	for k in 9:
		var a := k * 0.698 + 0.2
		var len := minf(front, RADIUS * 0.8) * (0.6 + 0.4 * Kit.h(k, 2))
		for r in range(4, int(ceilf(len))):
			if Kit.h(k, r, 9) < cf:
				continue
			var j := Kit.rnd((Kit.h(k, r >> 2) - 0.5) * 2.0)
			Kit.px(self, Kit.rnd(cos(a) * r) + j, Kit.rnd(sin(a) * r),
				Kit.R[1] if t < 0.4 else (Kit.R[2] if t < 1.0 else Kit.R[4]))
	if t > 1.0:
		return
	for k in 12:
		var a := k * PI / 6.0 + 0.1
		var r := RADIUS * Kit.eo(clampf(t / 0.15, 0.0, 1.0)) * (0.85 + 0.15 * Kit.h(k, 1))
		var burn := clampf(1.0 - t / 0.8, 0.0, 1.0)
		if burn > 0.0:
			Kit.flame(self, Kit.rnd(cos(a) * r), Kit.rnd(sin(a) * r),
				(4 + 8 * Kit.h(k, 3)) * burn * minf(1.0, t / 0.08), 2, t, k * 7)
	Kit.parts(self, 0, -2, t, 0.0, 20, 77, {"spd": RADIUS * 0.9, "vz": 24.0, "g": -6.0, "life": 1.0})
