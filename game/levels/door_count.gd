extends Node2D
## "1/2" over a doorway: how many of the standing party are in it, out of how
## many there are. A door waits for the party (DESIGN.md's Multiplayer, *The
## rules of a party*), and a door that waits without saying so reads as a door
## that is broken - so whoever is standing in it is told what it is waiting for.
##
## It is up only while the door is part-full. Solo it never shows at all: one
## player standing in a doorway is the whole party, so the door goes at once,
## exactly as it always has.
##
## Drawn in the damage numbers' own 3x5 digits plus a slash, rather than as a
## Label, for their reason: a Label's font is antialiased at any size this
## small, and these are the game's own pixels. `top_level`, because the south
## door of every floor is the north one turned half a turn, and a count that
## turned with it would be upside down.

const DamageNumber := preload("res://game/player/damage_number.gd")
const SLASH := "001001010100100"
const INK := Color.WHITE
const EDGE := Color("07080c")

## What it says. Read by tests.
var text := ""


func show_count(here: int, of: int) -> void:
	text = "%d/%d" % [here, of]
	visible = true
	queue_redraw()


func _draw() -> void:
	var width := text.length() * 4 - 1
	var origin := Vector2(-floorf(width / 2.0), 0.0)
	# Outline first, everywhere, then the ink over it - damage_number.gd's
	# order, so the two read as one alphabet.
	for pass_ink in [false, true]:
		for i in text.length():
			var glyph: String = SLASH if text[i] == "/" \
				else String(DamageNumber.GLYPHS.get(text[i], ""))
			for k in glyph.length():
				if glyph[k] != "1":
					continue
				var at := origin + Vector2(i * 4 + k % 3, floori(k / 3.0))
				if pass_ink:
					draw_rect(Rect2(at, Vector2.ONE), INK)
				else:
					for off in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
						draw_rect(Rect2(at + off, Vector2.ONE), EDGE)
