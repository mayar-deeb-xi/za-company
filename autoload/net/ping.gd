extends Node
## Each guest's ping to the host, measured by the game itself - WebRTC reports no
## round-trip time, so there is nothing to read off the transport. Counter-Strike
## shows every player's distance to the SERVER; here the host is the server, so
## every number is a distance to the host, and the host's own is zero.
##
## The host stamps a ping with its own clock once a second and the guest hands
## the stamp straight back: one clock, so nobody's clocks have to agree. Both
## legs ride the UNRELIABLE channel, as the game's own movement will - a ping
## that waited in line behind a resent packet would measure the line. A lost
## one simply never comes back.
##
## What it measures includes up to a frame at each end, since both sides read
## the network once a frame - which is also exactly how late the game itself
## hears anything, so it is the honest number for "how far behind am I".
##
## Must sit at the same node path on every machine, like anything with an RPC.
##
## It is also how long since anybody was last HEARD (`silent()`): the host
## hears each guest's pong and a guest hears the host's ping, once a second
## whatever else is going on - which makes it the one honest measure of a line
## that has gone dead without saying so (Net's `drop_seconds()`).

const INTERVAL := 1.0
const SAMPLES := 5

var _samples := {}  # peer id -> Array[float] of ms, newest last
## peer id -> Time.get_ticks_msec() when it was last heard, from `watch()` on.
var _heard := {}
## Peers given up on (Net's `_cut`), never pinged again: the transport can hold
## on to one for a while after, and a packet to a line going down is an error.
var _cut := {}
var _clock := 0.0


## Start counting how long `peer_id` goes unheard - from now, as if it had just
## spoken. The host watches each guest from its hello; a guest watches the host.
func watch(peer_id: int) -> void:
	_heard[peer_id] = Time.get_ticks_msec()


## Seconds since `peer_id` was last heard, or 0 for anybody not watched.
func silent(peer_id: int) -> float:
	if not _heard.has(peer_id):
		return 0.0
	return (Time.get_ticks_msec() - int(_heard[peer_id])) / 1000.0


## Never to be pinged again - see `_cut`.
func cut(peer_id: int) -> void:
	_cut[peer_id] = true
	forget(peer_id)


## Everybody forgotten - the party is over.
func clear() -> void:
	_samples.clear()
	_heard.clear()
	_cut.clear()
	_clock = 0.0


## The rolling average for a guest, in whole ms; -1 until the first one lands.
func ms(peer_id: int) -> int:
	var got: Array = _samples.get(peer_id, [])
	if got.is_empty():
		return -1
	var total := 0.0
	for sample: float in got:
		total += sample
	return roundi(total / got.size())


func forget(peer_id: int) -> void:
	_samples.erase(peer_id)
	_heard.erase(peer_id)


func _process(delta: float) -> void:
	if multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return
	_clock += delta
	if _clock < INTERVAL:
		return
	_clock = 0.0
	for peer_id in multiplayer.get_peers():
		if not _cut.has(peer_id):
			_ping.rpc_id(peer_id, Time.get_ticks_usec())


@rpc("authority", "call_remote", "unreliable")
func _ping(stamp: int) -> void:
	if _heard.has(1):
		_heard[1] = Time.get_ticks_msec()
	_pong.rpc_id(1, stamp)


@rpc("any_peer", "call_remote", "unreliable")
func _pong(stamp: int) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if _heard.has(peer_id):
		_heard[peer_id] = Time.get_ticks_msec()
	var got: Array = _samples.get(peer_id, [])
	got.append((Time.get_ticks_usec() - stamp) / 1000.0)
	if got.size() > SAMPLES:
		got.pop_front()
	_samples[peer_id] = got
