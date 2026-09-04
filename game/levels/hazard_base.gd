extends Area2D
class_name HazardBase
## Base for every level's own touch hazard - the torch, and whatever a later
## biome burns, freezes or poisons with. Standing in it hurts.
##
## Shared for the same reason as door_base.gd: the one thing every hazard must
## agree on is how it talks to the player. It carries no timer of its own - it
## presses damage every physics frame and the player's grace window is what
## meters the drain, so every hazard in the game speeds up or slows down
## together by changing one player constant.
##
## Each level owns its hazard scene outright (art, shape, extra nodes), exactly
## like its door and column.

@export var damage := 10


func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.call("take_damage", damage)
