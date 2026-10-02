extends "res://tests/coop.gd"
## Two machines in one run (DESIGN.md's Multiplayer, M3) - the PARTY half: the
## bodies, and everything about them the host decides. The harness, and why it
## is two processes, is tests/coop.gd.
##
## - **In together**: START puts both into the game, the guest is welcomed to
##   the host's floor and room, and each machine's body is its own while the
##   other's is drawn where its owner says.
## - **Bodies from their owners**: the guest walks and the host sees it; the
##   host walks and the guest sees it.
## - **The host decides**: a blow on the guest's body, its slow, its shove and
##   its heal are the host's, and land on the guest's machine - while the
##   world on the guest's own machine hurts and heals nobody.
## - **Down and up**: a death in company is down on both, one life from the
##   shared pool on both, and up at the door on both three seconds later.
## - **The door**: it waits for both, the host's goes, and the guest arrives on
##   the same floor in the same room.
## - **Nothing pauses**: the host's pause menu opens over a running game, with
##   its own player's hands taken away.
## - **The end**: with the pool empty and both down the run is over on both.
## - **Leaving**: the guest's body leaves with the guest.

const STUDIO := "ContentStudio"


func _plan() -> Array[Callable]:
	return [_together, _bodies, _guest_walks, _guest_walked, _host_walks, _blow,
		_gate, _slow, _shove_mark, _shove, _heal, _down, _up, _lives_there,
		_through, _arrived, _pause, _unpause, _the_end, _over_on_guest,
		_guest_leaves, _gone]


func _bodies() -> void:
	var party: Array = current_scene.call("party")
	_check("host: one body per member, the guest's drawn from their machine",
		party.size() == 2 and _second() != null and _second().get("remote") == true
			and _second().get("peer") == _guest_id and _player().get("remote") == false)
	_expect("guest: the host's body is the remote one there", "body", [1],
		func(a: Array) -> bool: return a.size() == 6 and a[3] == true)


func _guest_walks() -> void:
	_mark = _second().global_position
	_tell("key", [KEY_D, true])
	_wait("bodies: the guest walks, and the host sees it",
		func() -> bool: return _second().global_position.x > _mark.x + 20.0)


func _guest_walked() -> void:
	_tell("key", [KEY_D, false])
	_expect("bodies: and the guest's own body is where the host drew it", "body",
		[_guest_id], func(a: Array) -> bool:
			return a.size() == 6 and a[3] == false \
				and (a[0] as Vector2).distance_to(_second().global_position) < 4.0)


func _host_walks() -> void:
	_mark = _player().global_position
	_key(KEY_A, true)
	_expect("bodies: the host walks, and the guest sees it", "body", [1],
		func(a: Array) -> bool:
			return a.size() == 6 and (a[0] as Vector2).x < _mark.x - 20.0)


func _blow() -> void:
	_key(KEY_A, false)
	_second().call("take_damage", 10)
	_check("host: the blow is decided here (%d)" % _second().get("health"),
		_second().get("health") == 90)
	_expect("host decides: the blow lands on the guest's machine, and blinks", "body",
		[_guest_id], func(a: Array) -> bool:
			return a.size() == 6 and a[1] == 90 and a[5] == true)


func _gate() -> void:
	_expect("guest: its own world hurts, drains and heals nobody", "hurt_self", [30],
		func(health: int) -> bool: return health == 90)


func _slow() -> void:
	_second().call("apply_slow", 0.5, 3.0)
	_expect("host decides: a slow is carried by the guest's own body", "body",
		[_guest_id], func(a: Array) -> bool: return a.size() == 6 and a[4] == 0.5)


func _shove_mark() -> void:
	_expect("guest: standing still before the shove", "body", [_guest_id],
		func(a: Array) -> bool:
			if a.size() != 6:
				return false
			_mark = a[0]
			return true)


func _shove() -> void:
	_second().call("shove", Vector2.RIGHT, 70.0)
	_expect("host decides: a shove moves the guest's own body", "body", [_guest_id],
		func(a: Array) -> bool:
			return a.size() == 6 and (a[0] as Vector2).x > _mark.x + 8.0)


func _heal() -> void:
	_second().call("heal", 10)
	_expect("host decides: a heal reaches the guest's machine", "body", [_guest_id],
		func(a: Array) -> bool: return a.size() == 6 and a[1] == 100)


func _down() -> void:
	_second().set("_grace", 0.0)
	_second().call("take_damage", 200)
	_check("host: a death in company is DOWN, and one life from the pool",
		_second().call("is_down") and current_scene.get("lives") == 2)
	_expect("guest: down on its own machine too, with the same pool", "body", [_guest_id],
		func(a: Array) -> bool: return a.size() == 6 and a[2] == true)


func _up() -> void:
	_deadline = 600
	_expect("guest: up at the door three seconds later, full health", "body",
		[_guest_id], func(a: Array) -> bool:
			return a.size() == 6 and a[2] == false and a[1] == 100 \
				and not _second().call("is_down"))


func _lives_there() -> void:
	_expect("guest: two lives left there too", "lives", [],
		func(n: int) -> bool: return n == 2)


func _through() -> void:
	_player().global_position = Vector2(266, 78)
	_tell("teleport", [Vector2(278, 78)])
	_key(KEY_W, true)
	_tell("key", [KEY_W, true])
	_deadline = 600
	_wait("door: it waits for both, and the host's takes the party up",
		func() -> bool: return _level() != null and String(_level().name) == STUDIO)


func _arrived() -> void:
	_key(KEY_W, false)
	_tell("key", [KEY_W, false])
	var room: int = _sync().get("room")
	_expect("door: the guest arrives on the same floor, in the same room", "where", [],
		func(a: Array) -> bool:
			return a.size() == 4 and a[3] == STUDIO and a[2] == room)


func _pause() -> void:
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	_key(KEY_D, true)
	_wait("pause: online the menu opens over a running game, hands taken",
		func() -> bool:
			# Measured from a few frames in, once the menu is up and has them.
			if _f - _since == 5:
				_mark = _player().global_position
			return _f - _since > 35 and _pause_menu().call("is_paused") \
				and not paused and _player().global_position.distance_to(_mark) < 0.5)


func _unpause() -> void:
	_key(KEY_D, false)
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	_wait("pause: and closes again, hands back",
		func() -> bool:
			return not _pause_menu().call("is_paused") \
				and current_scene.get("_hands") == null)


func _the_end() -> void:
	current_scene.set("lives", 0)
	_sync().call("lives_changed", 0)
	_second().set("_grace", 0.0)
	_second().call("take_damage", 200)
	_player().set("_grace", 0.0)
	_player().call("take_damage", 200)
	_wait("end: the pool empty and both down, the run is over here",
		func() -> bool:
			return _pause_menu().call("is_paused") and not paused \
				and (_pause_menu().get_node("%Heading") as Label).text == "YOU DIED")


func _over_on_guest() -> void:
	_expect("end: and over on the guest's machine, with nothing paused", "over", [],
		func(a: Array) -> bool:
			return a.size() == 3 and a[0] == true and a[1] == "YOU DIED" and a[2] == false)


func _guest_leaves() -> void:
	_tell("quit")
	_deadline = 600
	_wait("leaving: the guest's body leaves with them",
		func() -> bool:
			return _second() == null and (current_scene.call("party") as Array).size() == 1)


func _gone() -> void:
	var rows: Array = current_scene.get_node("HUD/Hud").call("party_rows")
	_check("leaving: and their row under the hearts goes too (%d)" % rows.size(),
		rows.is_empty())
