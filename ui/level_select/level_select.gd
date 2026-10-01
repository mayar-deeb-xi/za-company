extends Control
## Development only: pick which floor a run starts on. Sits between the
## character select and the game, and only when it is switched on - Project >
## Tools > za-build > "Level select screen (dev)", which flips SETTING in
## project.godot. Off, the character select goes straight to the game exactly
## as it always has. A release export never shows it whatever the setting says.
##
## The floors are found by WALKING THE DOORS from game.gd's START_LEVEL rather
## than read from tools/biomes.gd's CHAIN: the game never loads a tools/ script,
## and the door targets baked into each level scene are the chain as the game
## actually plays it. Each scene's state is read without instancing it.

const SETTING := "za/dev/level_select"
const GAME_SCENE := "res://game/game.tscn"
const SELECT_SCENE := "res://ui/character_select/character_select.tscn"
## By preloaded script rather than class_name, like the rest of the project.
const GameType := preload("res://game/game.gd")

@onready var _grid: GridContainer = %Floors
@onready var _back_button: Button = %BackButton


## Whether the character select should come here rather than to the game.
static func enabled() -> bool:
	return OS.is_debug_build() and bool(ProjectSettings.get_setting(SETTING, false))


## Every floor in the order the doors lead, as {"path", "title"}. The first
## door out of a room that names a room not yet seen is the way up; the way
## back down always names one already seen, and the top floor has no way up.
static func floors() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen := {}
	var path: String = GameType.START_LEVEL
	while not path.is_empty() and not seen.has(path):
		seen[path] = true
		var state := (load(path) as PackedScene).get_state()
		var title := path.get_file().get_basename()
		var up := ""
		for node in state.get_node_count():
			for p in state.get_node_property_count(node):
				var key := state.get_node_property_name(node, p)
				var value: Variant = state.get_node_property_value(node, p)
				if node == 0 and key == &"display_name" and not String(value).is_empty():
					title = value
				elif key == &"target_level" and up.is_empty() and not seen.has(value):
					up = value
		out.append({"path": path, "title": title})
		path = up
	return out


func _ready() -> void:
	_back_button.pressed.connect(_go_back)
	# Asked again for the same reason the character select asks: a no-op while
	# the menu track is already playing, a start when entered directly.
	Music.play(Music.MENU)

	var saved: String = Settings.get_value(&"dev", &"level", "")
	var first: Button = null
	var focus_target: Button = null
	var list := floors()
	for i in list.size():
		var button := Button.new()
		button.name = list[i]["path"].get_file().get_basename()
		button.text = "%d  %s" % [i + 1, list[i]["title"]]
		button.custom_minimum_size = Vector2(280, 0)
		# The settings dropdowns' size rather than a menu button's: twelve
		# floors at 20px is six rows that do not fit the 360px screen.
		button.add_theme_font_size_override("font_size", 16)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_choose.bind(list[i]["path"]))
		_grid.add_child(button)
		if first == null:
			first = button
		if list[i]["path"] == saved:
			focus_target = button
	if first != null:
		(focus_target if focus_target != null else first).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		# Here rather than in _go_back(), which the Back BUTTON also calls.
		UiSound.back()
		_go_back()


func _go_back() -> void:
	get_tree().change_scene_to_file(SELECT_SCENE)


## Remembered so the next visit starts on the floor being worked on, and handed
## to the game for this one run only.
func _choose(path: String) -> void:
	Settings.set_value(&"dev", &"level", path)
	GameType.next_start = path
	get_tree().change_scene_to_file(GAME_SCENE)
