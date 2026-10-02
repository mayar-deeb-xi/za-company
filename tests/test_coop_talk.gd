extends "res://tests/coop.gd"
## Two machines in one run (DESIGN.md's Multiplayer, M3) - TALKING: whoever
## presses interact is the one talking and the one being led about, and
## everybody else keeps their hands and reads along (game/sync/talk.gd). The
## harness is tests/coop.gd.
##
## - **A prompt is this machine's**: it comes up for the player at THIS
##   keyboard, never for somebody else's body standing there.
## - **The guest talks to HR**: the conversation is the guest's, HR is busy on
##   the host, and the host reads her lines along on its subtitle.
## - **The talker leads her**: walked by the guest's machine, she walks on the
##   host's screen too - and once the guest is done she is the host's again.
## - **The host talks to HR**: and she is busy on the guest's machine.
## - **Ivan's gift is the host's**: a guest who talks him through is thrown his
##   hearts by the host, and they land on the guest's floor.

const CALL := "res://game/levels/call_center/call_center.tscn"
const HR := "Props/HrLady"


func _init() -> void:
	port = 47981


func _plan() -> Array[Callable]:
	return [_together, _guest_walks_up, _not_mine, _guest_talks, _host_waits,
		_reads_along, _guest_leads, _guest_done, _host_talks, _host_done,
		_to_call, _ivan, _guest_talks_to_ivan, _ivan_gives]


func _room_node(path: String) -> Node:
	var level := _level()
	return level.get_node_or_null(NodePath(path)) if level != null else null


func _guest_walks_up() -> void:
	var hr := _room_node(HR) as Node2D
	_tell("teleport", [hr.global_position + Vector2(0, 14)])
	_expect("prompt: the guest beside HR is offered her, on the guest's machine",
		"get", [HR + "/Prompt", ["visible"]], func(a) -> bool:
			return a is Array and a[0] == true)


func _not_mine() -> void:
	_check("prompt: and not on the host's, whose player is across the room",
		(_room_node(HR + "/Prompt") as Control).visible == false)


func _guest_talks() -> void:
	_tell("key", [KEY_E, true])
	_tell("key", [KEY_E, false])
	_expect("talk: the guest presses interact, and the conversation is the guest's",
		"talking", [], func(on: bool) -> bool: return on)


func _host_waits() -> void:
	_wait("talk: HR is the guest's to lead now, and busy on the host",
		func() -> bool:
			var hr := _room_node(HR)
			return hr.get("led_by") == _guest_id and hr.get("_talking") == true \
				and not current_scene.get_node("Dialogue").call("talking"))


func _reads_along() -> void:
	_wait("talk: and the host reads her lines along on its subtitle",
		func() -> bool:
			return _subtitle().call("showing") and _subtitle_line() != "")


func _guest_leads() -> void:
	var hr := _room_node(HR) as Node2D
	_mark = hr.global_position
	_tell("call", [HR, "walk_to", [hr.global_position + Vector2(-60, 0)]])
	_wait("talk: walked by the guest's machine, she walks on the host's screen",
		func() -> bool: return hr.global_position.x < _mark.x - 20.0)


func _guest_done() -> void:
	_tell("stop_talking")
	_wait("talk: and once the guest is done she is the host's again, free",
		func() -> bool:
			var hr := _room_node(HR)
			return hr.get("led_by") == 0 and hr.get("_talking") == false)


func _host_talks() -> void:
	var hr := _room_node(HR) as Node2D
	_tell("teleport", [Vector2(100, 300)])
	_player().global_position = hr.global_position + Vector2(0, 14)
	_since = _f
	_wait("talk: the host walks up and talks to her", func() -> bool:
		if _f - _since == 6:
			_key(KEY_E, true)
		elif _f - _since == 8:
			_key(KEY_E, false)
		return current_scene.get_node("Dialogue").call("talking"))


func _host_done() -> void:
	_expect("talk: and she is busy on the guest's machine", "get",
		[HR, ["_talking"]], func(a) -> bool: return a is Array and a[0] == true)


func _to_call() -> void:
	current_scene.get_node("Dialogue").call("stop")
	current_scene.call("_travel", CALL, &"start")
	_deadline = 600
	_wait("travel: the host takes the party to the call floor",
		func() -> bool: return _level() != null and _level().scene_file_path == CALL)


func _ivan() -> void:
	for node in get_nodes_in_group("enemies"):
		node.set("speed", 0.0)
	var room: int = _sync().get("room")
	_expect("travel: the guest arrives there in the same room", "where", [],
		func(a: Array) -> bool:
			if a.size() == 4 and a[2] == room:
				_room_node("Relief").call("_arrive")
				return true
			return false)


func _guest_talks_to_ivan() -> void:
	var ivan := _room_node("Props/Ivan") as Node2D
	_deadline = 600
	_since = _f
	_expect("ivan: the guest walks up to him and talks him through", "talking", [],
		func(on: bool) -> bool:
			# Up beside wherever he has got to, then the key, until he answers.
			if not on and (_f - _since) % 30 == 0:
				_tell("teleport", [ivan.global_position + Vector2(0, 14)])
				_tell("key", [KEY_E, true])
				_tell("key", [KEY_E, false])
			return on)


func _ivan_gives() -> void:
	_tell("stop_talking")
	_expect("ivan: and the host throws the hearts, which land on the guest's floor",
		"enemies", [], func(theirs: Dictionary) -> bool:
			var ivan := _room_node("Props/Ivan")
			return ivan != null and ivan.call("has_given") \
				and theirs.has("Props/IvansHeart1") and theirs.has("Props/IvansHeart2"))
