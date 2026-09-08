extends "res://game/levels/door_base.gd"
## The north door of a boss floor: shut until the boss concedes.
##
## Nothing here is wired by signal. The door asks its level's `Boss` sibling
## (build_levels.gd names the boss instance that, right beside the doors under
## Props) whether it has conceded, on every attempt to walk through - so the
## door and the boss never have to find each other at the right moment, and a
## room built without a boss simply opens. The `Seal` body door_base.gd already
## carries across the doorway is what makes "shut" solid: the player walks into
## the threshold and nothing happens, exactly as the base promises for a lock.

func can_travel() -> bool:
	var boss := get_parent().get_node_or_null("Boss")
	return boss == null or boss.get("has_conceded") == true
