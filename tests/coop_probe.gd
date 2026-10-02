extends Node
## The line between tests/test_coop.gd and the guest it starts (coop_guest.gd):
## the same node at /root/CoopProbe in both processes, so the suite can ASK the
## guest what its machine shows - where its body is, how much health it has, which
## floor it is on - and tell it what to press. Every check is the suite's; the
## guest only answers.
##
## It also holds both processes to the WALL CLOCK. A headless --fixed-fps run
## goes as fast as it can, and two of them would go at two different speeds
## while their messages cross in real time - so every frame here waits until
## its sixtieth of a second has really passed, and the two ends agree about
## how long anything took.

const STEP_MS := 1000.0 / 60.0

## Answers the guest has sent back, by question number. Read by the suite.
var answers := {}
var _asked := 0
var _since := 0
var _frames := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_since = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	_frames += 1
	var due := _since + roundi(_frames * STEP_MS)
	var now := Time.get_ticks_msec()
	if due > now:
		OS.delay_msec(due - now)


## Ask the machine `peer` something; its answer lands in `answers` under the
## number this returns.
func ask(peer: int, what: String, args: Array = []) -> int:
	_asked += 1
	rpc_id(peer, &"_ask", _asked, what, args)
	return _asked


@rpc("any_peer", "call_remote", "reliable")
func _ask(id: int, what: String, args: Array) -> void:
	var value: Variant = _answer(what, args)
	rpc_id(multiplayer.get_remote_sender_id(), &"_told", id, value)
	if what == "quit":
		_leave_and_quit.call_deferred()


## Out of the party first, so the host hears the line go now rather than when
## ENet gives up on a silent peer - then a few frames for the word to get out.
func _leave_and_quit() -> void:
	get_tree().root.get_node("/root/Net").call("leave")
	for i in 10:
		await get_tree().process_frame
	get_tree().quit(0)


@rpc("any_peer", "call_remote", "reliable")
func _told(id: int, value: Variant) -> void:
	answers[id] = value


# --- the guest's side ------------------------------------------------------------


func _answer(what: String, args: Array) -> Variant:
	var game := get_tree().current_scene
	var sync: Node = game.get_node_or_null("Sync") if game != null else null
	match what:
		"where":
			var level := _level(game)
			return [game.scene_file_path if game != null else "",
				sync != null and bool(sync.get("welcomed")),
				int(sync.get("room")) if sync != null else -1,
				String(level.name) if level != null else ""]
		"body":
			var body := _body(sync, int(args[0]))
			if body == null:
				return []
			return [body.global_position, int(body.get("health")), body.call("is_down"),
				bool(body.get("remote")), float(body.get("slow_factor")),
				float(body.get("_grace")) > 0.0]
		"lives":
			return int(game.get("lives")) if game != null else -1
		"rows":
			var out := []
			if game != null:
				for row: Node in game.get_node("HUD/Hud").call("party_rows"):
					out.append((row.get_node("Name") as Label).text)
			return out
		"over":
			var menu := game.get_node_or_null("PauseMenu") if game != null else null
			if menu == null:
				return []
			return [menu.call("is_paused"), (menu.get_node("%Heading") as Label).text,
				get_tree().paused]
		"key":
			var ev := InputEventKey.new()
			ev.physical_keycode = int(args[0])
			ev.keycode = int(args[0])
			ev.pressed = bool(args[1])
			Input.parse_input_event(ev)
			return true
		"teleport":
			var mine := _body(sync, multiplayer.get_unique_id())
			if mine != null:
				mine.global_position = args[0]
			return mine != null
		"hurt_self":
			# The world on a guest reaches nobody: this is that rule, asked.
			var mine := _body(sync, multiplayer.get_unique_id())
			if mine == null:
				return -1
			mine.call("take_damage", int(args[0]))
			mine.call("drain", int(args[0]))
			mine.call("heal", int(args[0]))
			return int(mine.get("health"))
		"quit":
			return true
	return null


func _body(sync: Node, peer: int) -> Node2D:
	return sync.call("body_of", peer) if sync != null else null


func _level(game: Node) -> Node:
	if game == null:
		return null
	for child in game.get_children():
		if child is Node2D and child.has_method("spawn_position"):
			return child
	return null
