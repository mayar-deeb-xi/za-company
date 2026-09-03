extends SceneTree
## Regenerates res://game/player/player_frames.tres from the source sheet.
## Run: godot --headless --path . --script res://tools/build_player_frames.gd

const SHEET := "res://game/player/character.png"
const OUT := "res://game/player/player_frames.tres"
const FRAME := 32

# Row indices in character.png, verified against the sheet.
# The sheet only draws a right-facing profile; "side" is flipped for left.
const LAYOUT := {
	"down": {"idle": 0, "walk": 1, "attack": 6},
	"up": {"idle": 2, "walk": 3, "attack": 7},
	"side": {"idle": 4, "walk": 5, "attack": 8},
}

const SPECS := {
	"idle": {"frames": 1, "fps": 1.0, "loop": true},
	"walk": {"frames": 4, "fps": 10.0, "loop": true},
	"attack": {"frames": 4, "fps": 14.0, "loop": false},
}


func _initialize() -> void:
	var tex := load(SHEET) as Texture2D
	if tex == null:
		printerr("Could not load ", SHEET, " - run once more so Godot imports it first.")
		quit(1)
		return

	var sf := SpriteFrames.new()
	sf.remove_animation("default")

	for dir_name in LAYOUT:
		for state in SPECS:
			var anim := "%s_%s" % [state, dir_name]
			var spec: Dictionary = SPECS[state]
			sf.add_animation(anim)
			sf.set_animation_speed(anim, spec["fps"])
			sf.set_animation_loop(anim, spec["loop"])
			for col in spec["frames"]:
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2(col * FRAME, LAYOUT[dir_name][state] * FRAME, FRAME, FRAME)
				sf.add_frame(anim, at)

	var err := ResourceSaver.save(sf, OUT)
	print("saved ", OUT, " -> ", error_string(err))
	print("animations: ", ", ".join(sf.get_animation_names()))

	_report_bounds()
	quit(0 if err == OK else 1)


## Prints the tight pixel bounds of the drawn character so the collision shape
## and sprite offset can be placed on the body rather than the empty frame.
func _report_bounds() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SHEET))
	var union := Rect2i()
	var idle_down := Rect2i()
	for row in 9:
		for col in 4:
			var box := _content_bounds(img, col * FRAME, row * FRAME)
			if box.size == Vector2i.ZERO:
				continue
			union = box if union.size == Vector2i.ZERO else union.merge(box)
			if row == 0 and col == 0:
				idle_down = box
	print("idle_down content bounds within frame: ", idle_down)
	print("union of all frames:                   ", union)


func _content_bounds(img: Image, ox: int, oy: int) -> Rect2i:
	var min_x := FRAME
	var min_y := FRAME
	var max_x := -1
	var max_y := -1
	for y in FRAME:
		for x in FRAME:
			if img.get_pixel(ox + x, oy + y).a > 0.0:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < 0:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
