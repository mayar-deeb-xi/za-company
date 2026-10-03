extends RefCounted
## The list of open games (server/signaling's `list`, rooms.py's header),
## asked for again every few seconds for as long as somebody is looking at it
## and handed over WHOLE each time: the newest answer is the truth, so there
## is nothing to merge and a row that went is simply not in the next one.
##
## It has a socket of its own rather than Net's, because looking is not being
## in a room: Net opens one to host or to join, and closing that one is how a
## party ends. Polled like every other peer object here - Net calls poll().

signal listed(rooms: Array)
## The service is not there; it is tried again on the same clock.
signal unreachable

const SignalClient := preload("res://autoload/net/signal_client.gd")

## How often the list is asked for. A room that filled or started stays on a
## screen at most this long, and joining it is refused in words.
const EVERY := 3.0

var _url: String
var _protocol: int
var _wire: int
var _signal: SignalClient = null
var _clock := 0.0


func _init(url: String, protocol: int, wire: int) -> void:
	_url = url
	_protocol = protocol
	_wire = wire


func open() -> void:
	_clock = 0.0
	_ask()


func poll(delta: float) -> void:
	if _signal != null:
		_signal.poll()
	_clock += delta
	if _clock >= EVERY:
		_clock = 0.0
		_ask()


func close() -> void:
	if _signal != null:
		_signal.close()
		_signal = null


## Over the open socket, or a new one if the last went: the request queues
## until it is up, and a socket that never comes up says so through `closed`.
func _ask() -> void:
	if _signal == null:
		_signal = SignalClient.new()
		_signal.message.connect(_on_message)
		_signal.closed.connect(_on_closed)
		if _signal.open(_url) != OK:
			_signal = null
			unreachable.emit()
			return
	_signal.send({"op": "list", "v": _protocol, "wire": _wire})


func _on_message(msg: Dictionary) -> void:
	match String(msg.get("op", "")):
		"rooms":
			if msg.get("rooms") is Array:
				listed.emit(msg["rooms"])
		"error":
			# A service from before the list refuses the ask with `version`:
			# as far as a player can tell, there is no list there to reach.
			unreachable.emit()


func _on_closed(_code: int, _reason: String) -> void:
	_signal = null
	unreachable.emit()
