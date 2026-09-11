extends Node2D
## The noise one boss makes. Shared like `boss_base.gd` is shared - the
## MECHANISM is here, the sounds are per boss, exactly the way the fire
## shapes are shared and the ramp is not.
##
## A boss's scene fills `sounds` with id -> stream and nothing else happens:
## `boss_base` already calls `hurt`, `stagger` and `concede` on whichever of
## them exist, so a boss gets those three by owning the files, and a boss who
## owns none of them stays silent without a single branch anywhere. Ids this
## node does not have are not an error - they are a boss who has not been
## given that sound yet, which is most of them most of the time, and which is
## also what a fresh checkout looks like before the WAVs are imported.
##
## One player per id, built once: an id retriggered mid-play restarts rather
## than stacking, which is what a grunt on a four-hit combo wants.
##
## Positional (AudioStreamPlayer2D) so a boss crossing the room pans, with the
## attenuation flattened right down - a boss arena is one screen wide and a
## fight that gets quieter at the edge of it is a bug, not atmosphere.

## id -> AudioStream. Filled per boss in his own scene.
@export var sounds: Dictionary = {}
## Trim for the whole boss, over the levels baked into the files themselves.
@export var volume_db := 0.0
## Flat across a room, then gone. The room is 640 px of viewport at 1x.
@export var max_distance := 600.0
@export var attenuation := 0.2

var _players := {}
var _fades := {}


func _ready() -> void:
	for id in sounds:
		var stream: AudioStream = sounds[id]
		if stream == null:
			continue
		var player := AudioStreamPlayer2D.new()
		player.name = "Sfx_%s" % id
		player.stream = stream
		player.volume_db = volume_db
		player.max_distance = max_distance
		player.attenuation = attenuation
		add_child(player)
		_players[id] = player


## Fire once. An unknown id is silence, deliberately - see the header.
func play(id: String) -> void:
	var player: AudioStreamPlayer2D = _players.get(id)
	if player == null:
		return
	_cancel_fade(id)
	player.volume_db = volume_db
	player.play()


## Fire and keep firing. The loop flag is set on the stream HERE rather than
## trusted to the .import, because the import settings are written by whoever
## first scanned the file and a silent failure to loop is hard to see in a
## fight - `loop_end` 0 means "to the end", which is what a sealed loop wants.
func loop(id: String) -> void:
	var player: AudioStreamPlayer2D = _players.get(id)
	if player == null or player.playing:
		return
	# `loop_end` is in FRAMES and must be the real count - 0 does not mean "to
	# the end". A forward loop ending on frame 0 wraps before it has played
	# anything, so the axe burned in total silence with its loop flag set and
	# every test passing. See autoload/music.gd's `_seal` for the long version;
	# the two are deliberately separate subsystems, so the fix lives twice.
	var wav := player.stream as AudioStreamWAV
	if wav != null and (wav.loop_mode != AudioStreamWAV.LOOP_FORWARD
			or wav.loop_end <= 0):
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_cancel_fade(id)
	player.volume_db = volume_db
	player.play()


func stop(id: String) -> void:
	var player: AudioStreamPlayer2D = _players.get(id)
	if player == null:
		return
	_cancel_fade(id)
	player.stop()


## Take a loop down over `seconds` and stop it. What the axe's fire does when
## it leaves his hand: it goes out over the concede rather than being cut.
func fade_out(id: String, seconds: float) -> void:
	var player: AudioStreamPlayer2D = _players.get(id)
	if player == null or not player.playing:
		return
	_cancel_fade(id)
	var tween := create_tween()
	_fades[id] = tween
	tween.tween_property(player, "volume_db", -60.0, seconds)
	tween.tween_callback(player.stop)


func _cancel_fade(id: String) -> void:
	var tween: Tween = _fades.get(id)
	if tween != null and tween.is_valid():
		tween.kill()
	_fades.erase(id)
