extends Node
## The room's moving parts across machines - every enemy and boss, and anything
## else that says it is `synced` - from the HOST (sync.gd's header has the rule).
##
## ## One snapshot is the whole truth
##
## Twenty times a second the host sends ONE message holding every synced thing
## in the room: its path in the level, and what it looks like now (its own
## net_state()). A guest draws each one where the host says - and that one
## message is also the only word there is on what EXISTS:
##
## - **Something the guest does not have** was spawned mid-room on the host - a
##   reinforcement walking in, Ivan, a heart he threw - and its entry carries the
##   scene it came from, so the guest makes one at the same path. A thing the
##   level placed carries nothing: every machine built the same level.
## - **Something the guest has and the snapshot does not** is gone on the host -
##   killed, picked up, walked out - and goes here too.
##
## No spawn message and no despawn message, so none that can be lost, arrive
## out of order against the snapshots, or be missed by a guest still fading in
## from the last floor: whatever the guest missed, the next snapshot has.
## Unreliable and ordered, because a picture that arrives late is worth nothing
## once the next one is in - and compressed, because a floor of a dozen bodies
## is already past one packet, and a packet split in two is twice as likely to
## be lost. Paths and animation names repeat in every entry, so it squeezes.
##
## ## A guest's swing
##
## "My swing reached enemy X" is the attacker's to say and the host's to apply
## (DESIGN.md's *Who decides what*): a guest's player reports each blow it lands
## (player.gd's `landed`) by path, and the host deals it. On the guest's own
## screen it lands at once, on the benefit of the doubt.
##
## ## A moment
##
## What a snapshot cannot carry is a MOMENT - a line a boss shouts, a fire he
## throws, a shake, a sound - because by the next picture it is over. So a
## synced thing on the host may also `tell()` the guests one, reliably, and the
## same thing on each guest hears it in net_event(). It is reached through the
## `sync` group (enemy_base.gd's `_tell`), so nothing that tells knows this file
## exists, and a body named in a moment travels as WHO it is rather than as an
## object: a player as their peer, anything in the room as its path.

## What a thing does to be in the snapshot: join this group and answer
## net_state() / apply_net_state(). Optionally net_spawn(), the properties a
## guest needs set before a mid-room arrival enters its tree, and net_gone(),
## what being gone looks like rather than simply vanishing.
const GROUP := &"synced"
## How many physics frames between two snapshots: 20 a second.
const SEND_EVERY := 3

var _sync
var _frame := 0


func _ready() -> void:
	_sync = get_parent()
	add_to_group(&"sync")


## The body this machine moves: on a guest, its blows are reported from here.
func track(mine: Node) -> void:
	if mine != null and mine.has_signal(&"landed"):
		mine.connect(&"landed", _on_landed)


func _physics_process(_delta: float) -> void:
	if not _sync.active or not _sync.is_host():
		return
	_frame += 1
	if _frame % SEND_EVERY != 0 or _sync.guests().is_empty():
		return
	var level: Node = _sync.level()
	if level == null:
		return
	var snap := {}
	for node in get_tree().get_nodes_in_group(GROUP):
		if node.is_queued_for_deletion() or not level.is_ancestor_of(node):
			continue
		var made: Variant = null
		# Owned by nothing is not from the level's file: it arrived mid-room.
		if node.owner == null and node.scene_file_path != "":
			made = [node.scene_file_path,
				node.call("net_spawn") if node.has_method("net_spawn") else {}]
		snap[String(level.get_path_to(node))] = [made, node.call("net_state")]
	var raw := var_to_bytes(snap)
	_sync.to_guests(&"_snapshot", [_sync.room, raw.size(),
		raw.compress(FileAccess.COMPRESSION_DEFLATE)], self)


@rpc("authority", "call_remote", "unreliable_ordered")
func _snapshot(room: int, size: int, packed: PackedByteArray) -> void:
	if room != _sync.room:
		return
	var level: Node = _sync.level()
	if level == null:
		return
	var snap: Variant = bytes_to_var(packed.decompress(size, FileAccess.COMPRESSION_DEFLATE))
	if not snap is Dictionary:
		return
	for path: String in snap:
		var entry: Array = snap[path]
		var node := level.get_node_or_null(NodePath(path))
		if node == null:
			if entry[0] == null:
				# Placed by the level, and already gone here: nothing to make.
				continue
			node = _make(level, path, entry[0])
			if node == null:
				continue
		if node.has_method("apply_net_state"):
			node.call("apply_net_state", entry[1])
	for node in get_tree().get_nodes_in_group(GROUP):
		if node.is_queued_for_deletion() or not level.is_ancestor_of(node):
			continue
		if not snap.has(String(level.get_path_to(node))):
			if node.has_method("net_gone"):
				node.call("net_gone")
			else:
				node.queue_free()


## A mid-room arrival, made on a guest the way the host made it: the same
## scene, at the same path, with whatever it needs set before it goes in.
func _make(level: Node, path: String, made: Array) -> Node:
	var cut := path.rfind("/")
	var parent := level if cut < 0 else level.get_node_or_null(NodePath(path.left(cut)))
	var scene := load(String(made[0])) as PackedScene
	if parent == null or scene == null:
		return null
	var node := scene.instantiate()
	node.name = path.substr(cut + 1)
	var props: Dictionary = made[1]
	for key in props:
		node.set(key, props[key])
	parent.add_child(node)
	return node


# --- a moment --------------------------------------------------------------------


## The host: `node` has something to tell the guests - see the header.
func tell(node: Node, what: String, args: Array) -> void:
	if not _sync.active or not _sync.is_host() or _sync.guests().is_empty():
		return
	var level: Node = _sync.level()
	if level == null or not level.is_ancestor_of(node):
		return
	var wired := []
	for arg in args:
		wired.append(_wire(arg, level))
	_sync.to_guests(&"_event", [_sync.room, String(level.get_path_to(node)), what, wired], self)


@rpc("authority", "call_remote", "reliable")
func _event(room: int, path: String, what: String, args: Array) -> void:
	if room != _sync.room:
		return
	var level: Node = _sync.level()
	var node := level.get_node_or_null(NodePath(path)) if level != null else null
	if node == null or not node.has_method("net_event"):
		return
	var unwired := []
	for arg in args:
		unwired.append(_unwire(arg, level))
	node.call("net_event", what, unwired)


## A body as WHO it is, which means the same on both ends: a player by their
## peer, anything in the room by its path there. Everything else as it is, and
## a dictionary's values the same way.
func _wire(value: Variant, level: Node) -> Variant:
	if value is Dictionary:
		var out := {}
		for key in value:
			out[key] = _wire(value[key], level)
		return out
	if value is Node:
		var node := value as Node
		if node.is_in_group("player") or node.get("peer") != null and node.has_method("net_state"):
			return {"__peer": int(node.get("peer"))}
		if level.is_ancestor_of(node):
			return {"__path": String(level.get_path_to(node))}
		return null
	return value


func _unwire(value: Variant, level: Node) -> Variant:
	if value is Dictionary:
		if value.has("__peer"):
			return _sync.body_of(int(value["__peer"]))
		if value.has("__path"):
			return level.get_node_or_null(NodePath(String(value["__path"])))
		var out := {}
		for key in value:
			out[key] = _unwire(value[key], level)
		return out
	return value


# --- a guest's swing ---------------------------------------------------------------


func _on_landed(body: Node, power: int) -> void:
	var level: Node = _sync.level()
	if not _sync.active or _sync.is_host() or not _sync.welcomed or level == null \
			or not level.is_ancestor_of(body):
		return
	rpc_id(1, &"_hit", _sync.room, String(level.get_path_to(body)), power)


@rpc("any_peer", "call_remote", "reliable")
func _hit(room: int, path: String, power: int) -> void:
	if not _sync.is_host() or room != _sync.room:
		return
	var level: Node = _sync.level()
	var node := level.get_node_or_null(NodePath(path)) if level != null else null
	if node != null and node.is_in_group("enemies") and node.has_method("take_damage"):
		node.call("take_damage", power)
