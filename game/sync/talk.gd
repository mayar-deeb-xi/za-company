extends Node
## Talking, across machines (DESIGN.md's Multiplayer, *Still to decide*, and its
## default): whoever presses interact is the one talking - and the one HR tows -
## and everybody else keeps their hands and reads along.
##
## - **The talker's machine runs the conversation**, as it always has: its own
##   dialogue director, its own box, its own choices, its own player led about.
## - **And it leads the NPC.** An NPC is the host's like anything in the room,
##   until somebody talks to it: then it is LENT to the talker (npc_base.gd's
##   `led_by`), whose machine walks it - HR's tour - and says where it is, and
##   the host draws it there and puts it in the snapshot for everybody else.
## - **It is busy for everybody else**: their prompt for it goes and their key
##   does nothing, until the talker is done. On the host that moment is
##   `set_talking` like any conversation's - which is when Ivan throws his
##   hearts, so a guest who talked to him is thrown them by the host.
## - **Everybody else reads along**: each line the talker is shown goes up on
##   the other machines' subtitles, which take nobody's hands.
##
## Who talks to whom first, when two press at once, is M6's.

## How many physics frames between two of a led NPC's steps: 20 a second.
const SEND_EVERY := 3

var _sync
var _game
var _frame := 0


func _ready() -> void:
	_sync = get_parent()
	_game = _sync.get_parent()
	if _sync.active and _sync.is_host():
		Net.peer_left.connect(_on_peer_left)


## This machine began a conversation with `npc`.
func began(npc: Node) -> void:
	var path := _path(npc)
	if not _sync.active or path == "":
		return
	if _sync.is_host():
		_sync.to_guests(&"_busy", [_sync.room, path, true], self)
	elif _sync.welcomed:
		npc.set("led_by", Net.my_id())
		rpc_id(1, &"_talking", _sync.room, path, true)


## ...and it is over.
func ended(npc: Node) -> void:
	var path := _path(npc)
	if not _sync.active or path == "":
		return
	if _sync.is_host():
		_sync.to_guests(&"_busy", [_sync.room, path, false], self)
	else:
		npc.set("led_by", 0)
		if _sync.welcomed:
			rpc_id(1, &"_talking", _sync.room, path, false)


## A line this machine's talker was just shown, for everybody else to read.
func spoke(speaker: String, text: String) -> void:
	if not _sync.active:
		return
	if _sync.is_host():
		_sync.to_guests(&"_line", [speaker, text], self)
	elif _sync.welcomed:
		rpc_id(1, &"_line", speaker, text)


func _physics_process(_delta: float) -> void:
	if not _sync.active or _sync.is_host() or not _sync.welcomed:
		return
	_frame += 1
	if _frame % SEND_EVERY != 0:
		return
	var level: Node = _sync.level()
	if level == null:
		return
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.get("led_by") == Net.my_id() and level.is_ancestor_of(npc):
			rpc_id(1, &"_npc_step", _sync.room, String(level.get_path_to(npc)),
				npc.call("net_state"))


# --- the host's side -----------------------------------------------------------


## A guest began or ended a conversation: the NPC is theirs to lead, or the
## host's again, and busy or free for everybody else.
@rpc("any_peer", "call_remote", "reliable")
func _talking(room: int, path: String, on: bool) -> void:
	var npc := _npc(room, path)
	if npc == null or not _sync.is_host():
		return
	var who := multiplayer.get_remote_sender_id()
	npc.set("led_by", who if on else 0)
	npc.call("set_talking", on)
	for id in _sync.guests():
		if id != who:
			rpc_id(id, &"_busy", room, path, on)


## Where the talker's machine has walked the NPC it is leading.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _npc_step(room: int, path: String, state: Array) -> void:
	var npc := _npc(room, path)
	if npc != null and npc.get("led_by") == multiplayer.get_remote_sender_id():
		npc.call("apply_net_state", state)


## A guest's talker leaving mid-conversation hands the NPC back.
func _on_peer_left(id: int) -> void:
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.get("led_by") == id:
			npc.set("led_by", 0)
			npc.call("set_talking", false)
			var path := _path(npc)
			if path != "":
				_sync.to_guests(&"_busy", [_sync.room, path, false], self)


# --- everybody's ---------------------------------------------------------------


@rpc("any_peer", "call_remote", "reliable")
func _busy(room: int, path: String, on: bool) -> void:
	var npc := _npc(room, path)
	if npc != null and multiplayer.get_remote_sender_id() == 1:
		npc.call("set_talking", on)


## A line somebody else is being told. The host passes a guest's on.
@rpc("any_peer", "call_remote", "reliable")
func _line(speaker: String, text: String) -> void:
	var who := multiplayer.get_remote_sender_id()
	if _sync.is_host():
		for id in _sync.guests():
			if id != who:
				rpc_id(id, &"_line", speaker, text)
	_game.net_line(speaker, text)


func _npc(room: int, path: String) -> Node:
	if room != _sync.room:
		return null
	var level: Node = _sync.level()
	var node := level.get_node_or_null(NodePath(path)) if level != null else null
	return node if node != null and node.is_in_group("npcs") else null


func _path(npc: Node) -> String:
	var level: Node = _sync.level()
	if npc == null or level == null or not level.is_ancestor_of(npc):
		return ""
	return String(level.get_path_to(npc))
