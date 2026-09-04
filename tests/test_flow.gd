extends "res://tests/helpers.gd"
## Flow test: the journey. Select -> game -> movement -> pause -> zoom from the
## pause menu -> attack animation -> torch -> heart -> death and respawn ->
## wall collision -> both doors -> back to the menu -> a second run that spends
## every life and ends at the death screen.
##
## Zoom lives here rather than in test_menu because it needs what only a run
## has: a camera framing a level behind a paused tree.


func _tick(frame: int) -> void:
	match frame:
		2:
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		14:
			# Pick someone who is NOT the default, so the frame swap is provable.
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
		26:
			_check("play: reaches game scene (got %s)" % current_scene.scene_file_path,
				current_scene.scene_file_path == "res://game/game.tscn")
			_check("select: chosen character is saved",
				_autoload("Settings").call("get_value", &"player", &"character", "")
					== "reem")
			_check("select: player wears the chosen character's frames (got %s)"
				% _sprite().sprite_frames.resource_path,
				_sprite().sprite_frames.resource_path.ends_with("reem_frames.tres"))
			_check("game: player sprite frames load (32x32)",
				_sprite().sprite_frames.get_frame_texture("walk_down", 0).get_size()
					== Vector2(32, 32))
			_check("level: the lobby loads first (got %s)"
				% ("<none>" if _level() == null else _level().name),
				_level() != null and _level().name == "Lobby")
			# Floor 1 is deliberately the one room with nothing in it: the first
			# thing a new player does is walk, and the lobby is where they learn
			# that safely. Anything spawning here is a placement mistake.
			_check("level: the lobby is empty of enemies (%d)"
				% get_nodes_in_group("enemies").size(),
				get_nodes_in_group("enemies").is_empty())
			# Empty of enemies is not the same as empty. The furniture is what
			# says this is an office rather than a dungeon with the lights on,
			# and it is the fragile half: re-running build_levels.gd overwrites a
			# level's dressing, so a run with stale data would ship a bare box
			# and every other check here would still pass.
			var dressing := ["Reception1", "Cooler1", "Desk1", "Sofa1", "Banner1"]
			var missing: Array = dressing.filter(func(n: String) -> bool:
				return _level().get_node_or_null("Props/" + n) == null)
			_check("level: the lobby is dressed as an office lobby (missing %s)"
				% [missing], missing.is_empty())
			# The title card names the room on arrival, and arriving at the start
			# of a run counts - the lobby gets announced like anywhere else.
			_check("title: the room announces itself on arrival (got '%s' at %.2f)"
				% [_title_text(), _title().modulate.a],
				_title_text() == "THE LOBBY" and _title().modulate.a == 1.0)
			_check("level: player spawned on the level's start marker (%s)"
				% _player().global_position,
				_player().global_position == Vector2(272, 240))
			_check("camera: the whole level is on screen (view %s vs level %s)"
				% [_view_size(), _level().bounds().size],
				_view_size().x >= _level().bounds().size.x
					and _view_size().y >= _level().bounds().size.y)
			_check("camera: centred on the level, since it fits (%s)"
				% _camera().global_position,
				_camera().global_position == _level().bounds().get_center())
			_check("level: doorway is a real gap in the wall ring, sealed by the door",
				(_level().get_node("Walls") as TileMapLayer)
					.get_cell_source_id(Vector2i(16, 0)) == -1
				and _level().get_node("Props/Exit/Seal") is StaticBody2D)
			_mark = _player().global_position
			_key(KEY_W, true)
		56:
			_check("move: W moves the player up", _player().global_position.y < _mark.y - 5.0)
			_check("move: walk_up animation (got %s)" % _sprite().animation,
				_sprite().animation == "walk_up")
			_key(KEY_W, false)
			_key(KEY_ESCAPE, true)
			_key(KEY_ESCAPE, false)
		62:
			_check("pause: Escape pauses and shows the overlay",
				paused and _pause_menu().get_node("Root").visible)
			_check("pause: Continue has keyboard focus",
				(_pause_menu().get_node("%ContinueButton") as Button).has_focus())
			_mark = _player().global_position
			_key(KEY_W, true)
		92:
			_check("pause: player is frozen (moved %.2f px)"
				% _player().global_position.distance_to(_mark),
				_player().global_position.distance_to(_mark) < 0.01)
			_key(KEY_W, false)
			(_pause_menu().get_node("%SettingsButton") as Button).pressed.emit()
		98:
			_check("settings: opens from the pause menu, still paused",
				_panel(_pause_menu()).visible and paused)
			_check("settings: window mode dropdown takes focus",
				(_panel(_pause_menu()).get_node("%ModeOption") as OptionButton)
					.has_focus())
			# Off the centre line first, or following and centring would put the
			# camera in the same place and the next check would prove nothing.
			_player().global_position = Vector2(100, 200)
			# Zoom in from the pause menu. It has to take effect immediately,
			# with the tree paused, or the player cannot see what they picked.
			_pick(_zoom_option(_pause_menu()), _zooms().find(2.0))
		101:
			_check("zoom: 200%% takes effect while still paused (zoom %s)"
				% _camera().zoom, _camera().zoom == Vector2(2, 2) and paused)
			_check("zoom: the view is now smaller than the level (%s vs %s)"
				% [_view_size(), _level().bounds().size],
				_view_size().x < _level().bounds().size.x)
			_check("zoom: camera follows the player instead of centring (%s)"
				% _camera().global_position,
				_camera().global_position.x != _level().bounds().get_center().x)
			_check("zoom: choice is saved", _saved(&"zoom", 0) == 2)
			# Labelled by percentage, not by how much of a room it happens to
			# show: a name like "WHOLE ROOM" stops being true once a level is
			# bigger than the screen.
			_check("zoom: every level in Display.ZOOMS is offered, as a percentage",
				_zoom_option(_pause_menu()).item_count == _zooms().size()
				and _zoom_option(_pause_menu())
					.get_item_text(_zooms().find(1.5)) == "150%")
			# The jump straight from the whole room to a quarter of it was too big.
			var between: Array = _zooms().filter(func(z): return z > 1.0 and z < 2.0)
			_check("zoom: two steps sit between 100%% and 200%% (%s)" % [between],
				between.size() == 2)
			_pick(_zoom_option(_pause_menu()), 0)
		103:
			_check("zoom: back to 100%% re-centres on the level (%s)"
				% _camera().global_position,
				_camera().zoom == Vector2(1, 1)
					and _camera().global_position == _level().bounds().get_center())
			_key(KEY_ESCAPE, true)
			_key(KEY_ESCAPE, false)
		104:
			# The interesting case: Escape has to back out of settings without
			# also unpausing the game underneath it.
			_check("settings: Escape closes the panel but does NOT unpause",
				not _panel(_pause_menu()).visible and paused)
			_check("settings: focus returns to the button that opened it",
				(_pause_menu().get_node("%SettingsButton") as Button).has_focus())
			_key(KEY_ESCAPE, true)
			_key(KEY_ESCAPE, false)
		110:
			_check("pause: Escape resumes", not paused)
			_key(KEY_SPACE, true)
			_key(KEY_SPACE, false)
		114:
			_check("attack: animation plays (got %s)" % _sprite().animation,
				String(_sprite().animation).begins_with("attack"))
		153:
			_check("attack: releases back to idle (got %s)" % _sprite().animation,
				String(_sprite().animation).begins_with("idle"))
			# Health: stand in the torch, then on the heart, then die outright.
			# One landing is one tick - the player's grace window is the meter.
			_check("hud: health bar starts full (%s)" % _player().get("health"),
				_player().get("health") == 100 and _fill().size.x == 66.0
					and _percent().text == "100%")
			_check("hud: three full hearts to start (%s lives, %d icons)"
				% [_player().get("lives"), _hearts().get_child_count()],
				_player().get("lives") == 3 and _hearts().get_child_count() == 3
					and _heart_tex(0) == _heart_tex(2))
			_player().global_position = Vector2(120, 152)
		166:
			_check("torch: standing in the flame costs health (%s)"
				% _player().get("health"), _player().get("health") < 100)
			_check("hud: the bar tracks the hit (%.0f px, '%s')"
				% [_fill().size.x, _percent().text],
				_fill().size.x < 66.0
					and _percent().text == "%d%%" % int(_player().get("health")))
			_health_mark = _player().get("health")
			_player().global_position = Vector2(424, 152)
		176:
			_check("heart: healed on touch (%d -> %s)"
				% [_health_mark, _player().get("health")],
				int(_player().get("health")) > _health_mark)
			_check("heart: consumed on pickup",
				_level().get_node_or_null("Props/Health") == null)
		206:
			# Waited out the torch hit's grace window, so this lethal hit lands.
			_player().call("take_damage", 9999)
		256:
			_check("death: respawns at the level's start with full health (%s at %s)"
				% [_player().get("health"), _player().global_position],
				_player().get("health") == 100
					and _player().global_position.distance_to(Vector2(272, 240)) < 1.0)
			_check("death: hud bar refilled (%.0f px, '%s')"
				% [_fill().size.x, _percent().text],
				_fill().size.x == 66.0 and _percent().text == "100%")
			_check("death: one life spent, hud dims the last heart (%s left)"
				% _player().get("lives"),
				_player().get("lives") == 2
					and _heart_tex(0) == _heart_tex(1)
					and _heart_tex(2) != _heart_tex(0))
			_check("death: fade cleared",
				(current_scene.get_node("Transition/Fade") as ColorRect).color.a < 0.01)
			_player().global_position = Vector2(40, 180)
			_key(KEY_A, true)
		346:
			_check("collision: tiled left wall blocks the player (x=%.1f)"
				% _player().global_position.x,
				_player().global_position.x > 16.0)
			# Three seconds and a fade later the card is gone on its own. Checked
			# this late rather than at the 204 frames it costs, because the tree
			# was paused for the settings section and a paused tween does not
			# count down.
			_check("title: the card takes itself away (%.2f)" % _title().modulate.a,
				_title().modulate.a == 0.0)
			_key(KEY_A, false)
			# Walk north into the doorway. Approaching on foot rather than
			# teleporting onto the threshold is the point: this is the path a
			# player actually takes through the door.
			_player().global_position = Vector2(272, 78)
			_key(KEY_W, true)
		421:
			_key(KEY_W, false)
			_check("door: walking north out of the lobby loads the bullpen (got %s)"
				% ("<none>" if _level() == null else _level().name),
				_level() != null and _level().name == "Bullpen")
			_check("door: player arrives by the bullpen's south door (%s)"
				% _player().global_position,
				_player().global_position.distance_to(Vector2(272, 240)) < 40.0)
			_check("door: transition faded back in",
				(current_scene.get_node("Transition/Fade") as ColorRect).color.a < 0.01)
			_check("door: camera reframed on the new level (%s)"
				% _camera().global_position,
				_camera().global_position == _level().bounds().get_center())
			_check("title: walking through a door announces the new room (got '%s' at %.2f)"
				% [_title_text(), _title().modulate.a],
				_title_text() == "THE BULLPEN" and _title().modulate.a == 1.0)
			# Floor 2 is where the game starts having enemies in it at all, and
			# they are the COMPANY's - the office boys, not dungeon guards. The
			# scene path is what proves that, since build_levels.gd names every
			# enemy instance Enemy<n> whatever type it is.
			var boys := get_nodes_in_group("enemies")
			var reskinned: Array = boys.filter(func(e: Node) -> bool:
				return e.scene_file_path.contains("office_boy"))
			_check("enemies: the bullpen fields four office boys (%d of %d)"
				% [reskinned.size(), boys.size()],
				boys.size() == 4 and reskinned.size() == 4)
			_check("enemies: an office boy is a reskin, so it has a guard's health (%s)"
				% (boys[0].get("max_health") if not boys.is_empty() else "<none>"),
				not boys.is_empty() and boys[0].get("max_health") == 24)
			# Nothing has noticed the player yet, which is the placement rule
			# this room has to keep: the walk from the south door to the north
			# one passes no office boy's 80 px sight.
			var awake: Array = boys.filter(func(e: Node) -> bool:
				return e.get("phase") != 0)
			_check("enemies: the door-to-door walk wakes nobody (%d awake)"
				% awake.size(), awake.is_empty())
			# The junk is the room. Same guard as the lobby's dressing check, and
			# it matters more here: a regeneration with stale data would leave an
			# empty box that still passed every other check on this floor.
			var junk := ["ServerRack1", "Printer1", "CrtStack1", "Toolbox1",
				"CableSpool1", "ScrapPile1", "Debris1", "Notice1"]
			var absent: Array = junk.filter(func(n: String) -> bool:
				return _level().get_node_or_null("Props/" + n) == null)
			_check("level: the bullpen is dressed as a repair floor (missing %s)"
				% [absent], absent.is_empty())
			# On along the chain, approaching the next door from the same distance
			# the lobby's was taken from.
			_player().global_position = Vector2(272, 78)
			_key(KEY_W, true)
		501:
			_key(KEY_W, false)
			_check("door: the chain continues on into the marble hall (got %s)"
				% ("<none>" if _level() == null else _level().name),
				_level() != null and _level().name == "MarbleHall")
			var guards := get_nodes_in_group("enemies")
			_check("enemies: the marble hall fields four guards (%d)" % guards.size(),
				guards.size() == 4)
			_player().global_position = Vector2(272, 78)
			_key(KEY_W, true)
		581:
			_key(KEY_W, false)
			_check("door: the chain continues on into hellfire (got %s)"
				% ("<none>" if _level() == null else _level().name),
				_level() != null and _level().name == "Hellfire")
			# Still up, and reading the room we are in now: a second card cuts the
			# first one off rather than queueing behind it.
			_check("title: a new room replaces the last one's name (got '%s' at %.2f)"
				% [_title_text(), _title().modulate.a],
				_title_text() == "HELLFIRE" and _title().modulate.a == 1.0)
			# Per-biome composition, second half: hellfire is the room that
			# escalates, and both of its extras are identified by their own
			# exports rather than by class, the way everything here avoids the
			# class cache.
			var here := get_nodes_in_group("enemies")
			var drainers := here.filter(func(e): return e.get("drain_per_second") != null)
			var slowers := here.filter(func(e): return e.get("slow_seconds") != null)
			_check("enemies: hellfire fields all three types (%d: %dD %dS)"
				% [here.size(), drainers.size(), slowers.size()],
				here.size() == 7 and drainers.size() == 2 and slowers.size() == 1)
			# Turn round and walk back out the way we came in. The wraith is on
			# the far wall, outside its own 120 px sight of this whole path.
			_key(KEY_S, true)
		661:
			_key(KEY_S, false)
			_check("return: hellfire's south door goes back to the marble hall (got %s)"
				% ("<none>" if _level() == null else _level().name),
				_level() != null and _level().name == "MarbleHall")
			_check("return: player arrives by the door they left through (%s)"
				% _player().global_position,
				_player().global_position.distance_to(Vector2(272, 80)) < 60.0)
			_key(KEY_ESCAPE, true)
			_key(KEY_ESCAPE, false)
		667:
			(_pause_menu().get_node("%MainMenuButton") as Button).pressed.emit()
		679:
			_check("pause: Main Menu returns to the menu, unpaused (got %s)"
				% current_scene.scene_file_path,
				current_scene.scene_file_path == "res://ui/main_menu/main_menu.tscn"
					and not paused)
			# Second run: spend every life and prove the run actually ends.
			(current_scene.get_node("%PlayButton") as Button).pressed.emit()
		691:
			(current_scene.get_node("%Roster/reem") as Button).pressed.emit()
		703:
			_check("lives: a new run starts with all three again (%s)"
				% _player().get("lives"),
				current_scene.scene_file_path == "res://game/game.tscn"
					and _player().get("lives") == 3)
			_player().call("take_damage", 9999)
		756:
			_check("lives: first death respawns with two left (%s, health %s)"
				% [_player().get("lives"), _player().get("health")],
				_player().get("lives") == 2 and _player().get("health") == 100)
			_player().call("take_damage", 9999)
		806:
			_check("lives: second death respawns with one left (%s)"
				% _player().get("lives"),
				_player().get("lives") == 1 and _player().get("health") == 100)
			_player().call("take_damage", 9999)
		856:
			_check("game over: the last death raises the death screen, paused",
				paused and _pause_menu().get_node("Root").visible)
			_check("game over: heading reads YOU DIED (got '%s')"
				% (_pause_menu().get_node("%Heading") as Label).text,
				(_pause_menu().get_node("%Heading") as Label).text == "YOU DIED")
			_check("game over: CONTINUE is disabled, MAIN MENU has focus",
				(_pause_menu().get_node("%ContinueButton") as Button).disabled
					and (_pause_menu().get_node("%MainMenuButton") as Button)
						.has_focus())
			# Escape must not dismiss a finished run - there is nothing to
			# resume back into.
			_key(KEY_ESCAPE, true)
			_key(KEY_ESCAPE, false)
		862:
			_check("game over: Escape cannot dismiss the death screen",
				paused and _pause_menu().get_node("Root").visible)
			(_pause_menu().get_node("%MainMenuButton") as Button).pressed.emit()
		874:
			_check("game over: MAIN MENU leaves the run, unpaused (got %s)"
				% current_scene.scene_file_path,
				current_scene.scene_file_path == "res://ui/main_menu/main_menu.tscn"
					and not paused)
			_finish()
