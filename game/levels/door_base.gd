extends Area2D
class_name DoorBase
## Base for every level's own door scene: the one thing doors must agree on is
## how they tell game.gd that the player walked into them.
##
## Each level owns its `door.tscn` outright - its own art, collision and extra
## nodes - and a level that needs different behaviour (a lock, a key, a one-way
## passage) writes its own script extending this one and swaps it in. Only the
## `travelled` handshake has to stay the same, because game.gd is what does the
## swapping.
##
## The doorway sits in a gap cut through the wall ring, so the scene carries its
## own `Seal` body across that gap: the map stays closed whether or not the
## transition fires, and that same body is what keeps a locked door solid.

signal travelled(level_path: String, spawn: StringName)

@export_file("*.tscn") var target_level: String
## Name of the Marker2D under the destination level's Spawns node.
@export var target_spawn: StringName = &"start"
## Which of the level's doorway textures this instance wears.
@export var art: Texture2D

## Latched because the threshold sits right against a solid seal: without it, a
## player nudged back onto it mid-fade would queue a second travel. Physics is
## frozen on the player for that whole fade, so nothing can leave the threshold
## while the latch matters.
var _used := false


func _ready() -> void:
	$Sprite2D.texture = art
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if _used or not can_travel() or not body.is_in_group("player"):
		return
	_used = true
	travelled.emit(target_level, target_spawn)


## Stepping off the threshold re-arms the door, and the case that needs it is
## not the obvious one: a level is swapped in while the arriving player still
## carries the position they had when the LAST door fired, which for two doors
## in the same place in both rooms is right on top of this one. That fires the
## new level's door during the transition, where game.gd is still travelling and
## drops it - so without re-arming, the door ahead of you is spent before you
## ever walk to it, and the chain dead-ends at the second room.
func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_used = false


## Override point for locked doors: return false and the player walks into the
## threshold with nothing happening.
func can_travel() -> bool:
	return true
