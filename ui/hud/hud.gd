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

const FILL_WIDTH := 66.0

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
