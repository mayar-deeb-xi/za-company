extends StaticBody2D
class_name Column
## A pillar the player collides with at the base and walks behind higher up.
##
## The node origin sits at the foot of the column, which is what Y-sorting reads
## to decide whether the player draws in front of it or behind it.

## Set per level so one column scene serves every biome.
@export var art: Texture2D


func _ready() -> void:
	$Sprite2D.texture = art
