extends Button
## One game in the lobby's list (join_view.gd): the host's character, their
## name, the seats as pips, their time zone and the game's STATUS - drawn in the
## seats' own colours, as the join screen of the Open Games preview has it.
##
## It is told a row of the signaling service's listing and draws it; it never
## asks Net anything. A game nobody can join (FULL, PLAYING) is a DISABLED
## button: it can still be picked, so the line under the list can say why not,
## but pressing it is no press - the menu does not chime at a key that did
## nothing (autoload/ui_sound.gd).

const Roster := preload("res://game/player/characters/roster.gd")

const SIZE := Vector2(576, 28)
const WALK_FPS := 8.0
const SURFACE := Color("3a3941")
const RAISED := Color("45434c")
const BORDER := Color("674949")
const ACCENT := Color("6eb39d")
const WARM := Color("ec773d")
const MID := Color("e8b84a")
const TEXT := Color("fff8e1")
const DIM := Color("987a68")
const BG := Color("1b1119")
## The status word and its colour: what can be joined is the accent, what wants
## a code is the warning amber, what cannot be joined is dim.
const STATUS := {
	"open": ["OPEN", ACCENT],
	"private": ["PRIVATE", MID],
	"full": ["FULL", DIM],
	"playing": ["PLAYING", DIM],
}
## Where each column starts, in the row's own pixels.
const NAME_X := 42
const PIPS_X := 268
const COUNT_X := 308
const ZONE_X := 372
const STATUS_W := 84

## The listing row this draws: {id, host, character, players, max, zone, status}.
var room := {}
var _frames: SpriteFrames = null
var _walk := 0
var _clock := 0.0

var _sprite: TextureRect
var _name: Label
var _count: Label
var _zone: Label
var _status: Label


func _init() -> void:
	custom_minimum_size = SIZE
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	var idle := _box(SURFACE, BORDER, 1)
	for state in [&"normal", &"hover", &"pressed", &"disabled"]:
		add_theme_stylebox_override(state, idle)
	add_theme_stylebox_override(&"focus", _box(RAISED, WARM, 2))
	_sprite = TextureRect.new()
	_sprite.position = Vector2(4, -4)
	_sprite.size = Vector2(32, 32)
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sprite)
	_name = _label("Host", NAME_X, PIPS_X - NAME_X - 8, false)
	_count = _label("Count", COUNT_X, 40, true)
	_zone = _label("Zone", ZONE_X, 80, true)
	_status = _label("Status", SIZE.x - STATUS_W - 8, STATUS_W, true)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func show_room(row: Dictionary, my_zone: int) -> void:
	room = row
	var shut := not joinable() and status() != "private"
	disabled = shut
	_name.text = String(row.get("host", "")).to_upper()
	_name.add_theme_color_override(&"font_color", DIM if shut else TEXT)
	var path := Roster.frames_path(String(row.get("character", "")))
	_frames = load(path if path != "" else Roster.frames_path(Roster.DEFAULT_ID))
	_walk = 0
	_sprite.texture = _frames.get_frame_texture("idle_down", 0) if _frames != null else null
	_sprite.modulate = Color(1, 1, 1, 0.45) if shut else Color.WHITE
	_count.text = "%d/%d" % [int(row.get("players", 0)), int(row.get("max", 0))]
	var zone := int(row.get("zone", 0))
	_zone.text = zone_text(zone)
	_zone.add_theme_color_override(&"font_color",
		TEXT if not shut and absi(zone - my_zone) <= 60 else DIM)
	var word: Array = STATUS.get(status(), ["?", DIM])
	_status.text = word[0]
	_status.add_theme_color_override(&"font_color", word[1])
	queue_redraw()


func status() -> String:
	return String(room.get("status", ""))


## Enter joins it as it stands, with no code to ask for.
func joinable() -> bool:
	return status() == "open"


## "UTC", "UTC+3", "UTC-5", "UTC+5:30" - minutes east of UTC, as the host's
## clock gave them.
static func zone_text(minutes: int) -> String:
	if minutes == 0:
		return "UTC"
	var whole := absi(minutes)
	var text := "UTC%s%d" % ["+" if minutes > 0 else "-", whole / 60]
	if whole % 60 != 0:
		text += ":%02d" % (whole % 60)
	return text


## The picked row's host walks, like the picked portrait on the character
## select and this machine's own seat in the room.
func _process(delta: float) -> void:
	if _frames == null or disabled or not has_focus():
		if _walk != 0 and _frames != null:
			_walk = 0
			_sprite.texture = _frames.get_frame_texture("idle_down", 0)
		return
	_clock += delta
	if _clock < 1.0 / WALK_FPS:
		return
	_clock = 0.0
	_walk = (_walk + 1) % _frames.get_frame_count("walk_down")
	_sprite.texture = _frames.get_frame_texture("walk_down", _walk)


## The pips - a filled one per player, an empty one per open seat - and the
## status word's frame. Whole pixels: filled rects, never lines.
func _draw() -> void:
	var shut := disabled
	var players := int(room.get("players", 0))
	for i in int(room.get("max", 0)):
		var at := Rect2(PIPS_X + i * 9, (SIZE.y - 6) / 2, 6, 6)
		if i < players:
			draw_rect(at, DIM if shut else ACCENT)
		else:
			draw_rect(at, BORDER)
			draw_rect(at.grow(-1), BG)
	var word: Array = STATUS.get(status(), ["?", DIM])
	var frame := Rect2(SIZE.x - STATUS_W - 8, (SIZE.y - 16) / 2, STATUS_W, 16)
	draw_rect(frame, word[1])
	draw_rect(frame.grow(-1), BG)


func _label(node_name: String, x: float, width: float, small: bool) -> Label:
	var label := Label.new()
	label.name = node_name
	label.theme_type_variation = &"Footer" if small else &""
	label.position = Vector2(x, 0)
	label.size = Vector2(width, SIZE.y)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


static func _box(fill: Color, edge: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(width)
	box.set_content_margin_all(0)
	return box
