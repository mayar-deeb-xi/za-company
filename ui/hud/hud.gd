extends Control
## In-game HUD, instanced once by game.tscn. One health bar for now; anything
## else the game grows on screen (keys, score, boss bars) joins it here rather
## than as loose nodes in game.tscn.
##
## Deliberately dumb: it renders whatever game.gd feeds it and never reaches
## for the player itself, so it keeps working when the thing with health is a
## different node - or when a second bar shows someone else's.
##
## Sized in design pixels against the 640x360 viewport: 66px of fill inside a
## 1px border, tucked into the top-left corner.
##
## The boss bar is its own scene under the same folder and this script only
## forwards to it, so game.gd still has one thing to talk to and neither bar
## has to know the other exists.
##
## **The rest of the party is a row each under the hearts** - a small bar and a
## name - built by `set_party()` from whatever game.gd hands it. The big bar is
## always THIS machine's player and the hearts are the party's one pool, so a
## party of one is given no rows and the HUD is exactly what it always was.

const FILL_WIDTH := 66.0
## A party row: where the first one sits, how far apart they are, and the width
## of the fill inside its 1px border.
const ROW_TOP := 33.0
const ROW_STEP := 9.0
const ROW_FILL := 40.0
const BORDER := Color(0.0784314, 0.0862745, 0.109804, 1)
const BACK := Color(0.168627, 0.027451, 0.0509804, 1)
const FILL := Color(0.847059, 0.196078, 0.235294, 1)
const TEXT := Color(0.937255, 0.941176, 0.960784, 1)
## A row whose player is down: still listed, so nobody wonders where they went.
const DOWN_ALPHA := 0.4
const FONT := preload("res://assets/fonts/KenneyPixel.ttf")

## Preloaded rather than reached for by class_name, like every other typed
## node in the game: global class names live in an editor-written cache.
const BossBarType := preload("res://ui/hud/boss_bar.gd")

## Same 9x8 mask as the heal pickup in tools/build_biomes.gd, kept in step by
## hand. Drawn at runtime rather than generated to a .tres: the HUD is not
## biome art, and two 9x8 sprites are not worth a generator of their own.
const HEART := [
	".XX...XX.",
	"XXXX.XXXX",
	"XXXXXXXXX",
	"XXXXXXXXX",
	".XXXXXXX.",
	"..XXXXX..",
	"...XXX...",
	"....X....",
]

@onready var _fill: ColorRect = %Fill
@onready var _percent: Label = %Percent
@onready var _hearts: HBoxContainer = %Hearts
@onready var _boss_bar: BossBarType = %BossBar

@onready var _heart_full := _heart_texture(true)
@onready var _heart_empty := _heart_texture(false)

## One Control per party row, in slot order; its fill is the child named Fill.
var _rows: Array[Control] = []


## The rest of the party, one row per name, in the order game.gd keeps them.
## Rebuilt whole rather than patched, because it is asked once per run.
func set_party(names: Array) -> void:
	for row in _rows:
		row.queue_free()
	_rows.clear()
	for i in names.size():
		_rows.append(_party_row(i, String(names[i])))


func set_member_health(slot: int, health: int, max_health: int) -> void:
	if slot < 0 or slot >= _rows.size():
		return
	var fill := _rows[slot].get_node("Fill") as ColorRect
	fill.size.x = roundf(ROW_FILL * float(health) / float(max_health))


func set_member_down(slot: int, down: bool) -> void:
	if slot < 0 or slot >= _rows.size():
		return
	_rows[slot].modulate.a = DOWN_ALPHA if down else 1.0


## The party rows, for tests: one Control each, in slot order.
func party_rows() -> Array[Control]:
	return _rows


func set_health(health: int, max_health: int) -> void:
	var ratio := float(health) / float(max_health)
	_fill.size = Vector2(roundf(FILL_WIDTH * ratio), _fill.size.y)
	_percent.text = "%d%%" % roundi(ratio * 100.0)


## One icon per possible life, full for the ones still held, a dark slot for
## the ones spent - so losing a life reads as a change, not a disappearance.
func set_lives(lives: int, max_lives: int) -> void:
	while _hearts.get_child_count() < max_lives:
		var icon := TextureRect.new()
		icon.stretch_mode = TextureRect.STRETCH_KEEP
		_hearts.add_child(icon)
	for i in _hearts.get_child_count():
		var icon := _hearts.get_child(i) as TextureRect
		icon.visible = i < max_lives
		icon.texture = _heart_full if i < lives else _heart_empty


## The boss bar, up only on a floor that has one. Three calls rather than
## one that means different things: game.gd names him once on arrival, then
## his own health_changed drives set_boss_health straight through.
func set_boss(title: String, health: int, max_health: int) -> void:
	_boss_bar.show_boss(title, health, max_health)


func set_boss_health(health: int, max_health: int) -> void:
	_boss_bar.set_health(health, max_health)


func clear_boss() -> void:
	_boss_bar.hide_boss()


## A small bar in a 1px border with a name beside it - the big bar's colours
## and font at a party member's size.
func _party_row(slot: int, label: String) -> Control:
	var row := Control.new()
	row.name = "Member%d" % (slot + 1)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.position = Vector2(8.0, ROW_TOP + ROW_STEP * slot)
	add_child(row)
	for part in [["Border", Vector2.ZERO, Vector2(ROW_FILL + 2.0, 6.0), BORDER],
			["Back", Vector2.ONE, Vector2(ROW_FILL, 4.0), BACK],
			["Fill", Vector2.ONE, Vector2(ROW_FILL, 4.0), FILL]]:
		var rect := ColorRect.new()
		rect.name = part[0]
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.position = part[1]
		rect.size = part[2]
		rect.color = part[3]
		row.add_child(rect)
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = label
	name_label.position = Vector2(ROW_FILL + 6.0, -2.0)
	name_label.size = Vector2(80.0, 10.0)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", FONT)
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", TEXT)
	name_label.add_theme_color_override("font_shadow_color", BORDER)
	name_label.add_theme_constant_override("shadow_offset_x", 1)
	name_label.add_theme_constant_override("shadow_offset_y", 1)
	row.add_child(name_label)
	return row


func _heart_texture(full: bool) -> Texture2D:
	var w: int = HEART[0].length()
	var img := Image.create(w, HEART.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in HEART.size():
		for x in w:
			if HEART[y][x] != "X":
				continue
			var c := Color("32363f")
			if full:
				c = Color("c8283c")
				if y <= 1:
					c = Color("e0465a")
				elif y >= 5:
					c = Color("8c1626")
			img.set_pixel(x, y, c)
	if full:
		img.set_pixel(2, 1, Color("f2a0aa"))
	return ImageTexture.create_from_image(img)
