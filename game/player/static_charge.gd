extends Node2D
## STATIC CHARGE - what the two light hits leave on a body for the arc to set
## off. The combo used to be three hits that did not know about each other;
## this is what gives it a shape: tag, tag, detonate.
##
## A swing or a rising slash that lands adds one charge to the body it struck
## (two at most), and the charge is drawn as that many PAIRS of sparks orbiting
## the chest in the striker's spark colour. When the arc lands, every charged
## body it touches discharges - a ring and a burst of sparks - and the arc's
## jump prefers a charged body to an uncharged one inside the same 40 px
## (player.gd's `_nearest_enemy`). That preference is the only logic here, and
## it is targeting rather than damage: every number on the 5 / 7 / 12 lattice
## is exactly what it was.
##
## It lives as a CHILD of the body it charges, so it follows the body and goes
## when the body does, and the enemy never learns it exists - nothing in
## enemy_base names it. player.gd finds it by node name (`of()`), the way the
## prop shelves are found by role.
##
## **A charge is the player's who laid it** (`by`). In a party one body can
## carry two - one per striker, each in its own colour - and an arc prefers,
## and sets off, only its own thrower's: your swings set up YOUR lightning,
## never your partner's. Picked over a shared charge, which made one player's
## light hits steer somebody else's chain. Every machine keeps it the same way,
## since a teammate's blow lays it there too (player.gd's net_event).
##
## Picked from the Combo Lab preview and shipped as previewed: 1.8 s to fade,
## a blink across the last 0.4 s, seven radians a second, 8 px by 3.

const NAME := "StaticCharge"
const MAX_CHARGES := 2
const SECONDS := 1.8
const BLINK_FROM := 0.4
const SPIN := 7.0
const ORBIT := Vector2(8.0, 3.0)
## Chest height above the feet, where the arc's bolt lands too.
const CHEST := Vector2(0.0, -10.0)

var charges := 0
var colour := Color.WHITE
## Who laid it: the striker's instance id - an id rather than the node, so a
## charge outliving a player who left the party holds nothing that is gone.
var by_id := 0
var _left := SECONDS
var _time := 0.0


## Adds one of `by`'s charges to `body`, making the node if `by` has none on it
## yet.
static func add_to(body: Node2D, spark: Color, by: Node) -> void:
	var node := of(body, by)
	if node == null:
		node = (load("res://game/player/static_charge.gd") as GDScript).new()
		node.name = "%s_%d" % [NAME, by.get_instance_id()]
		node.by_id = by.get_instance_id()
		node.colour = spark
		node.z_index = 1
		body.add_child(node)
	node.charges = mini(node.charges + 1, MAX_CHARGES)
	node._left = SECONDS


## The charge `by` left on `body`, or null - or anybody's, with no `by`.
static func of(body: Node, by: Node = null) -> Node2D:
	for child in body.get_children():
		if String(child.name).begins_with(NAME) and not child.is_queued_for_deletion() \
				and (by == null or int(child.get("by_id")) == by.get_instance_id()):
			return child
	return null


## The arc reached it. A ring and ten sparks, left in the body's world so they
## outlive a body the same arc killed, and the charge is spent.
func discharge() -> void:
	var at := global_position + CHEST
	var world := get_parent().get_parent()
	if world != null:
		var burst: Node2D = (load("res://game/player/spark_burst.gd") as GDScript).new()
		world.add_child(burst)
		burst.setup(at, colour)
	queue_free()


func _process(delta: float) -> void:
	_time += delta
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if _left < BLINK_FROM and int(_time * 16.0) % 2 == 1:
		return
	var n := charges * 2
	for i in n:
		var t := _time * SPIN + i * TAU / n
		var at := (CHEST + Vector2(cos(t) * ORBIT.x, sin(t) * ORBIT.y)).round()
		draw_rect(Rect2(at, Vector2.ONE), Color.WHITE if i % 2 == 1 else colour)
