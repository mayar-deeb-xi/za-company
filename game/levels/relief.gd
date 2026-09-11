extends Node2D
## A room's THIRD beat: the one that is not a fight. When the floor is finally
## clear, Ivan walks in through the door the player came by, crosses to a spot
## somebody chose, and waits there with a heart per head.
##
## ## Why it is a beat and not a placement
##
## Standing him in the room from the first frame would make him furniture in a
## fight - a solid 64px body in a room whose enemy positions were picked against
## sight radii and clear lanes, and a heart on offer while the arrangement the
## floor is FOR is still standing. The whole of what makes his healing a
## lifeline rather than a supply is that it arrives after the cost has been
## paid. So he is an arrival, exactly like the bodies in reinforcements.gd, and
## he has an authored destination rather than an authored position for exactly
## the reason they have neither: you cannot walk in at a spot.
##
## It is also why he belongs beside that file instead of inside it. A beat there
## is one question - is the fight far enough along - and this is the opposite
## one: is it over. Threading a friendly body through a script that spawns
## enemies would have cost both of them their one sentence.
##
## ## "Over" has to mean over, on both kinds of floor
##
## `_hostiles()` counts the `enemies` group and skips anybody who has conceded,
## which is what makes one definition serve a boss floor and an ordinary one. A
## boss is in that group and is never freed - he is still standing in the room
## when you leave - so counting the group alone can never reach zero on the four
## floors that have one. Skipping the conceded is the whole difference.
##
## Two more things have to be true before it is over, and each of them was a
## way of getting this wrong:
##
## - **He waits until he has seen a fight.** A room is clear on its first frame
##   too, and an Ivan who walks in before anything has happened is a vending
##   machine in a doorway. `_fought` latches the first frame a hostile is
##   standing, so the cue is a room that has been emptied rather than a room
##   that is empty.
## - **He waits for the beats to be spent.** A floor with reinforcements is
##   quiet between the last kill of the opening arrangement and the arrival of
##   the group it cues, and quiet is not clear. He asks the sibling node
##   (`spent()`), the same ask-don't-listen shape the boss door and the beats
##   themselves use - and a floor with no beat simply has no node to ask.
##
## ## The walk can fail, and it is allowed to
##
## NPCs have no pathfinding - they slide off whatever they touch, like the
## enemies do - so a route that clips a plant pot after a prop is nudged would
## otherwise leave him walking into it forever. WALK_TIMEOUT stops him where he
## got to, which costs a slightly wrong spot rather than a heal the player
## cannot reach. The dialogue director guards its own walks the same way and for
## the same reason.
##
## ## He does not start the conversation himself
##
## `greets` exists on npc_base and is deliberately not used here. It fires on
## the talk radius being ENTERED, and a man who is walking across the room drags
## that radius over the player on the way - so a greeting would land mid-stride,
## halfway to where he was going. The deeper reason is the lobby's: a
## conversation that starts itself takes the wheel off a player who has not
## pressed anything, and the player has just finished a fight. The prompt over
## his head is the invitation, and taking it is theirs.

const NPC_SCENE := "res://game/npcs/%s/%s.tscn"

## How long he may spend crossing the room before he gives up and stands where
## he is. Generous: the longest honest walk on any floor is the full height of a
## room at 45px/s, about seven seconds.
const WALK_TIMEOUT := 12.0

## Authored per floor as `relief` in tools/biomes/<level>.gd and written in by
## build_levels.gd:
##
##   npc      a folder under game/npcs/ (only Ivan heals, but nothing here
##            names him)
##   from     the spawn marker he walks in through - "start" is the south door
##   at       where he stands afterwards, in level pixels
##   say      the .gd of beats he carries (game/dialogue/dialogue_director.gd)
@export var npc := "ivan"
@export var from: StringName = &"start"
@export var at := Vector2.ZERO
@export_file("*.gd") var say := ""

## Latched the first frame this room has somebody standing in it - see the
## header. Until then there has been no fight to be after.
var _fought := false
var _npc: Node2D = null
var _walked := 0.0


func _process(delta: float) -> void:
	if _npc != null:
		_cross(delta)
		return
	if _hostiles() > 0:
		_fought = true
		return
	if not _fought or not _beats_spent():
		return
	_arrive()


## Everyone in the room who is still a threat. A conceded boss is not one, which
## is the one line that lets a boss floor reach this cue at all.
func _hostiles() -> int:
	var standing := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		if node.get("has_conceded") == true:
			continue
		standing += 1
	return standing


## Whether this floor's second beat is done with. Asked of the sibling rather
## than known, and a floor without one has nothing to wait for.
func _beats_spent() -> bool:
	var beats := get_parent().get_node_or_null("Reinforcements")
	if beats == null or not beats.has_method("spent"):
		return true
	return bool(beats.call("spent"))


func _arrive() -> void:
	var scene := load(NPC_SCENE % [npc, npc]) as PackedScene
	if scene == null:
		push_warning("%s: no npc scene for relief '%s'" % [get_parent().name, npc])
		set_process(false)
		return
	_npc = scene.instantiate() as Node2D
	_npc.name = npc.to_pascal_case()
	_npc.set("conversation", say)
	# Into Props, where the room's own people already are: that is the Y-sorted
	# branch, and anybody outside it draws through the furniture.
	get_parent().get_node("Props").add_child(_npc)
	_npc.global_position = _threshold()
	_npc.call("walk_to", at)
	_walked = 0.0


## Watches the walk in, and ends it one way or the other.
func _cross(delta: float) -> void:
	_walked += delta
	if bool(_npc.call("walking")) and _walked < WALK_TIMEOUT:
		return
	_npc.call("stop")
	# Turned to face the room he has just walked into rather than left looking
	# whichever way the last step went, which on a spot against a wall is at the
	# wall. The `facing` export every other NPC is placed with is no use to
	# somebody who arrives: it is applied in _ready, before he moves.
	var level := get_parent()
	if level != null and level.has_method("bounds"):
		_npc.call("face_towards", (level.call("bounds") as Rect2).get_center())
	set_process(false)


## Where he comes in. Asked of the level by name through has_method, the same
## way reinforcements.gd avoids typing a level: an unknown marker falls back to
## the middle of the room, so a typo in biome data costs a bad entrance rather
## than a crash.
func _threshold() -> Vector2:
	var level := get_parent()
	if level != null and level.has_method("spawn_position"):
		return level.call("spawn_position", from)
	return global_position
