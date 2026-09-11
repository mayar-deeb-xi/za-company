extends "res://game/npcs/npc_base.gd"
## Ivan, and the one thing he does that no other NPC does: he heals you.
##
## Everything else about him IS npc_base - he stands where he is put, he carries
## a conversation he does not run, he is in `npcs` and in neither `player` nor
## `enemies`. This file is the gift and nothing else, which is why the other two
## still have no script of their own.
##
## ## He gives at the END of the conversation, and the conversation tells him
##
## The director calls `set_talking()` on both edges of a talk (npc_base), so the
## falling edge IS "he has finished saying it". No new signal, no beat key that
## spawns a pickup, and nothing in the dialogue system learns that hearts exist.
## The last word of his lines is DESIGN.md's one line for him - "Eat." - and the
## hearts land on it.
##
## ## One heart per head, and once
##
## The count is game/heads.gd, the same number a floor's second beat scales its
## arrivals by, read in the other direction: four players sharing one heart is
## the same unfairness as one player facing four times the bodies. A beat is
## careful to add BODIES and never a worse one; this is the matching care on the
## healing side, and the two reading one function is the whole point of that
## function being a file.
##
## He gives ONCE. Talk to him again and he says it again and hands over nothing,
## because he is a lifeline and not a fountain - a room that can be farmed for
## health is a room with no fight in it. "Once" resets when the level does:
## rooms are re-instantiated on every entry (see the root CLAUDE.md), so walking
## a floor again is walking up to a man who has not seen you yet. That is the
## same forgetfulness a consumed pickup already has, not a new rule.

const Heads := preload("res://game/heads.gd")
const Hearts := preload("res://game/npcs/ivan/hearts.gd")

## Hearts per head. One is the tuned number - a heart is 25 against a 100 bar,
## so a floor's relief is a quarter of it back - and the export is here so a
## floor that has earned more can say so in its own biome data rather than by
## standing a second Ivan in the room.
@export var hearts_per_head := 1

## npc_base keeps its own `_talking` for the prompt; this is the EDGE, which is
## what a gift needs and a prompt does not.
var _was_talking := false
var _given := false


func set_talking(talking: bool) -> void:
	var finished := _was_talking and not talking
	_was_talking = talking
	super.set_talking(talking)
	if finished and not _given:
		_given = true
		Hearts.throw(self, Heads.count(get_tree()) * hearts_per_head, _aim())


## Whether he has already given. For the tests, and for the day a floor wants to
## ask before it walks him in again.
func has_given() -> bool:
	return _given


## Who the hearts are thrown to. The player, and the middle of the room when
## there is somehow nobody - which is not a case this game has, but it is the
## difference between a fallback and a crash the day it gets one.
func _aim() -> Vector2:
	for node in get_tree().get_nodes_in_group("player"):
		var body := node as Node2D
		if body != null:
			return body.global_position
	var level := get_parent().get_parent()
	if level != null and level.has_method("bounds"):
		return (level.call("bounds") as Rect2).get_center()
	return global_position + Vector2(0, 24)
