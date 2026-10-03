extends "res://tests/helpers.gd"
## A party of two on one machine (DESIGN.md's Multiplayer, M1): the keyboard
## drives this machine's player and synthesized hands drive the second, and
## every rule of a party is checked against the real game rather than promised.
##
## - The spawn: one body per member, each its own character, stood in a row
##   across the marker, and a head count of two.
## - The hands: the keyboard moves only its own body, and the second answers to
##   nothing but its input source - a press dated to the frame, as a key's is.
## - The room alert is anyone's: the SECOND player walking out of the doorway
##   wakes the room while the first stands in it.
## - The sticky target: an enemy goes for the nearest, holds on through a
##   near-tie, and turns only for somebody clearly closer.
## - The HUD: the big bar is this machine's, the second is a row under the
##   hearts, and a boss's health counts both heads.
## - Down and up: a death in company stops nobody else's game - no fade - and
##   spends one life from the ONE pool, and the body gets up at the door.
## - The door waits: "1/2" while one is in it, and it goes the moment the party
##   is complete - here because the one still out in the room goes down, which
##   no arrival announces. The body that was waiting to get up gets up on the
##   far side, and the wait that the door overtook does nothing when it ends.
## - The end: with the pool empty a death stays down, and the run is over only
##   when nobody is standing and nobody is about to be.
##
## It boots through the real menu like every other suite, with the party set on
## game.gd's `next_party` first, and stays on two floors: the empty lobby for
## everything that needs a quiet room, and the content studio for what happens
## on the far side of a door, where nobody leaves the doorway so the room never
## wakes.
##
## Frame budget: 60 fps. A get-up is GET_UP_SECONDS (3 s, 180 frames); a door
## is two fades of 0.28 s plus the swap, so ~40 frames.

const VirtualInput := preload("res://game/player/virtual_input.gd")
const Heads := preload("res://game/heads.gd")
const REGULAR := "res://game/enemies/regular/regular.tscn"
const AHMED := "res://game/bosses/ahmed/ahmed.tscn"
const STUDIO := "res://game/levels/content_studio/content_studio.tscn"

var _hands := VirtualInput.new()
var _start := Vector2.ZERO
var _guard: Node2D


func _tick(frame: int) -> void:
	match frame:
		2:
			# Loaded here and not preloaded: game.gd names autoloads, and a
			# --script file is compiled before they exist.
			var game_script: GDScript = load("res://game/game.gd")
			game_script.next_party = [{}, {"character": "anas", "input": _hands}]
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		17:
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
		32:
			_spawned()
			# Out of sight of everything, before anyone has left the doorway:
			# the alert is the only thing that can set it hunting.
			_guard = _place(REGULAR, Vector2(100, 100))
			_guard.set("sight_radius", 0.0)
			_hands.stick = Vector2.UP
		80:
			_hands.stick = Vector2.ZERO
			_check("hands: the second player walked on its own stick (%.0f px up)"
				% (_start.y - _second().global_position.y),
				_start.y - _second().global_position.y > 48.0)
			_check("hands: and the keyboard's player never moved (%.1f px)"
				% _player().global_position.distance_to(_start + Vector2(-6, 0)),
				_player().global_position.distance_to(_start + Vector2(-6, 0)) < 1.0)
			_check("alert: the second player walking out woke the room",
				current_scene.get("_room_alerted") == true)
			_check("alert: and the guard out of sight is hunting",
				_guard.get("hunting") == true)
			_guard.free()
		82:
			_key(KEY_SPACE, true)
		84:
			_key(KEY_SPACE, false)
			_check("hands: Space swings the keyboard's player (%s)" % _player().get("_attack"),
				_player().get("_attack") == "attack")
			_check("hands: and not the second (%s)" % _second().get("_attack"),
				_second().get("_attack") == "")
		90:
			_hands.hold(true)
		91:
			_hands.hold(false)
		93:
			_check("hands: a held button swings the second player (%s)"
				% _second().get("_attack"), _second().get("_attack") == "attack")
		130:
			# Down and up between two frames: Input's just-pressed still sees
			# that press, so the hands must too.
			_hands.hold(true)
			_hands.hold(false)
		133:
			_check("hands: a tap shorter than a frame still swings (%s)"
				% _second().get("_attack"), _second().get("_attack") == "attack")
		150:
			_guard = _place(REGULAR, Vector2(120, 150))
			_guard.set("sight_radius", 0.0)
			_guard.set("speed", 0.0)
			_player().global_position = Vector2(160, 150)
			_second().global_position = Vector2(220, 150)
		153:
			_check("target: the nearest player (40 px against 100)",
				_guard.call("target") == _player())
			_second().global_position = Vector2(120, 175)
		156:
			_check("target: a near-tie does not turn it (40 px against 25)",
				_guard.call("target") == _player())
			_player().global_position = Vector2(200, 150)
		159:
			_check("target: somebody clearly closer does (80 px against 25)",
				_guard.call("target") == _second())
			_player().global_position = Vector2(120, 128)
		162:
			_check("target: and then it sticks to them (22 px against 25)",
				_guard.call("target") == _second())
			_second().global_position = Vector2(300, 150)
		165:
			_check("target: until they are gone off (22 px against 180)",
				_guard.call("target") == _player())
			_guard.free()
			# The one enemy health that scales, by adding: two heads are
			# Ahmed's 144 plus his 48 a head.
			var ahmed := _place(AHMED, Vector2(460, 100))
			_check("heads: a boss counts both of them (%s of 144 + 48)"
				% ahmed.get("max_health"), ahmed.get("max_health") == 192)
			ahmed.free()
			_second().call("take_damage", 30)
		167:
			var row := _row()
			_check("hud: the second player's row shows their own health (%.0f of 40 px)"
				% (row.get_node("Fill") as ColorRect).size.x,
				(row.get_node("Fill") as ColorRect).size.x == 28.0)
			_check("hud: and the big bar is still this machine's (%.0f px)" % _fill().size.x,
				_fill().size.x == 66.0)
		180:
			_second().call("drain", 999)
		182:
			_check("down: a death in company is down, not respawned",
				_second().call("is_down") and not _second().is_in_group("player"))
			_check("down: and is no longer a head (%d)" % Heads.count(self),
				Heads.count(self) == 1)
			_check("down: the ONE pool paid for it (%s left)" % _lives(),
				_lives() == 2 and _heart_tex(1) == _heart_tex(0)
					and _heart_tex(2) != _heart_tex(0))
			_check("down: nobody else's game stopped - no fade, nothing frozen",
				_fade_alpha() == 0.0 and current_scene.get("_travelling") == false
					and _player().is_physics_processing())
			_check("down: and the HUD dims their row", _row().modulate.a < 1.0)
		340:
			_check("down: still down before the wait is up",
				_second().call("is_down"))
		370:
			_check("up: they got up at the door (%s)" % _second().global_position,
				not _second().call("is_down")
					and _second().global_position.distance_to(_start + Vector2(6, 0)) < 1.0)
			_check("up: whole again, and a head again (%s, %d)"
				% [_second().get("health"), Heads.count(self)],
				_second().get("health") == 100 and Heads.count(self) == 2
					and _second().is_physics_processing())
			_check("up: getting up cost nothing more (%s left)" % _lives(), _lives() == 2)
			_check("up: and their row is lit again", _row().modulate.a == 1.0)
			_player().global_position = Vector2(266, 24)
		385:
			_check("door: one of two in it waits (%s)" % _level().scene_file_path,
				_level().scene_file_path.ends_with("lobby.tscn"))
			var count := _level().get_node("Props/Exit/Count") as Node2D
			_check("door: and says so (%s)" % count.get("text"),
				count.visible and count.get("text") == "1/2")
		400:
			_check("door: still waiting a quarter of a second on",
				_level().scene_file_path.ends_with("lobby.tscn"))
			# Nobody arrives; the one still out in the room goes down instead,
			# and everyone left standing is already in the doorway.
			_second().call("drain", 999)
		450:
			_check("door: the party was complete, so it went (%s)" % _level().scene_file_path,
				_level().scene_file_path == STUDIO)
			var marker: Vector2 = _level().call("spawn_position", &"start")
			_check("door: both carried through, in a row across the marker",
				_player().global_position.distance_to(marker + Vector2(-6, 0)) < 1.0
					and _second().global_position.distance_to(marker + Vector2(6, 0)) < 1.0)
			_check("door: the one waiting to get up got up on the far side",
				not _second().call("is_down") and _second().get("health") == 100
					and (current_scene.get("_getting_up") as Dictionary).is_empty())
			_check("door: and that was the life it had already paid (%s left)" % _lives(),
				_lives() == 1)
			_second().call("drain", 10)
		600:
			# The wait the door overtook ended at ~580. Had it still stood them
			# up, it would have healed the 10 above.
			_check("door: the overtaken wait did nothing when it ran out (%s)"
				% _second().get("health"), _second().get("health") == 90)
			_second().call("drain", 999)
		602:
			_check("end: the last life goes to the one who fell (%s left)" % _lives(),
				_lives() == 0 and _second().call("is_down"))
			_player().call("drain", 999)
		604:
			_check("end: with the pool empty this machine's player stays down",
				_player().call("is_down"))
			_check("end: but somebody is still getting up, so the run goes on",
				not paused and not _pause_menu().get_node("Root").visible)
		800:
			_check("end: they got up (%s)" % Heads.count(self),
				not _second().call("is_down") and Heads.count(self) == 1)
			_check("end: and the one with no life left did not",
				_player().call("is_down"))
			_second().call("drain", 999)
		802:
			_check("end: nobody standing and nobody getting up is the end",
				paused and _pause_menu().get_node("Root").visible)
			_finish()


## Everything about the party as it is built, checked on its first frame.
func _spawned() -> void:
	var party: Array = current_scene.call("party")
	_check("spawn: one body per member (%d)" % party.size(), party.size() == 2)
	_check("spawn: both standing, and both heads (%d)" % Heads.count(self),
		Heads.count(self) == 2 and _player().is_in_group("player")
			and _second().is_in_group("player"))
	_check("spawn: each is the character they picked",
		_frames(_player()).ends_with("reem_frames.tres")
			and _frames(_second()).ends_with("anas_frames.tres"))
	_check("spawn: the second is driven by its own hands",
		_second().get("input_source") == _hands)
	_start = _level().call("spawn_position", &"start")
	_check("spawn: in a row across the start marker, 12 px apart (%s, %s)"
		% [_player().global_position, _second().global_position],
		_player().global_position.distance_to(_start + Vector2(-6, 0)) < 1.0
			and _second().global_position.distance_to(_start + Vector2(6, 0)) < 1.0)
	var rows: Array = _hud().call("party_rows")
	_check("hud: one row for the other player, by their name (%d)" % rows.size(),
		rows.size() == 1 and (rows[0].get_node("Name") as Label).text == "Anas")
	_check("hud: three hearts, which are the party's (%s)" % _lives(),
		_lives() == 3 and _hearts().get_child_count() == 3)
	# A party on one machine is offline: no connection, so nothing about one on
	# screen - no corner ping, no notice and no scoreboard, Tab or no Tab.
	_key(KEY_TAB, true)
	_check("hud: offline there is no ping, no notice and no scoreboard",
		_hud().call("ping_text") == "" and _hud().call("notice_text") == ""
			and current_scene.get_node_or_null("Scoreboard") == null
			and current_scene.call("scoreboard_up") == false)
	_key(KEY_TAB, false)


func _second() -> CharacterBody2D:
	return current_scene.get_node("Player2")


func _hud() -> Control:
	return current_scene.get_node("HUD/Hud")


func _row() -> Control:
	return (_hud().call("party_rows") as Array)[0]


func _frames(body: Node) -> String:
	return (body.get_node("AnimatedSprite2D") as AnimatedSprite2D).sprite_frames.resource_path


func _fade_alpha() -> float:
	return (current_scene.get_node("Transition/Fade") as ColorRect).color.a


## An enemy, under the level's Props like everything a level places.
func _place(path: String, at: Vector2) -> Node2D:
	var body := (load(path) as PackedScene).instantiate() as Node2D
	_level().get_node("Props").add_child(body)
	body.global_position = at
	return body
