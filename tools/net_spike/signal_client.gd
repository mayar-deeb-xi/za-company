extends RefCounted
## The game's end of the signaling socket (server/signaling/main.py): JSON
## messages with an `op`, in and out, over one WebSocket. It knows the wire and
## nothing about rooms - what an `op` MEANS is the caller's business.
##
## Polled rather than run on its own, like every peer object in Godot: whoever
## owns it calls poll() once a frame. Anything sent before the socket opens is
## queued and goes out the frame it does, so a caller can open and send in one
## breath without waiting on a signal.

signal message(msg: Dictionary)
signal closed(code: int, reason: String)

var _ws := WebSocketPeer.new()
var _was_open := false
var _closing := false
var _queue: Array[String] = []


func open(url: String) -> Error:
	_ws.outbound_buffer_size = 1 << 16
	return _ws.connect_to_url(url)


func send(msg: Dictionary) -> void:
	var text := JSON.stringify(msg)
	if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(text)
	else:
		_queue.append(text)


func close() -> void:
	_closing = true
	_ws.close(1000, "bye")


func poll() -> void:
	_ws.poll()
	var state := _ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _was_open:
			_was_open = true
			for text in _queue:
				_ws.send_text(text)
			_queue.clear()
		while _ws.get_available_packet_count() > 0:
			var parsed: Variant = JSON.parse_string(_ws.get_packet().get_string_from_utf8())
			if parsed is Dictionary:
				message.emit(parsed)
	elif state == WebSocketPeer.STATE_CLOSED and (_was_open or not _queue.is_empty()):
		# Either a socket that was up has gone, or one never came up with
		# something waiting to be said: both are "the server is not there".
		_was_open = false
		_queue.clear()
		closed.emit(_ws.get_close_code(), _ws.get_close_reason())
