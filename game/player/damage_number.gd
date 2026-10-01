extends Node2D
## The number that flies up off the player when a blow lands - "-18" in red,
## rising and fading over most of a second.
##
## It was picked off the Silverman attack preview, where it was drawn to make
## the hit checks readable and turned out to be the part worth keeping, so it
## is that preview's drawing shipped verbatim: the same 3x5 digits with a
## one-pixel dark outline, the same red, 14 px a second of rise, solid for half
## a second and gone by 0.8. A pixel font drawn as rects rather than a Label,
## because a Label's font is antialiased at any size small enough to sit over
## a 32 px body, and this one is the game's own pixels.
##
## **Blows only.** player.gd spawns one from `take_damage()` past the grace
## window - so a blow the window swallowed shows nothing, which is the truth -
## and never from `drain()`. A drain lands every physics frame at one point a
## time, so a number per tick is sixty a second of "-1" stacked on the head;
## the same reason a drain is silent. The thing draining you is already the
## thing on screen.
##
## It is `top_level`, so it stays where the blow landed while the player walks
## out from under it rather than riding along like a hat, and it sits at a
## high `z_index` so a prop the player is standing behind cannot hide it. It
## frees itself.

## Where it starts, above the body's origin: 6 px over the top of a 32 px cell
## drawn at offset -8, which is where the preview put it.
const RISE_FROM := Vector2(0.0, -30.0)
## World px per second.
const RISE_SPEED := 14.0
const LIFE := 0.8
## Fully opaque until here, then linear to nothing at LIFE.
const FADE_FROM := 0.5
const COLOUR := Color("ff7a7a")
const OUTLINE := Color("07080c")
## Above everything standing in a room.
const Z := 50

## 3x5 glyphs, row-major, "1" is ink. Only what a damage number can spell.
const GLYPHS := {
	"0": "111101101101111", "1": "010110010010111", "2": "111001111100111",
	"3": "111001111001111", "4": "101101111001001", "5": "111100111001111",
	"6": "111100111101111", "7": "111001001001001", "8": "111101111101111",
	"9": "111101111001111", "-": "000000111000000",
}

## What it says. Set by `spawn()`; read by tests.
var text := ""
var _age := 0.0


## One number for a blow of `amount`, over `body`. Parented to the body so it
## goes wherever the body's world goes (a door swaps the level, not the
## player), but top-level so it does not follow the body about.
static func spawn(body: Node2D, amount: int) -> Node2D:
	var node: Node2D = (load("res://game/player/damage_number.gd") as GDScript).new()
	node.text = "-%d" % amount
	node.top_level = true
	node.z_index = Z
	body.add_child(node)
	node.global_position = (body.global_position + RISE_FROM).round()
	return node


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var alpha := 1.0 - clampf((_age - FADE_FROM) / (LIFE - FADE_FROM), 0.0, 1.0)
	var width := text.length() * 4 - 1
	var origin := Vector2(-floorf(width / 2.0), -roundf(_age * RISE_SPEED))
	var ink := Color(COLOUR, alpha)
	var edge := Color(OUTLINE, alpha)
	# Outline first, everywhere, then the ink over it - so where two strokes'
	# outlines overlap a neighbour's ink, the ink wins.
	for pass_ink in [false, true]:
		for i in text.length():
			var glyph: String = GLYPHS.get(text[i], "")
			for k in glyph.length():
				if glyph[k] != "1":
					continue
				var at := origin + Vector2(i * 4 + k % 3, floori(k / 3.0))
				if pass_ink:
					draw_rect(Rect2(at, Vector2.ONE), ink)
				else:
					for off in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
						draw_rect(Rect2(at + off, Vector2.ONE), edge)
