extends Node2D
## THE ARC's bolt - the lightning the combo's third hit throws between bodies.
##
## player.gd spawns one of these on the frame the arc lands, hands it the
## chains it struck (the hitbox, then each body the bolt reached, in order) and
## the character's spark colour, and forgets it: the bolt runs its own clock
## and frees itself. It is drawn live rather than baked into the sheet for the
## reason a boss's fire is - a line between two bodies has no fixed shape a
## 32 px cell could hold - and in the character's OWN colour for the reason
## the swing on the sheet is: Mayar's lightning is violet and Anas's is gold,
## and nobody should have to check who is holding the sword.
##
## Points arrive in WORLD pixels, so the node sits at the origin as a top-level
## canvas item and its parent's transform never enters into it. It draws two
## passes per segment - a 2 px edge in the spark colour darkened by the same
## fraction character_art.gd darkens the swing's edge, then a 1 px white core -
## and a 3 px white bloom on every body it struck. The jag is re-rolled every
## JITTER_STEP from a seed built out of the step and the segment, so the bolt
## flickers rather than boils and two frames inside one step draw the same
## line.

## How long the bolt is on screen, and from when it starts to fade.
const LIFETIME := 0.3
const FADE_FROM := 0.2
## How often the jag re-rolls. Six flickers across the lifetime.
const JITTER_STEP := 0.05
## Segments per bolt between two points, and how far a midpoint may sit off
## the straight line, in world pixels either side.
const MIDPOINTS := 4
const JITTER := 3.0
## The edge is the spark colour darkened by this - character_art.gd's
## SRC_VOLT_EDGE rule, so the bolt's edge is the swing's edge.
const EDGE_DARKEN := 0.38
const EDGE_WIDTH := 2.0
const BLOOM := 3.0
## Found by tests through this group; nothing in the game looks a bolt up.
const GROUP := "player_arcs"

var chains: Array[PackedVector2Array] = []
var colour := Color.WHITE
var _age := 0.0


func setup(paths: Array[PackedVector2Array], spark: Color) -> void:
	chains = paths
	colour = spark
	top_level = true
	position = Vector2.ZERO
	add_to_group(GROUP)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var alpha := 1.0
	if _age >= FADE_FROM:
		alpha = (LIFETIME - _age) / (LIFETIME - FADE_FROM)
	var edge := colour.darkened(EDGE_DARKEN)
	edge.a = alpha
	var core := Color(1.0, 1.0, 1.0, alpha)
	var step := int(_age / JITTER_STEP)
	var rng := RandomNumberGenerator.new()
	for c in chains.size():
		var chain := chains[c]
		for i in chain.size() - 1:
			rng.seed = step * 977 + c * 131 + i * 31
			var points := _jag(chain[i], chain[i + 1], rng)
			draw_polyline(points, edge, EDGE_WIDTH)
			draw_polyline(points, core, 1.0)
		for i in range(1, chain.size()):
			draw_rect(Rect2(chain[i] - Vector2.ONE, Vector2(BLOOM, BLOOM)), core)


## A jagged run from `a` to `b`: MIDPOINTS - 1 points between them, each pushed
## off the line by up to JITTER, snapped to whole pixels.
func _jag(a: Vector2, b: Vector2, rng: RandomNumberGenerator) -> PackedVector2Array:
	var points := PackedVector2Array([a])
	var along := b - a
	var across := Vector2(-along.y, along.x).normalized()
	for i in range(1, MIDPOINTS):
		var t := float(i) / MIDPOINTS
		var offset := (rng.randf() - 0.5) * 2.0 * JITTER
		points.append((a + along * t + across * offset).round())
	points.append(b)
	return points
