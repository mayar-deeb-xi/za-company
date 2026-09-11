extends CharacterBody2D
## Base for every NPC. An NPC is a colleague, not a combatant: it stands where
## it is put, faces where it is told, and walks only if something asks it to.
##
## ## Friendly is a matter of which groups it is in
##
## An NPC is in the `npcs` group and in NEITHER `player` nor `enemies`. Nothing
## else is needed to make the world leave it alone, because nothing in the game
## reaches the player by type - enemies find their target through the `player`
## group, and the player's sword finds its targets through `enemies`. So an NPC
## is invisible to both by construction rather than by a flag anyone has to
## remember to set, and adding a third friendly face is a scene in this folder
## and nothing else.
##
## ## Standing still is the normal case
##
## Both NPCs the game has are stationary: Dominique is behind a desk and Ivan is
## in a corner. `walk_to()` exists anyway, because an NPC that never moves is
## one script change away from being an NPC that walks somewhere once, and a
## sheet that already holds a walk cycle should not have to grow a script to use
## it. Nothing calls it yet.
##
## ## Everyone is wearing a name badge
##
## Every NPC carries its name over its head, always on, from the moment the
## room is built - the same name the subtitles put in front of its lines, taken
## from the same place (`speaker_name()`), so the person you walked up to and
## the person talking are never two different labels. It sits between the head
## and where the prompt appears, so the two never fight for the same pixels,
## and it is drawn in the subtitles' gold with a dark outline rather than on a
## plate: a plate would have to be as wide as the longest name, and HR's white
## dress against the marble hall is the case that decides it - an outline reads
## on any floor, on any garment, at any length.
##
## ## Talking is the one thing all of them do
##
## An NPC carries a `conversation` - a path to a .gd holding `const BEATS` - and
## nothing else about dialogue. It does not run one: it notices the player is in
## range, shows a prompt, and emits `talk_requested`. game.gd wires that to the
## director in game.tscn, exactly as it wires a door's `travelled` and a boss's
## `health_changed`, so the NPC never learns that a subtitle box exists and the
## box never learns that an NPC does.
##
## ## Speed
##
## Half the player's, which is the one number here that is a RATIO rather than a
## measurement - see SPEED. Everything else about how an NPC moves is the
## simplest thing that works: no acceleration curve, no pathfinding, no sliding
## off geometry into a recovery. An NPC crossing a room is a scripted beat, not
## a chase.

## Half the player's 90 (game/player/player.gd's SPEED). Deliberately a plain
## number rather than a read of that constant, exactly as the enemies' speeds
## are: a level retunes the instance it places, and coupling every NPC in the
## building to the player's walk would mean a movement tweak silently
## restaging every scripted walk in the game. If the player's speed moves and
## an NPC should follow it, that is an edit here, on purpose.
@export var speed := 45.0

## Which way it faces while standing. Dominique faces the lobby (DOWN); an NPC
## against the north wall wants UP.
@export_enum("down", "up", "side") var facing := "down"
## Only meaningful when `facing` is "side".
@export var face_left := false

@export_group("Dialogue")
## A .gd holding `const BEATS` - see game/dialogue/dialogue_director.gd for the
## format. Empty means this one has nothing to say, and no prompt appears.
@export_file("*.gd") var conversation := ""
## The name over the subtitles. Empty falls back to the roster's, which is what
## every NPC should want - a display name is the roster's business, and typing
## it a second time in a scene is how the two drift apart.
@export var speaker := ""
## Starts the conversation by itself the first time the player comes into range,
## instead of waiting for the key. For the one who greets you at the door.
@export var greets := false

signal talk_requested(npc: Node2D)

enum Facing { DOWN, UP, SIDE }

const Roster := preload("res://game/npcs/roster.gd")

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _prompt: Control = $Prompt
@onready var _nameplate: Label = $Nameplate

var _facing: Facing = Facing.DOWN
var _facing_left := false
## Where it has been told to walk, or null while it is standing.
var _target = null
## Whether the player is standing close enough to be talked to, and whether a
## conversation is under way - the director sets the second through
## `set_talking()`, and the prompt is the two of them together.
var _near := false
var _talking := false
## A greeter greets once per visit. Not per SAVE: rooms are re-instantiated on
## every entry (see the root CLAUDE.md), so this resets with the level, like a
## consumed pickup does.
var _greeted := false


func _ready() -> void:
	var area := $TalkArea as Area2D
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	_prompt.visible = false
	# Written from the roster rather than trusted from the scene: the text
	# sitting in the .tscn is only there so the editor shows something over the
	# head, and a scene whose label and frames disagree is the drift
	# `speaker_name()` exists to prevent.
	_nameplate.text = speaker_name()
	_nameplate.visible = _nameplate.text != ""
	_facing_left = face_left
	match facing:
		"up":
			_facing = Facing.UP
		"side":
			_facing = Facing.SIDE
		_:
			_facing = Facing.DOWN
	_apply_animation("idle")


func _physics_process(_delta: float) -> void:
	if _target == null:
		velocity = Vector2.ZERO
		_apply_animation("idle")
		return

	var to_target: Vector2 = _target - global_position
	# Stop inside a pixel rather than on an exact match: move_and_slide() can
	# be nudged off the line by anything it touches, and an NPC jittering
	# forever on the last half-pixel is the failure this avoids.
	if to_target.length() <= 1.0:
		_target = null
		velocity = Vector2.ZERO
		_apply_animation("idle")
		return

	var direction := to_target.normalized()
	_face(direction)
	velocity = direction * speed
	_apply_animation("walk")
	move_and_slide()


## The player is close enough to be spoken to, and nothing else is going on.
## `greets` turns arriving in range into the request itself; otherwise the
## prompt goes up and the key makes it.
func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or conversation == "":
		return
	_near = true
	_refresh_prompt()
	if greets and not _greeted:
		_greeted = true
		talk_requested.emit(self)


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_near = false
	_refresh_prompt()


## Unhandled, so the subtitle box - which marks its own presses handled - gets
## the key first while it is open. The director declines a second conversation
## anyway; this just keeps the prompt from flickering under one.
func _unhandled_input(event: InputEvent) -> void:
	if not _near or _talking or conversation == "":
		return
	if not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	talk_requested.emit(self)


## Called by the director on both edges of a conversation. The only thing it
## changes here is the prompt: an NPC being talked to should not also be
## advertising that it can be talked to.
func set_talking(talking: bool) -> void:
	_talking = talking
	_refresh_prompt()


func conversation_path() -> String:
	return conversation


## The roster's name unless the scene overrides it - see `speaker`.
func speaker_name() -> String:
	if speaker != "":
		return speaker
	return String(Roster.find(_roster_id()).get("name", ""))


## Turn to look at something without moving, so a guide who has just walked
## somewhere is not delivering the next line to a wall.
func face_towards(point: Vector2) -> void:
	var to_point := point - global_position
	if to_point == Vector2.ZERO:
		return
	_face(to_point)
	_apply_animation("idle")


func _refresh_prompt() -> void:
	_prompt.visible = _near and not _talking and conversation != ""


## Which roster entry this scene is, taken from the frames it was built with:
## `game/npcs/<id>/<id>_frames.tres`. Derived rather than exported because the
## sheet is already the identity - a scene pointing at Ivan's frames and
## calling itself Dominique is a bug, not a configuration.
func _roster_id() -> String:
	var frames := _sprite.sprite_frames
	if frames == null:
		return ""
	return frames.resource_path.get_file().trim_suffix("_frames.tres")


## Walk to a point in world space, at this NPC's own speed. Call again to
## redirect, or `stop()` to give up on it.
func walk_to(target: Vector2) -> void:
	_target = target


func stop() -> void:
	_target = null


## True while it is on its way somewhere.
func walking() -> bool:
	return _target != null


func _face(direction: Vector2) -> void:
	# Horizontal wins ties, so a diagonal reads as the side profile - the same
	# rule the enemies use, so everything in a room turns alike.
	if absf(direction.x) >= absf(direction.y):
		_facing = Facing.SIDE
		_facing_left = direction.x < 0.0
	else:
		_facing = Facing.UP if direction.y < 0.0 else Facing.DOWN


func _apply_animation(state: String) -> void:
	_sprite.flip_h = _facing == Facing.SIDE and _facing_left
	var suffix := "down"
	match _facing:
		Facing.UP:
			suffix = "up"
		Facing.SIDE:
			suffix = "side"
	var anim := "%s_%s" % [state, suffix]
	if _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)
