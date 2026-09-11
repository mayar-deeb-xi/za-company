extends Node2D
## The noise one body makes. Shared like `enemy_base.gd` is shared - the
## MECHANISM is here, the sounds are per enemy, exactly the way the fire
## shapes are shared between bosses and the ramp is not.
##
## It was written for the bosses and moved here when the plain enemies wanted
## the identical node for the identical job: a boss IS an enemy, so this sits
## one level above both, beside `enemy_base.gd`, on the placement rule in
## CLAUDE.md. `wraith_base.gd` made the same journey for the same reason.
##
## A scene fills `sounds` with id -> stream and nothing else happens:
## `enemy_base` already calls `windup`, `hit`, `hurt`, `stagger` and `die` on
## whichever of them exist, and `boss_base` adds `concede` and a telegraph and
## impact per attack, so a body gets its sounds by owning the files. One that
## owns none stays silent without a single branch anywhere. Ids this node does
## not have are not an error - they are a fighter who has not been given that
## sound yet, which is most of them most of the time, and which is also what a
## fresh checkout looks like before the WAVs are imported.
##
## One player per id, built once: an id retriggered mid-play restarts rather
## than stacking, which is what a grunt on a four-hit combo wants.
##
## Positional (AudioStreamPlayer2D) so a body crossing the room pans, with the
## attenuation flattened right down - an arena is one screen wide and a fight
## that gets quieter at the edge of it is a bug, not atmosphere. It matters
## more for the ordinary enemies than it ever did for a boss: a room holds up
## to seven of them, and which corner a wind-up came from is the whole of what
## panning is for.

## id -> AudioStream. Filled per enemy in its own scene.
@export var sounds: Dictionary = {}
## Trim for the whole body, over the levels baked into the files themselves.
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


## Fire and keep firing - the wraith's drain, a boss's fire. The loop flag is
## set on the stream HERE rather than trusted to the .import, because the
## import settings are written by whoever first scanned the file and a silent
## failure to loop is hard to see in a fight.
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


## Fire a sound that must outlive the node making it, at a place in the world.
##
## Only a DEATH needs this, and it needs it completely: an enemy plays `die`
## on the frame it is `queue_free`d, and every player under this node is freed
## with it, so the ordinary `play()` above starts a sound and destroys it in
## the same frame. `host` is somebody who will still be standing - the enemy's
## parent, i.e. the level - and the copy buries itself when it finishes.
##
## A boss never calls this. He concedes instead of dying and is still in the
## room when you leave, which is exactly why the problem never came up until
## the things that DO die got sounds.
func play_detached(id: String, host: Node, at: Vector2) -> void:
	var stream: AudioStream = sounds.get(id)
	if stream == null or host == null or not is_instance_valid(host):
		return
	var one_shot := AudioStreamPlayer2D.new()
	one_shot.stream = stream
	one_shot.volume_db = volume_db
	one_shot.max_distance = max_distance
	one_shot.attenuation = attenuation
	host.add_child(one_shot)
	# After add_child: global_position on a node outside the tree has no parent
	# transform to resolve against, so setting it first puts the sound at the
	# level's origin - a death in the far corner heard from the door.
	one_shot.global_position = at
	one_shot.finished.connect(one_shot.queue_free)
	one_shot.play()


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
