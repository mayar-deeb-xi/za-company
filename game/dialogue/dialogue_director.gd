extends Node
## Runs one conversation: reads a list of beats, drives the subtitle box, walks
## the NPC, leads the player after them, and raises whatever overlay a beat asks
## for. Instanced once by game.tscn, exactly like the HUD and the pause menu,
## and handed work by game.gd when an NPC asks to talk.
##
## ## A conversation is data
##
## `game/npcs/<id>/<name>.gd` holds `const BEATS`, an Array of Dictionaries, and
## this script is the only thing that reads it - the same split every other
## authored thing in this project uses (a floor's furniture, the cast's looks,
## the bestiary). Writing a conversation is editing one file with no code in it.
##
## A beat's keys, all optional, applied in this order:
##
## - `id`        a label, so a `goto` can come back here
## - `name`      who is speaking. STICKY: it carries to the beats that follow
##               until another one changes it, so a run of lines from one mouth
##               names them once
## - `text`      the subtitle. A beat with text waits for the player
## - `voice`     the clip that will play with it (see dialogue_box.gd) - carried
##               and ignored until there is audio
## - `options`   [{"text": ..., "goto": ...}, ...]; needs `text` to ask with
## - `walk`      a Vector2 the NPC walks to before speaking
## - `escort`    while walking, lead the player along behind them
## - `face`      "player" (the default after a walk) or "keep"
## - `show`      a scene path to raise over the room; `hide` takes it back down
## - `wait`      seconds to hold, for a beat with nothing to say
## - `goto`      jump to that `id` instead of falling through to the next beat
##
## ## It is a coroutine, not a state machine
##
## `talk()` awaits its way down the list. That is what keeps "walk there, then
## say this, then ask" readable as three lines of data rather than a table of
## states, and it is why a beat can await two different things (an arrival, a
## keypress) without either knowing the other exists.
##
## ## What it does NOT do
##
## It does not pause the tree. It cannot: the NPC has to walk while it talks,
## and pausing would freeze her too. So the world keeps running through a
## conversation, and the guard against being hit mid-sentence is WHERE an NPC
## is placed, not a flag here. Talk to people in safe rooms.
##
## It also keeps no memory. Rooms are re-instantiated on every entry (see the
## root CLAUDE.md), so a conversation that has been had is a conversation that
## can be had again; persistent story state is a later thing, and when it
## arrives it belongs in a save, not here.

## Emitted so game.gd (or a test) can tell a conversation is under way without
## reaching into this script.
signal started(npc: Node2D)
signal finished(npc: Node2D)

## How far behind the guide the player is led. A little more than the two
## bodies' radii, so following reads as following rather than as pushing - and
## deliberately INSIDE the NPC's talk radius, so a tour that ends where it began
## leaves the player still close enough to start another one.
const TRAIL := 24.0
## Seconds after a conversation ends before another can start. The press that
## closed the last line is the same press an NPC standing right there would
## read as "talk to me", and without this the box would reopen on the frame it
## closed.
const COOLDOWN := 0.3
## How long a single `walk` beat may take before the conversation gives up on
## it and says its line from wherever the guide got to. NPCs have no
## pathfinding - they slide off whatever they touch, like the enemies do - so a
## route that clips a plant pot after a prop is nudged would otherwise hang the
## conversation forever, with the player still under its control. Generous
## enough that no honest walk in the game comes near it: the longest leg of
## HR's tour is about five seconds.
const WALK_TIMEOUT := 12.0

const BoxType := preload("res://ui/dialogue/dialogue_box.gd")

@onready var _box: BoxType = $Layer/DialogueBox
## Where a beat's `show` scene is parented. Under the box's layer but BEHIND it
## in tree order, so an overlay never covers the line that is explaining it.
@onready var _overlay: Control = $Layer/Overlay

var _npc: Node2D = null
var _player: Node2D = null
var _beats: Array = []
## Index of the beat to run next. A `goto` writes it; everything else steps it.
var _at := 0
## The current speaker, carried between beats - see the `name` key above.
var _speaker := ""
var _running := false
var _cooldown := 0.0
## The scene a `show` beat raised, or null. One at a time by construction.
var _shown: Node = null


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)


func talking() -> bool:
	return _running


## Start `npc`'s conversation, with `player` as the one being talked at.
## Silently declines when one is already running or has only just ended, which
## is the whole of the re-entry guard: the box consumes its own keypresses, and
## this covers the frame on either side of that.
func talk(npc: Node2D, player: Node2D) -> void:
	if _running or _cooldown > 0.0:
		return
	var beats := _load_beats(npc)
	if beats.is_empty():
		return

	_npc = npc
	_player = player
	_beats = beats
	_at = 0
	_speaker = String(npc.call("speaker_name")) if npc.has_method("speaker_name") else ""
	_running = true
	if npc.has_method("set_talking"):
		npc.call("set_talking", true)
	player.call("take_control")
	player.call("face_towards", npc.global_position)
	if npc.has_method("face_towards"):
		npc.call("face_towards", player.global_position)
	started.emit(npc)

	# Bounded by the list rather than by a terminator beat: falling off the end
	# IS the end, so no conversation can be left unfinished by forgetting one.
	while _running and _at >= 0 and _at < _beats.size():
		var beat: Dictionary = _beats[_at]
		_at += 1
		await _play(beat)

	_end()


## One beat, start to finish. Everything in here is ordered the way the class
## docs list the keys: get there, say it, then jump.
func _play(beat: Dictionary) -> void:
	if beat.has("show"):
		_raise(String(beat["show"]))
	if beat.get("hide", false):
		_drop()

	if beat.has("walk"):
		await _walk(beat["walk"], beat.get("escort", false))
		if String(beat.get("face", "player")) == "player":
			_look_at_each_other()

	if beat.has("text"):
		_speaker = String(beat.get("name", _speaker))
		_box.say(_speaker, String(beat["text"]), String(beat.get("voice", "")))
		if beat.has("options"):
			var options: Array = beat["options"]
			_box.offer(options.map(func(o): return String(o["text"])))
			var picked: int = await _box.chose
			# The choice replaces the beat's own `goto`: an answer that led
			# nowhere would silently fall through to the next line in the file,
			# which is never what a question meant.
			_at = _index_of(String(options[picked].get("goto", "")))
			return
		await _box.advanced
	elif beat.has("wait"):
		await get_tree().create_timer(float(beat["wait"])).timeout

	if beat.has("goto"):
		_at = _index_of(String(beat["goto"]))


## Walk the NPC to a point, optionally towing the player. The lead point is
## recomputed every frame from where the player already IS, so they trail from
## whichever side they happen to be on instead of snapping to a fixed shoulder.
func _walk(to: Vector2, escort: bool) -> void:
	if not _npc.has_method("walk_to"):
		return
	_box.close()
	_npc.call("walk_to", to)
	var spent := 0.0
	while _running and _npc.call("walking"):
		if escort:
			_player.call("lead_to", _trail())
		await get_tree().physics_frame
		spent += get_physics_process_delta_time()
		if spent >= WALK_TIMEOUT:
			push_warning("dialogue: %s could not reach %s" % [_npc.name, to])
			_npc.call("stop")
			break
	if escort:
		_player.call("lead_to", null)


func _trail() -> Vector2:
	var away: Vector2 = _player.global_position - _npc.global_position
	if away.length() < 0.5:
		away = Vector2.DOWN
	return _npc.global_position + away.normalized() * TRAIL


func _look_at_each_other() -> void:
	if _npc.has_method("face_towards"):
		_npc.call("face_towards", _player.global_position)
	_player.call("face_towards", _npc.global_position)


## A beat's overlay. Raised by path so the director never learns what any
## particular one is - the contract is a scene like any other, and the next
## conversation that wants a screen adds no code here.
func _raise(scene_path: String) -> void:
	_drop()
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_warning("dialogue: no scene at %s" % scene_path)
		return
	_shown = packed.instantiate()
	_overlay.add_child(_shown)


func _drop() -> void:
	if _shown == null:
		return
	_shown.queue_free()
	_shown = null


## Where the beat labelled `id` sits. An unknown or empty label ends the
## conversation rather than falling through to whatever happens to be next: a
## typo in a `goto` should be obvious, not a line delivered out of order.
func _index_of(id: String) -> int:
	if id == "":
		return _beats.size()
	for i in _beats.size():
		if String((_beats[i] as Dictionary).get("id", "")) == id:
			return i
	push_warning("dialogue: no beat labelled '%s'" % id)
	return _beats.size()


## `const BEATS` out of the .gd the NPC names. Read off the Script itself rather
## than an instance of it, so a conversation file is pure data with nothing to
## construct.
func _load_beats(npc: Node2D) -> Array:
	if not npc.has_method("conversation_path"):
		return []
	var path := String(npc.call("conversation_path"))
	if path == "":
		return []
	var script := load(path) as GDScript
	if script == null:
		push_warning("dialogue: no conversation at %s" % path)
		return []
	return script.get_script_constant_map().get("BEATS", [])


## Hands the body back and takes everything down. Called on the way out of
## `talk()`, and by `stop()` when something else needs the conversation over -
## a door, a death - so there is one path that releases the player.
func _end() -> void:
	var who: Node2D = _npc
	_box.close()
	_drop()
	if _npc != null and _npc.has_method("set_talking"):
		_npc.call("set_talking", false)
	if _player != null:
		_player.call("release_control")
	_npc = null
	_player = null
	_beats = []
	_running = false
	_cooldown = COOLDOWN
	if who != null:
		finished.emit(who)


## Cut a conversation short. The `while` in talk() checks `_running`, so the
## loop unwinds on its own at the next beat boundary; _end() here is what makes
## the player playable again in the same frame.
func stop() -> void:
	if not _running:
		return
	_running = false
	# Unblock whatever the run is awaiting, so the coroutine unwinds through its
	# own loop - which sees `_running` is false and stops - instead of sitting
	# on a signal that is never coming again.
	_box.advanced.emit()
	_box.chose.emit(0)
	_end()
