extends Control
## One seat in the lobby (ui/lobby/): a player's card in the character select's
## own dress - their sprite at 3x, their name, and how they are connected - or
## an OPEN seat, drawn dashed, which is how the lobby says how many more can
## come without a number. Picked as option A from the lobby preview.
##
## It is told what to show and draws it; it never asks Net anything, so the
## lobby stays the one place that reads the roster.

const Roster := preload("res://game/player/characters/roster.gd")

const SIZE := Vector2(128, 160)
const SPRITE_PX := 96
const WALK_FPS := 8.0
## The menu theme's colours (tools/build_ui_theme.gd), which a card draws with
## itself because a frame drawn dashed is not a stylebox.
const SURFACE := Color("3a3941")
const BORDER := Color("674949")
const ACCENT := Color("6eb39d")
const TEXT := Color("fff8e1")
const DIM := Color("987a68")
const BG := Color("1b1119")
## Somebody whose hello has not arrived yet has no character to show: a
## silhouette of the default body, so the seat is visibly taken and visibly
## not ready.
const SILHOUETTE := Color(0.15, 0.1, 0.15, 0.7)
## DESIGN.md's ping colours: green under 60 ms, amber under 120, red above.
const PING_GOOD := Color("6fdc6f")
const PING_MID := Color("e8b84a")
const PING_BAD := Color("e85a4a")

## Read by tests: "open", "connecting" or "player".
var kind := "open"
var _mine := false
var _frames: SpriteFrames = null
var _walk := 0
var _clock := 0.0

var _sprite: TextureRect
var _you: ColorRect
var _name: Label
var _line_1: Label
var _line_2: Label


func _init() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprite = TextureRect.new()
	_sprite.position = Vector2((SIZE.x - SPRITE_PX) / 2.0, 4)
	_sprite.size = Vector2(SPRITE_PX, SPRITE_PX)
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sprite)
	_name = _label(104, 16)
	_name.name = "Name"
	_line_1 = _label(124, 12)
	_line_1.name = "Line1"
	_line_2 = _label(140, 12)
	_line_2.name = "Line2"
	_you = ColorRect.new()
	_you.color = ACCENT
	_you.size = Vector2(34, 14)
	_you.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var you_text := Label.new()
	you_text.text = "YOU"
	you_text.theme_type_variation = &"Footer"
	you_text.add_theme_color_override(&"font_color", BG)
	you_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	you_text.size = _you.size
	you_text.position = Vector2(0, -1)
	_you.add_child(you_text)
	add_child(_you)
	show_open()


## Nobody here yet.
func show_open() -> void:
	kind = "open"
	_mine = false
	_frames = null
	_sprite.texture = null
	_you.visible = false
	_name.text = ""
	_line_1.text = "OPEN SEAT"
	_line_1.position.y = 70
	_line_1.add_theme_color_override(&"font_color", DIM)
	_line_2.text = ""
	queue_redraw()


## A row of Net's roster. `mine` is this machine's player, whose card walks.
func show_row(row: Dictionary, mine: bool) -> void:
	_mine = mine
	_you.visible = mine
	_name.text = String(row.get("name", "")).to_upper()
	_line_1.position.y = 124
	var character := String(row.get("character", ""))
	var route := String(row.get("route", ""))
	kind = "connecting" if route == "..." or character == "" else "player"
	var path := Roster.frames_path(character)
	_frames = load(path if path != "" else Roster.frames_path(Roster.DEFAULT_ID))
	_sprite.modulate = SILHOUETTE if kind == "connecting" else Color.WHITE
	_walk = 0
	_sprite.texture = _frames.get_frame_texture("idle_down", 0) if _frames != null else null
	if kind == "connecting":
		_set_line(_line_1, "CONNECTING...", DIM)
		_set_line(_line_2, "", DIM)
	elif route == "HOST":
		_set_line(_line_1, "HOST", ACCENT)
		_set_line(_line_2, "", DIM)
	else:
		var ping := int(row.get("ping", -1))
		_set_line(_line_1, "..." if ping < 0 else "%d MS" % ping, ping_colour(ping))
		_set_line(_line_2, route, PING_MID if route == "RELAY" else DIM)
	queue_redraw()


static func ping_colour(ms: int) -> Color:
	if ms < 0:
		return DIM
	if ms < 60:
		return PING_GOOD
	if ms < 120:
		return PING_MID
	return PING_BAD


func _process(delta: float) -> void:
	if not _mine or _frames == null or kind != "player":
		return
	_clock += delta
	if _clock < 1.0 / WALK_FPS:
		return
	_clock = 0.0
	_walk = (_walk + 1) % _frames.get_frame_count("walk_down")
	_sprite.texture = _frames.get_frame_texture("walk_down", _walk)


## Solid for a player - in the accent, two pixels wide, for this machine's -
## and dashed for an open seat. Whole pixels: filled rects, never lines.
func _draw() -> void:
	if kind == "open":
		for x in range(0, int(SIZE.x), 4):
			draw_rect(Rect2(x, 0, 2, 1), BORDER)
			draw_rect(Rect2(x, SIZE.y - 1, 2, 1), BORDER)
		for y in range(0, int(SIZE.y), 4):
			draw_rect(Rect2(0, y, 1, 2), BORDER)
			draw_rect(Rect2(SIZE.x - 1, y, 1, 2), BORDER)
		return
	var edge := 2 if _mine else 1
	draw_rect(Rect2(Vector2.ZERO, SIZE), ACCENT if _mine else BORDER)
	draw_rect(Rect2(Vector2(edge, edge), SIZE - Vector2(edge, edge) * 2), SURFACE)


func _label(y: float, font_size: int) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"Footer" if font_size == 12 else &""
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(4, y)
	label.size = Vector2(SIZE.x - 8, font_size + 4)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font_size == 16:
		label.add_theme_color_override(&"font_color", TEXT)
	add_child(label)
	return label


func _set_line(label: Label, text: String, colour: Color) -> void:
	label.text = text
	label.add_theme_color_override(&"font_color", colour)
