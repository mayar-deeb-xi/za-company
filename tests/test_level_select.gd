extends "res://tests/helpers.gd"
## The development level select: that it stays out of the way while switched
## off, that switched on it comes after the character select, lists every floor
## in the order the doors lead, fits the screen, backs out by Escape, and that
## picking a floor starts the run there - once, not on every run after.

const Biomes := preload("res://tools/biomes.gd")
## Loaded when first used rather than preloaded: both name autoloads, and this
## file is compiled before the autoload list reaches the compiler.
var LevelSelect: GDScript
var GameType: GDScript

const SELECT := "res://ui/character_select/character_select.tscn"
const LEVELS := "res://ui/level_select/level_select.tscn"
const GAME := "res://game/game.tscn"


func _tick(frame: int) -> void:
	if LevelSelect == null:
		LevelSelect = load("res://ui/level_select/level_select.gd")
		GameType = load("res://game/game.gd")
	match frame:
		4:
			_check("switch: off unless asked for", not LevelSelect.enabled())
			# The walk is the screen's only source of truth, so it has to agree
			# with the chain the generators build from.
			var floors: Array = LevelSelect.floors()
			var walked: Array = floors.map(
				func(f: Dictionary) -> String: return f["path"])
			var chain: Array = Biomes.CHAIN.map(
				func(l: String) -> String: return "%s/%s.tscn" % [Biomes.dir(l), l])
			_check("floors: the doors walk the whole chain in order (%d of %d)"
				% [walked.size(), chain.size()], walked == chain)
			_check("floors: each is named as its title card names it (%s)"
				% floors[0]["title"], floors.all(func(f: Dictionary) -> bool:
					return f["title"] == Biomes.BIOMES[f["path"].get_file()
						.get_basename()].get("title", "")))
			_change(SELECT)
		8:
			_choose_first_character()
		16:
			_check("off: a character goes straight to the game (got %s)"
				% current_scene.scene_file_path,
				current_scene.scene_file_path == GAME)
			ProjectSettings.set_setting(LevelSelect.SETTING, true)
			_check("switch: on once set", LevelSelect.enabled())
			_change(SELECT)
		20:
			_choose_first_character()
		28:
			_check("on: a character opens the level select (got %s)"
				% current_scene.scene_file_path,
				current_scene.scene_file_path == LEVELS)
			var grid := current_scene.get_node("%Floors") as GridContainer
			_check("screen: one button per floor (%d)" % grid.get_child_count(),
				grid.get_child_count() == Biomes.CHAIN.size())
			_check("screen: focus starts on floor 1",
				(grid.get_child(0) as Button).has_focus())
			# Centred like the character select's column, so its bottom is half
			# of it below the middle and must clear the 28px footer.
			var need: Vector2 = (grid.get_parent() as Control).get_combined_minimum_size()
			_check("screen: the floors fit above the footer (%s)" % need,
				need.x <= 640 and 170 + need.y / 2 <= 360 - 28)
			_key(KEY_ESCAPE, true)
			_key(KEY_ESCAPE, false)
		34:
			_check("screen: Escape backs out to the character select (got %s)"
				% current_scene.scene_file_path,
				current_scene.scene_file_path == SELECT)
			_choose_first_character()
		42:
			var grid := current_scene.get_node("%Floors") as GridContainer
			(grid.get_child(3) as Button).pressed.emit()
		60:
			_check("pick: the game starts on the chosen floor (%s)"
				% (_level().scene_file_path if _level() != null else "none"),
				current_scene.scene_file_path == GAME and _level() != null
					and _level().scene_file_path == LevelSelect.floors()[3]["path"])
			_check("pick: spent on use, so the next run is the lobby again",
				GameType.next_start.is_empty())
			_check("pick: remembered for the next visit",
				_autoload("Settings").call("get_value", &"dev", &"level", "")
					== LevelSelect.floors()[3]["path"])
			_change(LEVELS)
		64:
			var grid := current_scene.get_node("%Floors") as GridContainer
			_check("screen: focus returns to the floor picked last",
				(grid.get_child(3) as Button).has_focus())
			_finish()


func _change(path: String) -> void:
	change_scene_to_file(path)


func _choose_first_character() -> void:
	var row := current_scene.get_node("%Roster") as GridContainer
	(row.get_child(0) as Button).pressed.emit()
