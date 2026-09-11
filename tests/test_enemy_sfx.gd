extends "res://tests/helpers.gd"
## What the bestiary sounds like: that all six own the cues their archetype can
## actually reach, that every declared stream resolves to a real file, that the
## wraith's drain is a sealed LOOP rather than a one-shot with a flag on it,
## and that a death sound outlives the body that made it.
##
## Its own suite because the last of those is a destructive check on a clean
## room - it kills an enemy and then counts what the LEVEL is holding - and a
## file that does that cannot also hand the room to a next section unchanged.
## test_combat.gd keeps the fight; this keeps the noise.
##
## ## What is deliberately not checked, and why
##
## That a one-shot is audible. Headless runs the Dummy audio driver, under
## which `AudioStreamPlayer.playing` is false forever even with a good stream
## assigned, and `get_playback_position()` advances on the wall clock while
## `--fixed-fps` never sleeps - test_menu.gd wrote that check, watched it flake
## on the second run and took it back out. So the evidence here is the same
## evidence test_bosses.gd settled on: STRUCTURE (the ids a scene declares, the
## players built from them, the streams resolving) plus the two things a call
## leaves a visible mark on - the loop flag `enemy_audio.loop()` sets, and the
## detached player `play_detached()` parents to the level.
##
## Those two are not consolation prizes. They are the only parts of this that
## could fail silently in a way a person would not notice for months: a loop
## sealed to frame 0 plays exact silence with its flag set (see the root
## CLAUDE.md's Testing), and a death sound played the ordinary way is freed in
## the same frame it starts.

## Which cues each type can reach, derived from the fight rather than listed
## twice: the drainers opt out of the attack cycle (`_attacks()` false), so
## they have no wind-up to telegraph, no blow to land and nothing to stagger.
const MELEE := ["windup", "hit", "hurt", "stagger", "die"]
const DRAINER := ["drain", "hurt", "die"]
const CAST := {
	"regular": MELEE,
	"office_boy": MELEE,
	"warden": MELEE,
	"call_center": MELEE,
	"wraith": DRAINER,
	"social_media": DRAINER,
}

## Enemy scenes carry `<id>` as both folder and file name.
const SCENE := "res://game/enemies/%s/%s.tscn"

## The two who talk to themselves, and the one cue they have. Nobody else in
## the bestiary has a `Lines` child; a boss has one with nine cues and none of
## them is this.
const MUTTERERS := ["social_media", "call_center"]
const MUTTER := "mutter"

var _wraith: Node2D
var _victim: Node2D
var _mutterer: Node2D
var _players_before := 0


func _tick(frame: int) -> void:
	match frame:
		2:
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		17:
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()

		# ---- The contract, read off the six scenes on disk. Every one of them
		# is instanced for real rather than parsed, because what is under test
		# is what `enemy_audio._ready()` makes of the dictionary, not what the
		# dictionary says.
		32:
			_check("sfx: the lobby starts empty, so every body here is placed (%d)"
				% get_nodes_in_group("enemies").size(),
				get_nodes_in_group("enemies").is_empty())
			for id in CAST:
				_audit(id, CAST[id])

		# ---- The drain. The wraith is the one enemy whose sound is a STATE,
		# and the loop flag is the one thing a headless run can see a `loop()`
		# call by. It must not be set before the player is in the aura: the
		# drain starting on spawn would be the whole floor humming.
		46:
			_wraith = _spawn("wraith", Vector2(272, 200))
			_player().global_position = Vector2(272, 120)
		60:
			_check("sfx: the drain is silent until it feeds (loop %d)"
				% _loop_mode_of(_wraith, "drain"),
				_loop_mode_of(_wraith, "drain") != AudioStreamWAV.LOOP_FORWARD)
			# Into the aura, which is a 16 px Touch radius - stand on it.
			_player().global_position = _wraith.global_position + Vector2(0, -8)
		64:
			_check("sfx: contact starts the drain looping (loop %d)"
				% _loop_mode_of(_wraith, "drain"),
				_loop_mode_of(_wraith, "drain") == AudioStreamWAV.LOOP_FORWARD)
			# The trap the whole project has been bitten by once already: a
			# forward loop ending on frame 0 wraps before it has played
			# anything, so the bus receives exact silence while every flag a
			# check could look at reads correct. `loop_end` must be the real
			# frame count.
			var wav := _stream_of(_wraith, "drain")
			var frames := 0 if wav == null else int(wav.get_length() * wav.mix_rate)
			_check("sfx: and sealed to a real end, not frame 0 (%d of %d)"
				% [0 if wav == null else wav.loop_end, frames],
				wav != null and wav.loop_end > 0 and absi(wav.loop_end - frames) <= 1)
			# The seam itself, which is the OTHER way a loop ships broken: an
			# export ends mid-waveform and clicks once per pass. tools/sfx
			# crossfades the tail over the head, so the step across the join
			# should be no worse than an ordinary step inside the clip.
			_check_seam("res://game/enemies/wraith/sfx/drain.wav")

		# ---- The death, which is the one call that cannot use the ordinary
		# path: `queue_free()` takes the Audio child and every player under it,
		# so a die sound played the normal way runs for zero frames.
		70:
			_player().global_position = Vector2(272, 60)
			_victim = _spawn("regular", Vector2(400, 200))
			_victim.set("sight_radius", 0.0)
			_players_before = _audio_players_under(_level())
		74:
			_victim.call("take_damage", 999)
		78:
			_check("sfx: the body is gone (%s)"
				% ("freed" if not is_instance_valid(_victim) else "still here"),
				not is_instance_valid(_victim))
			var now := _audio_players_under(_level())
			_check("sfx: and its death outlived it, on the level (%d -> %d)"
				% [_players_before, now], now == _players_before + 1)
			_check("sfx: playing the stream the enemy owned (%s)"
				% _newest_detached_name(),
				_newest_detached_stream() != null)

		# ---- The mutters. Two enemies talk to themselves while they work, and
		# the thing that would ship silently here is a `voice` path that does not
		# resolve: a missing clip is LEGAL by design, so a typo plays nothing,
		# holds the line for as long as it takes to READ instead, and looks
		# exactly like an enemy who has not been recorded yet.
		82:
			for id in MUTTERERS:
				_audit_lines(id)
		86:
			# Scattered starts. Four of these spawn on one frame with their
			# cooldowns at zero, so a fixed first poll would have the whole room
			# speak at once and then settle into a rhythm - which sounds like a bug
			# and cannot be heard as an office. Six fresh ones should not share a
			# countdown.
			var starts: Array = []
			var crowd: Array[Node2D] = []
			for _i in 6:
				var one := _spawn("social_media", Vector2(560, 300))
				one.set("sight_radius", 0.0)
				crowd.append(one)
				starts.append(snappedf(float(one.get("_mutter_in")), 0.001))
			var distinct: Array = []
			for s in starts:
				if not distinct.has(s):
					distinct.append(s)
			_check("sfx: mutters start scattered, not in chorus (%d of 6 distinct)"
				% distinct.size(), distinct.size() > 1)
			var ceiling: float = _lines_of(crowd[0]).cue_seconds
			var outside: Array = starts.filter(func(s: float) -> bool:
				return s < 0.0 or s > ceiling)
			_check("sfx: and inside one cooldown of spawning (%s)"
				% ("all 6" if outside.is_empty() else str(outside)), outside.is_empty())
			for one in crowd:
				one.queue_free()

			_mutterer = _spawn("social_media", Vector2(120, 280))
			_mutterer.set("sight_radius", 0.0)
			# Forced rather than waited out: the first ask is up to a whole
			# cue_seconds away by design, which is 660 frames of watching nothing.
			# What is under test is that the poll SPEAKS, not when it first does.
			_mutterer.set("_mutter_in", 0.0)
		90:
			_check("sfx: the poll gets a line out (holding %s)"
				% _lines_of(_mutterer).holding(), _lines_of(_mutterer).holding())
			# And it stays off the screen. A boss overrides `_say` to emit `said`
			# and game.gd puts that on the subtitle; an enemy must not, because a
			# subtitle turns overhearing somebody into being addressed by them -
			# and four of these would fight each other for one box.
			# Reported as showing/hidden rather than by printing the label: the
			# subtitle scene carries Ahmed's "Get over here!" as editor placeholder
			# text, so the TEXT of a box nobody has written to is a line no one said.
			_check("sfx: and nothing of it reaches the subtitle (%s)"
				% ("showing" if _subtitle().call("showing") else "hidden"),
				not _subtitle().call("showing"))
		94:
			_finish()


## One enemy's sounds: the ids it declares, that each resolves, and that
## `_ready` built a player per entry. Instanced and then freed, so the room is
## exactly as empty afterwards as the frame-32 check found it.
func _audit(id: String, expected: Array) -> void:
	var enemy := _spawn(id, Vector2(560, 300))
	enemy.set("sight_radius", 0.0)
	var audio: Node = enemy.get_node_or_null("Audio")
	_check("sfx: %s carries its own sounds (%s)" % [id, audio], audio != null)
	var sounds: Dictionary = audio.get("sounds") if audio != null else {}

	var absent: Array = expected.filter(func(cue: String) -> bool:
		return not sounds.has(cue))
	_check("sfx: %s has every cue its archetype reaches (%s)"
		% [id, "all %d" % expected.size() if absent.is_empty() else str(absent)],
		absent.is_empty())
	# And nothing it can never reach. A `stagger` on a wraith is not harmless
	# noise in the folder - it is a file somebody generated, levelled and will
	# one day go looking for the bug in, because it never plays.
	var unreachable: Array = sounds.keys().filter(func(cue: String) -> bool:
		return not expected.has(cue))
	_check("sfx: %s has no cue it can never reach (%s)"
		% [id, "none" if unreachable.is_empty() else str(unreachable)],
		unreachable.is_empty())

	var missing: Array = sounds.keys().filter(func(cue: String) -> bool:
		return sounds[cue] == null)
	_check("sfx: %s - every declared sound resolves (%s)"
		% [id, "all" if missing.is_empty() else str(missing)], missing.is_empty())
	_check("sfx: %s - one player built per sound (%d of %d)"
		% [id, 0 if audio == null else audio.get_child_count(), sounds.size()],
		audio != null and audio.get_child_count() == sounds.size())
	enemy.queue_free()


## One mutterer's lines: that it carries a `Lines` child at all, that the file
## it names is its OWN (a copy-pasted scene pointing at the other one's mutters
## is silent-running and would take a long time to notice), and that every line
## in it has a clip that actually resolves to audio.
##
## That last one is the reason this section exists. `enemy_lines._play_voice()`
## treats a missing clip as legal - it returns 0.0 and the line is held for as
## long as it takes to read - so a mistyped path is not an error anywhere. It
## is an enemy who moves their lips.
func _audit_lines(id: String) -> void:
	var enemy := _spawn(id, Vector2(560, 300))
	enemy.set("sight_radius", 0.0)
	var lines := _lines_of(enemy)
	_check("sfx: %s carries a Lines child (%s)" % [id, lines], lines != null)
	var path: String = lines.lines if lines != null else ""
	_check("sfx: %s names its own mutters (%s)" % [id, path],
		path == "res://game/enemies/%s/mutters.gd" % id)

	var script := load(path) as GDScript if path != "" else null
	var all: Dictionary = script.get_script_constant_map().get("LINES", {}) 		if script != null else {}
	var spoken: Array = all.get(MUTTER, [])
	_check("sfx: %s has something to say (%d lines)" % [id, spoken.size()],
		spoken.size() >= 4)

	var silent: Array = []
	for line in spoken:
		var clip := String((line as Dictionary).get("voice", ""))
		var stream := load(clip) as AudioStream if ResourceLoader.exists(clip) 			else null
		if stream == null or stream.get_length() <= 0.0:
			silent.append(clip.get_file())
	_check("sfx: %s - every line has a clip behind it (%s)"
		% [id, "all %d" % spoken.size() if silent.is_empty() else str(silent)],
		silent.is_empty())
	enemy.queue_free()


func _lines_of(enemy: Node2D) -> Node:
	return enemy.get_node_or_null("Lines")


func _spawn(id: String, at: Vector2) -> Node2D:
	var enemy := (load(SCENE % [id, id]) as PackedScene).instantiate() as Node2D
	_level().get_node("Props").add_child(enemy)
	enemy.global_position = at
	return enemy


func _stream_of(enemy: Node2D, id: String) -> AudioStreamWAV:
	var audio := enemy.get_node_or_null("Audio")
	if audio == null:
		return null
	var player := audio.get_node_or_null("Sfx_%s" % id) as AudioStreamPlayer2D
	return null if player == null else player.stream as AudioStreamWAV


## The loop flag on one of an enemy's sounds, or -1 where there is no such
## player. Headless, this is how a `loop()` call is seen at all - the importer
## writes `loop_mode=0` on every WAV it was not told otherwise about, so the
## flag being set IS the call having happened. Same reading as
## test_bosses.gd's, against an enemy rather than a boss.
func _loop_mode_of(enemy: Node2D, id: String) -> int:
	var wav := _stream_of(enemy, id)
	return -1 if wav == null else wav.loop_mode


## Whether the join is inaudible: the step from the last sample back to the
## first, against the average step inside the clip. A raw export lands in the
## thousands against tens (see the root CLAUDE.md's Music); a sealed one lands
## in the same order as its own neighbours.
##
## Read off the SOURCE .wav on disk rather than out of the imported stream,
## and that is not a shortcut - it is the only reading that means anything.
## These import at `compress/mode=2`, which is QOA, so `AudioStreamWAV.get_data()`
## hands back COMPRESSED bytes rather than frames. Treating those as samples
## does not fail, it passes: it compares one noise to another and reports a
## plausible number. That check was written, it passed, and the numbers it
## printed were 1000x the ones the generator measures - which is how it was
## caught, and why the printed values stay in the label.
func _check_seam(path: String) -> void:
	var s := _pcm(path)
	if s.size() < 400:
		_check("sfx: the drain's loop seam is crossfaded (%d frames)" % s.size(), false)
		return
	# Sampled every 97th frame - coprime with anything periodic in the audio,
	# and it keeps a 2.5 s clip to a few hundred reads.
	var step := 0.0
	var taken := 0
	var i := 1
	while i < s.size():
		step += absf(s[i] - s[i - 1])
		taken += 1
		i += 97
	var typical := step / maxf(taken, 1)
	var seam := absf(s[s.size() - 1] - s[0])
	_check("sfx: the drain's loop seam is crossfaded (step %.0f vs typical %.0f)"
		% [seam, typical], seam <= maxf(typical * 4.0, 200.0))


## The samples of a 16-bit mono WAV on disk. Walks the chunk list rather than
## assuming a 44-byte header, because "the header is 44 bytes" is true of what
## tools/sfx writes and of nothing anybody might drop in beside it later.
func _pcm(path: String) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() < 44:
		return out
	f.seek(12)   # past "RIFF" + size + "WAVE"
	while f.get_position() + 8 <= f.get_length():
		var id := f.get_buffer(4).get_string_from_ascii()
		var size := f.get_32()
		if id == "data":
			var bytes := f.get_buffer(size)
			for i in range(0, bytes.size() - 1, 2):
				var v := bytes[i] | (bytes[i + 1] << 8)
				out.append(float(v - 65536 if v >= 32768 else v))
			return out
		f.seek(f.get_position() + size + (size & 1))
	return out


## Loose players left standing in the room - what `play_detached` parents to
## whoever was holding the enemy. Counted by EXCLUSION rather than by looking
## in one place: the host is the enemy's own parent, which is whatever node a
## level happens to keep its bodies under (`Props` today), and a check that
## hard-coded that would go quietly to zero the day a level nests them deeper.
## Every attached player is a child of an `Audio` node; a detached one is not.
func _detached(root: Node) -> Array:
	var found: Array = []
	for child in root.get_children():
		if child is AudioStreamPlayer2D and child.get_parent().name != &"Audio":
			found.append(child)
		found.append_array(_detached(child))
	return found


func _audio_players_under(level: Node) -> int:
	return _detached(level).size()


func _newest_detached() -> AudioStreamPlayer2D:
	var found := _detached(_level())
	return null if found.is_empty() else found[0] as AudioStreamPlayer2D


func _newest_detached_name() -> String:
	var player := _newest_detached()
	return "none" if player == null else str(player.stream)


func _newest_detached_stream() -> AudioStream:
	var player := _newest_detached()
	return null if player == null else player.stream
