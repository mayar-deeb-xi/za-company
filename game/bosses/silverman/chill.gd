extends Node2D
## THE COLD ROOM - what standing near him costs once he has stopped being
## polite about it.
##
## The drain itself is `silverman.gd`'s and it is four lines: inside the radius,
## health goes, banked in whole points and metered by nothing. This file is the
## only warning the player gets, and that makes it load-bearing rather than
## decorative - an aura with no telegraph is only fair if you can see where it
## reaches. So the one thing drawn brightest here is the EDGE, at exactly the
## radius the drain uses, read off the boss rather than restated.
##
## It draws only in his third phase, and it asks him which phase that is. Like
## every effect on this boss it is told nothing: it walks up to the `bosses`
## group and reads him.
##
## Frost on the floor, an edge, and motes coming off him. No hue, like the rest
## of him - cold here is a lack of everything rather than a colour, which is
## the only way to draw cold in a palette that has no blue in it.

## His ramp, the rungs the frost is built from.
const W := Color(238.0 / 255.0, 244.0 / 255.0, 251.0 / 255.0)
const L := Color(195.0 / 255.0, 204.0 / 255.0, 216.0 / 255.0)
const S := Color(140.0 / 255.0, 151.0 / 255.0, 168.0 / 255.0)
const M := Color(84.0 / 255.0, 93.0 / 255.0, 110.0 / 255.0)

const FAINT := 0.03
## The floor is seen from the game's slight elevation, so a circle on it is an
## ellipse - the same squash Ahmed's rings are drawn on.
const SQUASH := 0.4
## How many motes are in the air at once, and how high they climb.
const MOTES := 12
const MOTE_RISE := 26.0

var _boss: Node2D
var _time := 0.0


func _ready() -> void:
	var node: Node = self
	while node != null and not node.is_in_group("bosses"):
		node = node.get_parent()
	_boss = node as Node2D
	set_process(_boss != null)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if _boss == null or _boss.get("has_conceded"):
		return
	# The third phase only. A boss who is still being fair does not get to
	# hurt anyone for standing still, and nothing here draws until he does.
	if int(_boss.call("tier")) < 3:
		return
	var radius := float(_boss.get("chill_radius"))
	var pulse := 0.5 + 0.5 * sin(_time * 2.0)

	# The floor, gone over. Broken up rather than solid, so it reads as frost
	# spreading instead of a painted circle.
	for i in 46:
		var th := TAU * float(i) / 46.0
		var r := radius * (0.30 + 0.62 * float(_hash(i, 3) % 100) / 100.0)
		var drift := sin(_time * 0.9 + float(i)) * 1.5
		_put(cos(th) * r + drift, sin(th) * r * SQUASH,
			L if _hash(i, 7) % 3 == 0 else S, 0.18 + 0.16 * pulse)

	# THE EDGE, at the radius the drain actually uses. Dashed and turning, so
	# it is unmistakably a boundary and unmistakably alive.
	var steps := maxi(28, roundi(radius * 2.2))
	for i in steps:
		var th := TAU * float(i) / float(steps) + _time * 0.5
		if fposmod(float(i), 4.0) > 1.0:
			continue
		_put(cos(th) * radius, sin(th) * radius * SQUASH, W, 0.35 + 0.35 * pulse)

	# Motes coming off him - heat leaving, drawn as the only thing in this
	# game that falls upward.
	for i in MOTES:
		var age := fposmod(_time * 0.45 + float(_hash(i, 11) % 100) / 100.0, 1.0)
		var off := float(_hash(i, 13) % 100) / 100.0 - 0.5
		_put(off * 18.0, -age * MOTE_RISE, L if age < 0.5 else M,
			(1.0 - age) * 0.45)


## One world pixel, quantized. No mirroring: the aura is a circle round him and
## a circle does not care which way he is facing.
func _put(x: float, y: float, col: Color, alpha: float) -> void:
	if alpha <= FAINT:
		return
	draw_rect(Rect2(floorf(x), floorf(y), 1.0, 1.0), Color(col, alpha))


static func _hash(a: int, b: int) -> int:
	return absi((a * 73856093) ^ (b * 19349663)) % 2147483647
