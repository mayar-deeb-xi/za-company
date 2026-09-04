@tool
extends ConfirmationDialog
## Which levels build_levels.gd should be told to rebuild.
##
## It is a list of checkboxes rather than one choice, and that is the whole
## reason the dialog exists: a door's `target_level` is baked into the level
## scene, so rebuilding one floor whose neighbours moved leaves those
## neighbours still pointing past it. **Include neighbours** is on by default
## for exactly that, and the summary line underneath shows what will actually
## be passed after `--`, in chain order, before you commit to it.
##
## Built in code rather than as a .tscn on purpose: it reads CHAIN at open
## time, so a floor added or reordered since the last build is simply there.

const Biomes := preload("res://tools/biomes.gd")

var _boxes := {}
var _neighbours: CheckBox
var _summary: Label


func _init() -> void:
	title = "Rebuild levels"
	ok_button_text = "Rebuild"
	min_size = Vector2i(460, 0)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	add_child(page)
	var lead := Label.new()
	lead.text = ("A re-run rewrites the level scene, its door and every prop "
		+ "scene in it, from tools/biomes/<level>.gd.")
	lead.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lead.custom_minimum_size.x = 440
	page.add_child(lead)
	# The chain, in chain order, numbered the way a run walks it - so the list
	# doubles as the answer to "what is after what".
	var grid := GridContainer.new()
	grid.columns = 2
	page.add_child(grid)
	for i in Biomes.CHAIN.size():
		var level: String = Biomes.CHAIN[i]
		var box := CheckBox.new()
		box.text = "%2d. %s" % [i + 1, level]
		box.tooltip_text = Biomes.BIOMES[level].get("title", level)
		box.toggled.connect(func(_on: bool) -> void: _refresh())
		grid.add_child(box)
		_boxes[level] = box
	var buttons := HBoxContainer.new()
	page.add_child(buttons)
	for entry: Array in [["All", true], ["None", false]]:
		var button := Button.new()
		button.text = entry[0]
		var on: bool = entry[1]
		button.pressed.connect(func() -> void: _set_all(on))
		buttons.add_child(button)
	_neighbours = CheckBox.new()
	_neighbours.text = "Include neighbours (door targets are baked in)"
	_neighbours.button_pressed = true
	_neighbours.toggled.connect(func(_on: bool) -> void: _refresh())
	page.add_child(_neighbours)
	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.custom_minimum_size.x = 440
	page.add_child(_summary)
	_refresh()


## The levels to name after `--`, in chain order. Order does not change what
## gets built, but it makes the summary and the command read like the floor
## plan rather than like click order.
func selection() -> PackedStringArray:
	var picked: Array[String] = []
	for level: String in Biomes.CHAIN:
		if _boxes[level].button_pressed:
			picked.append(level)
	if _neighbours != null and _neighbours.button_pressed:
		for level: String in picked.duplicate():
			for side: String in [Biomes.previous_of(level), Biomes.next_of(level)]:
				if side != "" and not picked.has(side):
					picked.append(side)
	var out := PackedStringArray()
	for level: String in Biomes.CHAIN:
		if picked.has(level):
			out.append(level)
	return out


func _set_all(on: bool) -> void:
	for level: String in _boxes:
		_boxes[level].button_pressed = on
	_refresh()


func _refresh() -> void:
	var out := selection()
	_summary.text = ("Nothing selected." if out.is_empty()
		else "Will build %d: %s" % [out.size(), " ".join(out)])
	get_ok_button().disabled = out.is_empty()
