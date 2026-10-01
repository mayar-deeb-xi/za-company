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
##
## **It is the THUNDERCLAP now**, picked from the Combo Lab preview: the bolt
## grows forks off its midpoints and a 4 px glow in the spark colour under the
## edge, and lives 0.36 s rather than 0.3. The rest of the clap is not drawn
## here - the hit-stop, the shake and the screen flash are player.gd asking
## game.gd and screen_flash.gd, and the outline left on every body it touched
## is shock.gd.

## How long the bolt is on screen, and from when it starts to fade.
const LIFETIME := 0.36
const FADE_FROM := 0.26
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
## The glow under the edge, and the forks: a midpoint grows one FORK_CHANCE of
## the time, turned off the bolt by FORK_TURN plus up to FORK_SPREAD radians,
## FORK_MIN to FORK_MAX px long, with a bend half way.
const GLOW_WIDTH := 4.0
const GLOW_ALPHA := 0.35
const FORK_CHANCE := 0.6
const FORK_TURN := 0.5
const FORK_SPREAD := 0.6
const FORK_MIN := 4.0
const FORK_MAX := 10.0
const FORK_ALPHA := 0.9
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
			_forks(points, chain[i + 1] - chain[i], rng, Color(colour, alpha * FORK_ALPHA))
			draw_polyline(points, Color(colour, alpha * GLOW_ALPHA), GLOW_WIDTH)
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


## The dead-end branches off a bolt's midpoints. Drawn from the same rng the jag
## used, so they flicker on the same step as the line they hang off.
func _forks(points: PackedVector2Array, along: Vector2, rng: RandomNumberGenerator,
		ink: Color) -> void:
	var heading := along.angle()
	for k in range(1, points.size() - 1):
		if rng.randf() >= FORK_CHANCE:
			continue
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var dir := Vector2.from_angle(heading + side * (FORK_TURN + rng.randf() * FORK_SPREAD))
		var length := FORK_MIN + rng.randf() * (FORK_MAX - FORK_MIN)
		var bend := points[k] + dir * length * 0.5 + Vector2((rng.randf() - 0.5) * 2.0, 0.0)
		draw_polyline(PackedVector2Array([points[k], bend.round(),
			(points[k] + dir * length).round()]), ink, 1.0)
