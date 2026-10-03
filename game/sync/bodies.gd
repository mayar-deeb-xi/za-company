extends Node
## The party's bodies across machines: each one from its OWNER, its health from
## the HOST (sync.gd's header has the rule).
##
## - **Where it is and what it is drawing** goes from the owner's machine thirty
##   times a second (player.gd's net_state), to the host, which draws it and
##   passes it on to everybody else - a star, like everything online here.
##   Unreliable and ordered: a step that arrives late is worth nothing once the
##   next is in, and a lost one is replaced a frame later. Each step carries its
##   owner's time, which the host turns into its own before passing it on, so
##   every guest reads every body on the one clock (sync.gd's header).
## - **A body is in two places, on purpose** (M4): its BODY stands at the newest
##   step there is, and its PICTURE is drawn `DELAY` behind, gliding between two
##   steps (game/sync/timeline.gd, player.gd's net_draw). The body is what the
##   host decides with - an enemy's blow, a door, a pickup - so a guest who
##   stepped out of a swing is out of it on the host as soon as the wire allows,
##   and not a tenth of a second later. The picture is only looked at.
## - **Health** is the host's: every change to any body's goes to every guest.
## - **What the world did to a body** - a blow to show, a slow or a shove to
##   carry - goes to the one machine that owns it (player.gd's `reached`, and
##   net_reached() at the far end), and a blow or a drain is SEEN by everybody
##   else: the number over that body, and its grunt (net_seen()). Both on the
##   clock, so they land as the drawn blow does.
## - **A body nobody is hearing from is AWAY** (M6): a second with no step from
##   its owner and it is out of the fight (player.gd's `away`) - nobody's
##   target, nothing lands on it, no door waits for it - until its owner is
##   heard again. A machine that crashed or lost its line says nothing, and
##   the line itself can take many seconds to be given up on (`Net`); a body
##   standing in a fight all that time would be beaten down, and the pool
##   would pay for somebody who is not even there. Counted in this machine's
##   physics frames rather than read off a clock, so a hitch HERE - which
##   stops the frames as well as the hearing - never makes anybody else away.
##   And a new room starts everybody's count again, so loading one never does.

const PlayerType := preload("res://game/player/player.gd")
const Timeline := preload("res://game/sync/timeline.gd")
const Clock := preload("res://game/sync/clock.gd")

## How many physics frames between two of a body's steps: 30 a second.
const SEND_EVERY := 2
## How long without a step before a body is away - see the header. Thirty
## steps' worth: nothing a line merely having a bad moment loses.
const AWAY_SECONDS := 1.0

var _sync
## peer id -> body, for every member of the party.
var _bodies := {}
## peer id -> Timeline, for every body another machine moves.
var _steps := {}
## peer id -> the physics frame its newest step in this room was heard on.
var _heard := {}
var _frame := 0


func _ready() -> void:
	_sync = get_parent()


## The party, spawned. Wired once here, on every machine alike; offline every
## connection below is inert, because nobody is listening on the other end.
func track(party: Array) -> void:
	for body: PlayerType in party:
		_bodies[body.peer] = body
		body.health_changed.connect(_on_health_changed.bind(body))
		body.reached.connect(_on_reached.bind(body))
		if body.remote:
			_steps[body.peer] = Timeline.new()


func forget(peer: int) -> void:
	_bodies.erase(peer)
	_steps.erase(peer)
	_heard.erase(peer)


## A new room: the last one's steps are not drawn in it - a picture gliding
## from where somebody stood upstairs would cross this room to get here - and
## nobody is away for the time it took anybody to load it.
func new_room() -> void:
	for timeline: Timeline in _steps.values():
		timeline.clear()
	_heard.clear()


func body_of(peer: int) -> PlayerType:
	var body: PlayerType = _bodies.get(peer)
	return body if is_instance_valid(body) else null


func _physics_process(_delta: float) -> void:
	if not _sync.active:
		return
	_draw_bodies()
	_frame += 1
	if _frame % SEND_EVERY != 0:
		return
	var mine := body_of(Net.my_id())
	if mine == null:
		return
	if _sync.is_host():
		_relay(1, _sync.now(), mine.net_state())
	elif _sync.welcomed:
		rpc_id(1, &"_step", Net.my_id(), _sync.room, Clock.local(), mine.net_state())


## Every body another machine moves, drawn as it was `DELAY` ago - see the
## header.
func _draw_bodies() -> void:
	var at: float = _sync.drawn()
	var quiet := roundi(AWAY_SECONDS * Engine.physics_ticks_per_second)
	var frame := Engine.get_physics_frames()
	for peer in _steps:
		var body := body_of(peer)
		if body == null:
			continue
		body.set_away(_heard.has(peer) and frame - int(_heard[peer]) > quiet)
		var pick: Array = (_steps[peer] as Timeline).at(at)
		if pick.is_empty():
			continue
		var before: Array = pick[1]
		var where: Vector2 = before[0]
		if pick[2] != null:
			where = Timeline.point(before[0], pick[2][0], pick[3], pick[4])
		body.net_draw(before, where)


## The host passes a body's step on to every guest but its owner.
func _relay(peer: int, stamp: float, state: Array) -> void:
	for id in _sync.guests():
		if id != peer:
			rpc_id(id, &"_step", peer, _sync.room, stamp, state)


## One body's step, on any machine but its owner's. Dropped if it was taken in
## another room, or claims a body its sender does not own. The host hears it in
## the owner's time and passes it on in its own.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _step(peer: int, room: int, stamp: float, state: Array) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if room != _sync.room:
		return
	if _sync.is_host():
		if sender != peer:
			return
		stamp = _sync.from_guest(peer, stamp)
		_relay(peer, stamp, state)
	elif sender != 1:
		return
	else:
		_sync.heard(stamp)
	var body := body_of(peer)
	if body != null and body.remote:
		_heard[peer] = Engine.get_physics_frames()
		body.apply_net_state(state)
		(_steps[peer] as Timeline).add(stamp, state)


# --- the host's word ---------------------------------------------------------------


func _on_health_changed(health: int, _max_health: int, body: PlayerType) -> void:
	if _sync.active and _sync.is_host():
		for id in _sync.guests():
			rpc_id(id, &"_health", body.peer, _sync.now(), health)


## The world reached a body, on the host: its owner carries it, and everybody
## else sees a blow or a drain land on it.
func _on_reached(what: String, args: Array, body: PlayerType) -> void:
	if not _sync.active or not _sync.is_host():
		return
	for id in _sync.guests():
		if id == body.peer:
			rpc_id(id, &"_reached", body.peer, _sync.now(), what, args)
		elif what == "struck" or what == "drained":
			rpc_id(id, &"_seen", body.peer, _sync.now(), what, args)


@rpc("authority", "call_remote", "reliable")
func _health(peer: int, stamp: float, health: int) -> void:
	_sync.later(stamp, func() -> void:
		var body := body_of(peer)
		if body != null:
			body.net_health(health))


@rpc("authority", "call_remote", "reliable")
func _reached(peer: int, stamp: float, what: String, args: Array) -> void:
	_sync.later(stamp, func() -> void:
		var body := body_of(peer)
		if body != null and not body.remote:
			body.net_reached(what, args))


@rpc("authority", "call_remote", "reliable")
func _seen(peer: int, stamp: float, what: String, args: Array) -> void:
	_sync.later(stamp, func() -> void:
		var body := body_of(peer)
		if body != null and body.remote:
			body.net_seen(what, args))
