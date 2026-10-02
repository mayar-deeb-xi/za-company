extends RefCounted
## One WebRTC connection between this machine and one other player, and which
## ROUTE it took - DIRECT or RELAY - which is the thing the game needs to say
## out loud and the thing Godot's WebRTC will not tell you.
##
## So the route is not asked, it is ARRANGED. A link connects in two stages:
##
##   1. STUN only. Every route but the relay is on the table - the same network,
##      or straight through both routers. Most players end here.
##   2. Only if stage 1 has not connected inside DIRECT_SECONDS (or failed
##      outright): again, with our TURN server added, and BOTH ends offering
##      ONLY their relay candidates, and dropping any other the far end sends.
##      That filter is what makes a stage-2 connection a relayed one for
##      certain rather than probably.
##
## Both ends, not one, and the first test run is why. Filtering only the guest
## was the original design - one relay hop instead of two - and it connected
## with NO TURN server running at all: ICE learns a peer-reflexive address from
## the first connectivity check that reaches it, so a guest that hid its own
## addresses still walked straight up to a host that had sent its own, and the
## link reported RELAY for a direct line. With both ends hidden behind their
## relays the only pair that can carry a packet is relay to relay. The second
## hop costs little: both allocations live on the same server.
##
## Every signal carries its stage as `gen`, so a late candidate from the
## abandoned first attempt can never land on the second one.
##
## The guest drives: it makes the offers and decides when stage 1 has run out.
## The host only answers, and moves to stage 2 the moment a gen-2 message
## arrives. Both ends therefore agree on the route without telling each other.

signal outgoing(data: Dictionary)
signal connected(route: String)
signal failed(reason: String)

const DIRECT_SECONDS := 6.0
const RELAY_SECONDS := 10.0

var peer_id: int
var route := ""

var _mp: WebRTCMultiplayerPeer
var _ice: Dictionary
var _offerer: bool
var _force_relay: bool
var _stage := 0
var _conn: WebRTCPeerConnection
var _started_ms := 0
var _given_up := false


## `peer_id` is the OTHER end's id; `ice` is the {stun, turn} pair the
## signaling service handed out; the guest is the `offerer`.
func _init(mp: WebRTCMultiplayerPeer, other_id: int, ice: Dictionary, offerer: bool,
		force_relay := false) -> void:
	_mp = mp
	peer_id = other_id
	_ice = ice
	_offerer = offerer
	_force_relay = force_relay


func start() -> void:
	_begin(2 if _force_relay else 1)


func stage() -> int:
	return _stage


## A message the other end sent us through signaling.
func receive(data: Dictionary) -> void:
	var gen := int(data.get("gen", 0))
	if gen < _stage or _given_up:
		return
	if gen > _stage:
		if _offerer:
			return  # only the guest moves stages; a host never runs ahead of it
		_begin(gen)
	match String(data.get("kind", "")):
		"offer", "answer":
			_conn.set_remote_description(data["kind"], String(data.get("sdp", "")))
		"cand":
			if _stage == 2 and not _is_relay(String(data.get("cand", ""))):
				return
			_conn.add_ice_candidate(String(data.get("mid", "")), int(data.get("idx", 0)),
				String(data.get("cand", "")))


## Called once a frame. The connection itself is polled by the multiplayer peer
## it was added to; this only watches the clock and the state.
func poll() -> void:
	if _conn == null or _given_up or route != "":
		return
	var state := _conn.get_connection_state()
	if state == WebRTCPeerConnection.STATE_CONNECTED:
		route = "DIRECT" if _stage == 1 else "RELAY"
		connected.emit(route)
		return
	var waited := (Time.get_ticks_msec() - _started_ms) / 1000.0
	var dead := state == WebRTCPeerConnection.STATE_FAILED
	if _stage == 1 and _offerer and (dead or waited > DIRECT_SECONDS):
		_begin(2)
	elif _stage == 2 and (dead or waited > RELAY_SECONDS):
		_given_up = true
		failed.emit("no route, even through the relay")


func close() -> void:
	_given_up = true
	if _conn != null:
		_conn.close()
	if _mp.has_peer(peer_id):
		_mp.remove_peer(peer_id)


func _begin(stage_number: int) -> void:
	if _conn != null:
		_conn.close()
	if _mp.has_peer(peer_id):
		_mp.remove_peer(peer_id)
	_stage = stage_number
	_started_ms = Time.get_ticks_msec()
	var servers: Array = []
	servers.append_array(_ice.get("stun", []))
	if _stage == 2:
		servers.append_array(_ice.get("turn", []))
	_conn = WebRTCPeerConnection.new()
	_conn.initialize({"iceServers": servers})
	_conn.session_description_created.connect(_on_description.bind(_stage))
	_conn.ice_candidate_created.connect(_on_candidate.bind(_stage))
	_mp.add_peer(_conn, peer_id)
	if _offerer:
		_conn.create_offer()


func _on_description(type: String, sdp: String, gen: int) -> void:
	if gen != _stage:
		return
	_conn.set_local_description(type, sdp)
	outgoing.emit({"gen": gen, "kind": type, "sdp": sdp})


func _on_candidate(mid: String, idx: int, candidate: String, gen: int) -> void:
	if gen != _stage:
		return
	if _stage == 2 and not _is_relay(candidate):
		return
	outgoing.emit({"gen": gen, "kind": "cand", "mid": mid, "idx": idx, "cand": candidate})


static func _is_relay(candidate: String) -> bool:
	return candidate.contains(" typ relay")
