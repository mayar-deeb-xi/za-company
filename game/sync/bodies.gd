extends Node
## The party's bodies across machines: each one from its OWNER, its health from
## the HOST (sync.gd's header has the rule).
##
## - **Where it is and what it is drawing** goes from the owner's machine thirty
##   times a second (player.gd's net_state), to the host, which draws it and
##   passes it on to everybody else - a star, like everything online here.
##   Unreliable and ordered: a step that arrives late is worth nothing once the
##   next is in, and a lost one is replaced a frame later.
## - **Health** is the host's: every change to any body's goes to every guest.
## - **What the world did to a body** the host does not own - a blow to show, a
##   slow or a shove to carry - goes to the one machine that owns it
##   (player.gd's `reached`, and net_reached() at the far end).

const PlayerType := preload("res://game/player/player.gd")

## How many physics frames between two of a body's steps: 30 a second.
const SEND_EVERY := 2

var _sync
## peer id -> body, for every member of the party.
var _bodies := {}
var _frame := 0


func _ready() -> void:
	_sync = get_parent()


## The party, spawned. Wired once here, on every machine alike; offline every
## connection below is inert, because nobody is listening on the other end.
func track(party: Array) -> void:
	for body: PlayerType in party:
		_bodies[body.peer] = body
		body.health_changed.connect(_on_health_changed.bind(body))
		if body.remote:
			body.reached.connect(_on_reached.bind(body))


func forget(peer: int) -> void:
	_bodies.erase(peer)


func body_of(peer: int) -> PlayerType:
	var body: PlayerType = _bodies.get(peer)
	return body if is_instance_valid(body) else null


func _physics_process(_delta: float) -> void:
	if not _sync.active:
		return
	_frame += 1
	if _frame % SEND_EVERY != 0:
		return
	var mine := body_of(Net.my_id())
	if mine == null:
		return
	if _sync.is_host():
		_relay(1, mine.net_state())
	elif _sync.welcomed:
		rpc_id(1, &"_step", Net.my_id(), _sync.room, mine.net_state())


## The host passes a body's step on to every guest but its owner.
func _relay(peer: int, state: Array) -> void:
	for id in _sync.guests():
		if id != peer:
			rpc_id(id, &"_step", peer, _sync.room, state)


## One body's step, on any machine but its owner's. Dropped if it was taken in
## another room, or claims a body its sender does not own.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _step(peer: int, room: int, state: Array) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if room != _sync.room:
		return
	if _sync.is_host():
		if sender != peer:
			return
		_relay(peer, state)
	elif sender != 1:
		return
	var body := body_of(peer)
	if body != null and body.remote:
		body.apply_net_state(state)


# --- the host's word ---------------------------------------------------------------


func _on_health_changed(health: int, _max_health: int, body: PlayerType) -> void:
	if _sync.active and _sync.is_host():
		for id in _sync.guests():
			rpc_id(id, &"_health", body.peer, health)


func _on_reached(what: String, args: Array, body: PlayerType) -> void:
	if _sync.active and _sync.is_host() and _sync.guests().has(body.peer):
		rpc_id(body.peer, &"_reached", body.peer, what, args)


@rpc("authority", "call_remote", "reliable")
func _health(peer: int, health: int) -> void:
	var body := body_of(peer)
	if body != null:
		body.net_health(health)


@rpc("authority", "call_remote", "reliable")
func _reached(peer: int, what: String, args: Array) -> void:
	var body := body_of(peer)
	if body != null and not body.remote:
		body.net_reached(what, args)
