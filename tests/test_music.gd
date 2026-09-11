extends "res://tests/helpers.gd"
## The last two floors share a track, and the door between them does not
## restart it. Plus the rule that pair is only an instance of, which floor 1
## joined the day the lobby got a bed of its own: a floor may name a track, and
## the ones that do are named here and nowhere else.
##
## Its own suite because it is the first thing in this project that is checked
## ACROSS a door rather than inside a room: the whole claim is that one file
## plays continuously from the executive floor into the penthouse, and there is
## no single frame anywhere at which that is visible. test_flow.gd walks the
## same doors, but it walks all twelve and asserts each room's composition as it
## passes - a music check threaded into it would have to survive every future
## renumbering of a chain it does not care about.
##
## ## What makes this worth a suite at all
##
## Every track in this game shipped MUTE once, and nothing noticed, because the
## only thing anyone checked was that `loop_mode` had been set - it had, with
## `loop_end` left at 0, which wraps before a single sample has played. So the
## check with teeth here is not "a path is set" but that the stream behind the
## path resolved, and that its loop is sealed to the stream's real length.
##
## ## Why this is not a check about a boss
##
## Silverman is standing on the second of the two floors and deliberately names
## no theme of his own. A boss's theme is HIS: it starts on the frame his bar
## goes up and leaves on the frame he concedes, so it could never cover the
## floor below him, and putting one on him here would interrupt the track twice
## in the last four minutes of the game. That absence is load-bearing and is
## checked, because nothing else in the project would notice a `music` line
## being added to his scene.

const CHAIN := ["lobby", "content_studio", "call_center", "ahmed_office",
	"the_hub", "marble_hall", "innovation_lab", "conflict_resolution",
	"asset_recovery", "hellfire", "executive_floor", "khaled_office"]

const EXEC := "res://game/levels/executive_floor/executive_floor.tscn"
const PENTHOUSE := "res://game/levels/khaled_office/khaled_office.tscn"
const FINALE := "res://assets/music/finale_loop.wav"
const LOBBY := "res://assets/music/lobby_loop.wav"

## The floors that carry a track of their own, and what each one carries. The
## rest of the building runs on Music.DEFAULT. Written as a map rather than a
## list because there are now two answers to "which track": floor 1 has a bed
## of its own, and the last two share the finale. A third floor quietly taking
## either of them - or the lobby's leaking upstairs - fails below.
const SCORED := {
	"lobby": LOBBY,
	"executive_floor": FINALE,
	"khaled_office": FINALE,
}

## A door transition is two fades plus travel (~40 frames), and a handoff
## between two tracks costs Music.FADE_SECONDS (1.2 s = 72) more on top,
## because there is one player and the old track has to finish leaving. Every
## wait here is that sum with room to spare rather than a tuned number.
## Where the playhead is parked before the last door, in seconds. Any number
## the track is long enough to hold and no fresh play() could reach in the
## frames this suite spends crossing a door.
const SEEK_TO := 30.0

## What the floor below the finale was playing, so the change at its door can
## be shown to be a change. Not named `_bed`: the floor below is the LOBBY in
## this suite's walk, and the lobby has not played the bed since floor 1 got a
## track of its own.
var _below := ""
var _pos_before := -1.0
var _pos_after := -1.0


func _tick(frame: int) -> void:
	match frame:
		2:
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		17:
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()

		# --- an ordinary floor, which is ten of the twelve -------------------
		140:
			_below = _music_track()
			_check("lobby: floor 1 plays the track its biome names (%s)"
				% _below.get_file(), _below == LOBBY)
			_check("lobby: which is not the bed the other nine floors run on",
				_below != _default_track())
			_travel(EXEC)

		# --- the executive floor, where the finale starts --------------------
		300:
			_check("exec: the floor named its own track and got it (%s)"
				% _music_track().get_file(), _music_track() == FINALE)
			_check("exec: which is not what the floor below was playing",
				_music_track() != _below)
			_seal()
			# SEEKED rather than merely read, and that is what makes the check
			# below mean anything. Under the dummy driver a headless run mixes
			# in fits - the position crawled 0.09 s across 160 frames while it
			# was measured - so "the position advanced" is a coin flip and
			# would pass a restart on a quiet frame. A seek is not mixing: it
			# puts the playhead somewhere no fresh `play()` could ever leave
			# it, and crossing the door either keeps it there or does not.
			_music().seek(SEEK_TO)
			_pos_before = _music().get_playback_position()
			_travel(PENTHOUSE)

		# --- the penthouse, through the door, same file -----------------------
		460:
			_check("penthouse: the same track is still playing (%s)"
				% _music_track().get_file(), _music_track() == FINALE)
			_pos_after = _music().get_playback_position()
			# The no-restart evidence: the playhead is still where it was put
			# a floor below. A handoff - to the bed, to a boss's theme, or to
			# this same file asked for a second time without the idempotence
			# guard - starts the stream over and lands near 0.
			_check("penthouse: the door did not restart it (%.2f s -> %.2f s)"
				% [_pos_before, _pos_after], _pos_after >= SEEK_TO)
			_boss()
			_scored()
			_finish()


## The door's own signal, which is all a level ever tells the host. Any door
## does: what is under test is what the ARRIVING floor asks for, not which
## doorway was walked through.
func _travel(path: String) -> void:
	_level().get_node("Props/Exit").travelled.emit(path, &"start")


## The stream behind the path, and the loop sealed to its real length. `loop_end`
## is in FRAMES and 0 does NOT mean "to the end" - a forward loop ending on
## frame 0 wraps before it has played anything and the bus receives silence.
func _seal() -> void:
	var stream := _music().stream as AudioStreamWAV
	_check("exec: the path resolved to a stream that really loaded",
		stream != null)
	if stream == null:
		return
	var want := int(stream.get_length() * stream.mix_rate)
	_check("exec: it loops forward",
		stream.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	_check("exec: and the loop is sealed to its real length (%d of %d frames)"
		% [stream.loop_end, want], stream.loop_end == want)


## The boss standing on the second of the two floors, and the theme he does not
## have. Read off the live node rather than off his scene file, because what
## matters is what game.gd's _watch_boss finds when it looks.
func _boss() -> void:
	var boss: Node = null
	for node in get_nodes_in_group("bosses"):
		boss = node
	_check("penthouse: the boss is in the room", boss != null)
	if boss == null:
		return
	_check("penthouse: and names no theme, so the fight interrupts nothing (%s)"
		% String(boss.get("music")), String(boss.get("music")) == "")


## THE RULE THE TWO FLOORS ARE ONLY AN INSTANCE OF: a floor's own track sits on
## the last two floors of the chain and on no other, and it is the SAME file on
## both - which is the entire reason the music crosses the door. Read off disk
## for the same reason test_dominique.gd reads the chain: a thirteenth floor, or
## a `music` line pasted onto a room in the middle of the building, fails here
## rather than shipping.
func _scored() -> void:
	var carried := {}
	for name in CHAIN:
		var room := (load("res://game/levels/%s/%s.tscn" % [name, name])
			as PackedScene).instantiate()
		carried[name] = String(room.get("music"))
		room.free()
	var wrong: Array[String] = []
	for name in CHAIN:
		var want: String = SCORED.get(name, "")
		if carried[name] != want:
			wrong.append("%s %s" % [name,
				"silent" if carried[name] == "" else carried[name].get_file()])
	_check("chain: three floors name a track and the other nine do not (%s)"
		% ("the whole chain" if wrong.is_empty() else ", ".join(wrong)),
		wrong.is_empty())
	# The finale's two are the LAST two, and the lobby's one is the FIRST. Both
	# halves matter: a track that is meant to carry the end of the game into
	# the end of the game has to sit at the end of the chain, and floor 1's is
	# the tutorial's and belongs nowhere else.
	var scored: Array = SCORED.keys().filter(func(n: String) -> bool:
		return SCORED[n] == FINALE)
	_check("chain: and the finale's two are the last two, not merely two (%s)"
		% ", ".join(scored), scored == CHAIN.slice(CHAIN.size() - 2))
	_check("chain: while the lobby's own is floor 1 and nowhere else",
		SCORED.get(CHAIN[0], "") == LOBBY)


## Music.DEFAULT, read off the autoload rather than spelled out here: the bed's
## path moving must not fail a suite about a different track.
func _default_track() -> String:
	var m := _autoload("Music")
	return String(m.get_script().get_script_constant_map()["DEFAULT"])
