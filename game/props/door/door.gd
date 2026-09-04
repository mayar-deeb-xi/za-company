extends Area2D
class_name Door
## An archway that moves the player to another level when they walk into it.
##
## The door only reports; game.gd owns the actual swap. That keeps levels free
## of any knowledge of the host scene, and means a door works the same whether
## it was placed by tools/build_levels.gd or dragged in by hand.

signal travelled(level_path: String, spawn: StringName)

@export_file("*.tscn") var target_level: String
## Name of the Marker2D under the destination level's Spawns node.
@export var target_spawn: StringName = &"start"
## Set per level so one door scene serves every biome.
@export var art: Texture2D

## Latched because the trigger sits in front of a solid wall: without it, a
## player nudged back onto the threshold mid-fade would queue a second travel.
var _used := false


func _ready() -> void:
	$Sprite2D.texture = art
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _used or not body.is_in_group("player"):
		return
	_used = true
	travelled.emit(target_level, target_spawn)
