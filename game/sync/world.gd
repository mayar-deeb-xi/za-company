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
## ## A beat behind, and between
##
## Each snapshot carries the host's time, and a guest shows it when its picture
## reaches that moment (sync.gd's *One clock*): a tenth of a second late, which
## is what buys a snapshot on both sides of the moment being drawn. In between,
## a thing that answers `net_between(a, b, weight)` is drawn on the way from
## one to the next - every enemy and boss, an NPC walking, a heart in the air, a
## scrubber - instead of stepping twenty times a second. Such a thing puts
## WHERE it stands first in its state, which is how a jump is told from a walk
## (game/sync/timeline.gd).
##
## **A CLOCK is not drawn behind.** The studio, the dolly and the wiring answer
## no `net_between`: they count their own time on every machine and are only
## put right when they have come apart (game/levels/CLAUDE.md's *Online*), so
## their state is taken the moment it is heard. Held back a tenth of a second,
## every correction would set them that much late - and a hazard drawn late is
## one that hurts before it is seen.
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
##
## ## A player's moment
##
## A player has moments too, and they are told by whoever MOVES that player
## (`from_player`), since nobody else knows them: a blow it landed and a bolt
## it threw (player.gd's `_tell`). They go through the host like everything, on
## the host's word (DESIGN.md's *Who decides what*):
##
## - **A guest's blow is also its swing.** "My swing reached enemy X" is the
##   attacker's to say and the host's to apply, so the host deals it, and only
##   then tells everybody what it did - the number, the jolt, the pieces if it
##   killed. On the guest's own screen it landed at once, on the benefit of the
##   doubt, so the guest is told back only whether it killed.
## - **The host's blow** was dealt where it was swung, and is told as it is.
## - **Everybody else draws it** with the attacker's body on their machine
##   (player.gd's net_event), in the attacker's colour and with its noise - on
##   the clock, so it lands as the drawn sword does.

## What a thing does to be in the snapshot: join this group and answer
## net_state() / apply_net_state(). Optionally net_spawn(), the properties a
## guest needs set before a mid-room arrival enters its tree, net_gone(), what
## being gone looks like rather than simply vanishing, and net_between(), how
## it is drawn between two snapshots (see *A beat behind*).
const GROUP := &"synced"
## How many physics frames between two snapshots: 20 a second.
const SEND_EVERY := 3

const Timeline := preload("res://game/sync/timeline.gd")

var _sync
var _frame := 0
## A guest's: the snapshots of this room, and the newest one shown.
var _frames := Timeline.new()
var _shown := -INF


func _ready() -> void:
	_sync = get_parent()
	add_to_group(&"sync")


## A new room: nothing from the last one is drawn in it.
func forget() -> void:
	_frames.clear()
	_shown = -INF


func _physics_process(_delta: float) -> void:
	if not _sync.active:
		return
	if not _sync.is_host():
		_draw_between()
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
	_sync.to_guests(&"_snapshot", [_sync.room, _sync.now(), raw.size(),
		raw.compress(FileAccess.COMPRESSION_DEFLATE)], self)


## A snapshot, heard: a clock takes it now, and everything else is shown when
## the picture gets there - see the header.
@rpc("authority", "call_remote", "unreliable_ordered")
func _snapshot(room: int, stamp: float, size: int, packed: PackedByteArray) -> void:
	if room != _sync.room:
		return
	var level: Node = _sync.level()
	if level == null:
		return
	var snap: Variant = bytes_to_var(packed.decompress(size, FileAccess.COMPRESSION_DEFLATE))
	if not snap is Dictionary:
		return
	for path: String in snap:
		var node := level.get_node_or_null(NodePath(path))
		if node != null and not node.has_method("net_between") \
				and node.has_method("apply_net_state"):
			node.call("apply_net_state", snap[path][1])
	_frames.add(stamp, snap)
	_sync.later(stamp, _show.bind(room, stamp, snap))


## One snapshot, as the picture reaches it: what it holds is drawn as it was,
## what it holds that is not here is made, and what is here that it does not
## hold is gone.
func _show(room: int, stamp: float, snap: Dictionary) -> void:
	if room != _sync.room or stamp <= _shown:
		return
	var level: Node = _sync.level()
	if level == null:
		return
	_shown = stamp
	for path: String in snap:
		var entry: Array = snap[path]
		var node := level.get_node_or_null(NodePath(path))
		var made := false
		if node == null:
			if entry[0] == null:
				# Placed by the level, and already gone here: nothing to make.
				continue
			node = _make(level, path, entry[0])
			if node == null:
				continue
			made = true
		# A clock took its state when it was heard (_snapshot).
		if node.has_method("apply_net_state") and (made or node.has_method("net_between")):
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


## Every frame on a guest: whatever answers net_between() drawn on its way from
## the snapshot on screen to the next one - see the header.
func _draw_between() -> void:
	var pick := _frames.at(_sync.drawn())
	if pick.is_empty() or pick[2] == null or float(pick[0]) > _shown:
		return
	var level: Node = _sync.level()
	if level == null:
		return
	var before: Dictionary = pick[1]
	var after: Dictionary = pick[2]
	for path: String in before:
		if not after.has(path):
			continue
		var node := level.get_node_or_null(NodePath(path))
		if node == null or not node.has_method("net_between"):
			continue
		var a: Array = before[path][1]
		var b: Array = after[path][1]
		var weight: float = pick[3]
		# Held, rather than slid, across a jump (game/sync/timeline.gd).
		if not a.is_empty() and a[0] is Vector2 and b[0] is Vector2 \
				and Timeline.jumped(a[0], b[0], pick[4]):
			weight = 0.0
		node.call("net_between", a, b, weight)


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
	_sync.to_guests(&"_event", [_sync.room, _sync.now(), String(level.get_path_to(node)),
		what, wired], self)


## Heard now, played when the picture reaches the moment it was told, so a fire
## he throws leaves the axe that is drawn throwing it.
@rpc("authority", "call_remote", "reliable")
func _event(room: int, stamp: float, path: String, what: String, args: Array) -> void:
	if room == _sync.room:
		_sync.later(stamp, _play.bind(room, path, what, args))


func _play(room: int, path: String, what: String, args: Array) -> void:
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
## a dictionary's values and an array's items the same way.
func _wire(value: Variant, level: Node) -> Variant:
	if value is Array:
		return (value as Array).map(func(item: Variant) -> Variant: return _wire(item, level))
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
	if value is Array:
		return (value as Array).map(func(item: Variant) -> Variant: return _unwire(item, level))
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


# --- a player's moment -------------------------------------------------------------


## The body this machine moves has a moment for the party - see the header. The
## host tells the guests; a guest tells the host, which takes it from there.
func from_player(body: Node, what: String, args: Array) -> void:
	var level: Node = _sync.level()
	if not _sync.active or level == null:
		return
	var wired := []
	for arg in args:
		wired.append(_wire(arg, level))
	if _sync.is_host():
		_sync.to_guests(&"_player_moment",
			[_sync.room, _sync.now(), int(body.get("peer")), what, wired], self)
	elif _sync.welcomed:
		rpc_id(1, &"_player_says", _sync.room, what, wired)


## A guest's moment, on the host. A blow is dealt here first - the one thing in
## any of this that decides anything - and is told on only if it did something;
## then the host draws it with the guest's body and tells everybody, the guest
## included, what it came to.
@rpc("any_peer", "call_remote", "reliable")
func _player_says(room: int, what: String, args: Array) -> void:
	if not _sync.is_host() or room != _sync.room:
		return
	var level: Node = _sync.level()
	var sender := multiplayer.get_remote_sender_id()
	var body: Node = _sync.body_of(sender)
	if level == null or body == null:
		return
	var told := []
	for arg in args:
		told.append(_unwire(arg, level))
	var skip := sender
	if what == "blow":
		if told.size() < 4:
			return
		var target: Node = told[0]
		if target == null or not target.is_in_group("enemies") or not target.has_method("take_damage"):
			return
		var before: Variant = target.get("health")
		target.call("take_damage", int(told[1]))
		var after: Variant = target.get("health")
		if before != null and after != null and int(after) >= int(before):
			return
		told = [target, told[1], told[2], told[3], target.is_queued_for_deletion()]
		# The attacker hears too: whether it killed is the host's to say.
		skip = 0
	body.call("net_event", what, told)
	var wired := []
	for arg in told:
		wired.append(_wire(arg, level))
	for id in _sync.guests():
		if id != skip:
			rpc_id(id, &"_player_moment", room, _sync.now(), sender, what, wired)


## A player's moment on a guest, played when the picture reaches it.
@rpc("authority", "call_remote", "reliable")
func _player_moment(room: int, stamp: float, peer: int, what: String, args: Array) -> void:
	if room == _sync.room:
		_sync.later(stamp, _player_play.bind(room, peer, what, args))


func _player_play(room: int, peer: int, what: String, args: Array) -> void:
	var level: Node = _sync.level()
	var body: Node = _sync.body_of(peer)
	if room != _sync.room or level == null or body == null:
		return
	var told := []
	for arg in args:
		told.append(_unwire(arg, level))
	body.call("net_event", what, told)
