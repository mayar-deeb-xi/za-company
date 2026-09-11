extends Node
## The music, and the reason it is an autoload rather than a node in a scene:
## the front end is THREE scenes (main menu -> character select -> and back out
## of the game), and `change_scene_to_file` frees the old one. A player living
## in main_menu.tscn would restart the track the moment PLAY is pressed, which
## is the one seam a menu loop exists to hide. Living above the scene tree, it
## simply keeps playing.
##
## `play()` is idempotent on the track, and that is the whole trick: every
## front-end screen asks for the same track in its `_ready` without knowing
## which screen ran before it, and only the first ask actually starts anything.
## No screen has to know whether music is already playing, and entering the
## character select directly - which the tests do - still gets music.
##
## Deliberately NOT positional: a room's sounds pan with the room (see
## game/bosses/boss_audio.gd), but music is not standing anywhere.

## The tracks. A boss's sounds live in his own scene because they are HIS
## (game/bosses/boss_audio.gd); a music track is the opposite - one file that
## three screens ask for by name, and a path spelled out in three places is the
## one that goes stale when a file moves. So the catalogue lives here.
const MENU := "res://assets/music/menu_loop.wav"

## Trim over the level baked into the file. The menu export peaks at -0.5 dBFS,
## which is mastered for headphones and far too hot to sit under a game that
## will grow sound effects; this puts it where a menu bed belongs.
const VOLUME_DB := -8.0

## Long enough to read as the music ending rather than being cut off, short
## enough that it is gone before the first room has faded in (game.gd's
## FADE_SECONDS is 0.28, and the title card follows it).
const FADE_SECONDS := 1.2

var _player: AudioStreamPlayer
## Path of whatever is playing now, so a repeated `play()` can no-op. Cleared on
## stop, never on fade - a fade that is still running is still that track, and
## re-asking for it during one should catch it and bring it back up.
##
## This, and NOT `_player.playing`, is what the no-op is decided on. Under a
## dummy audio driver - which is every headless run, tests included - `playing`
## is false even while a stream is assigned and looping, so a guard that
## trusted it would restart the track on every scene change in exactly the
## situation nobody can hear. Everything here loops and `stop()` clears this,
## so "a track is set" and "a track is playing" are the same statement.
var _track := ""
var _fade: Tween


func _ready() -> void:
	# The pause menu pauses the tree with the game sitting behind it, and a
	# paused AudioStreamPlayer stops its stream. Music is the last thing that
	# should notice a pause.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_player = AudioStreamPlayer.new()
	_player.name = "Player"
	_player.volume_db = VOLUME_DB
	add_child(_player)


## Start `path`, or do nothing if it is already the track playing. A track
## caught mid-fade is brought back to full rather than restarted, so bouncing
## out of the game and back into the menu picks the loop up where it was.
func play(path: String) -> void:
	if _track == path:
		_cancel_fade()
		_player.volume_db = VOLUME_DB
		return

	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("Music: no stream at %s" % path)
		return

	_cancel_fade()
	_seal(stream)
	_track = path
	_player.stream = stream
	_player.volume_db = VOLUME_DB
	_player.play()


## Take the music down over `seconds` and stop it. What leaving the menu for a
## room does: the track goes out rather than being cut.
##
## A fade already running is left alone rather than restarted, and that is the
## guard doing real work rather than tidiness: the exits stack. Leaving the
## menu fades, and the first room being built asks for silence again one frame
## later; conceding a boss fades, and the door out of his floor asks again
## while it is still going. Re-tweening from the level it had reached would
## reset the clock each time, so a track could be asked to leave three times
## and take longer for it.
func fade_out(seconds := FADE_SECONDS) -> void:
	if _track == "":
		return
	if _fade != null and _fade.is_valid():
		return
	_fade = create_tween()
	_fade.tween_property(_player, "volume_db", -60.0, seconds)
	_fade.tween_callback(stop)


## What is playing, or "" for silence. The readout callers and tests get,
## rather than `playing` on a node behind a driver that may not exist.
func track() -> String:
	return _track


func stop() -> void:
	_cancel_fade()
	_player.stop()
	_player.volume_db = VOLUME_DB
	_track = ""


## Loop flag set here rather than trusted to the .import, for the same reason
## boss_audio.gd sets it: import settings are written by whoever first scanned
## the file, and a menu track that plays once and leaves silence behind is a
## failure nobody notices until they sit on the menu for half a minute.
##
## `loop_end` is in FRAMES and must be the real count. It does NOT mean "to the
## end" when left at 0 - that was the guess this code shipped with, and a
## forward loop ending on frame 0 wraps before it has played anything: the
## playback position stays pinned at 0.000s and the bus receives exact silence.
## Every sealed stream in the game was mute, and nothing noticed, because the
## only thing anyone checked was that `loop_mode` had been set. It had.
##
## The count comes from `get_length() * mix_rate` rather than from `data.size()`
## because these import as QOA (format 3) - `data` is compressed bytes, not
## frames, so sizing a loop off it would be wrong by the compression ratio.
func _seal(stream: AudioStream) -> void:
	var wav := stream as AudioStreamWAV
	if wav != null:
		if wav.loop_mode != AudioStreamWAV.LOOP_FORWARD or wav.loop_end <= 0:
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		return
	var ogg := stream as AudioStreamOggVorbis
	if ogg != null:
		ogg.loop = true


func _cancel_fade() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = null
