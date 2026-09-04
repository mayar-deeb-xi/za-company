extends SceneTree
## Regenerates res://ui/theme/menu_theme.tres.
## Run: godot --headless --path . --script res://tools/build_ui_theme.gd
##
## Every colour here was sampled from the actual sprite art (see CREDITS.md), so
## the menu and the game read as one thing:
##   #6eb39d  the character's shirt      -> accent
##   #ec773d  torchlight in the tileset  -> focus / highlight
##   #fff8e1  the sword's swing arc      -> text
##   #674949  dungeon brick shadow       -> borders

const OUT := "res://ui/theme/menu_theme.tres"

const BG_DEEP := Color("1b1119")
const SURFACE := Color("3a3941")
const SURFACE_HI := Color("674949")
const BORDER := Color("674949")
const ACCENT := Color("6eb39d")
const ACCENT_WARM := Color("ec773d")
const TEXT := Color("fff8e1")
const TEXT_DIM := Color("987a68")


func _flat(bg: Color, border: Color, border_w: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	# Square corners: rounded ones fight a pixel grid.
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	return sb


func _initialize() -> void:
	var blocks := load("res://assets/fonts/KenneyBlocks.ttf") as FontFile
	var mini := load("res://assets/fonts/KenneyMiniSquare.ttf") as FontFile
	if blocks == null or mini == null:
		printerr("fonts not imported yet - run with --editor --quit first")
		quit(1)
		return

	var theme := Theme.new()
	theme.default_font = mini
	theme.default_font_size = 16

	# ---- Button ----------------------------------------------------------
	var normal := _flat(SURFACE, BORDER)
	var hover := _flat(SURFACE_HI, ACCENT)
	var pressed := _flat(BG_DEEP, ACCENT)
	# Nudge the label down a pixel so a press feels physical.
	pressed.content_margin_top = 8
	pressed.content_margin_bottom = 6
	var focus := _flat(Color(0, 0, 0, 0), ACCENT_WARM)
	var disabled := _flat(SURFACE.darkened(0.3), BORDER.darkened(0.3))

	theme.set_font("font", "Button", mini)
	theme.set_font_size("font_size", "Button", 20)
	theme.set_color("font_color", "Button", TEXT_DIM)
	theme.set_color("font_hover_color", "Button", TEXT)
	theme.set_color("font_pressed_color", "Button", ACCENT)
	theme.set_color("font_focus_color", "Button", TEXT)
	theme.set_color("font_disabled_color", "Button", TEXT_DIM.darkened(0.4))
	for pair in [["normal", normal], ["hover", hover], ["pressed", pressed],
			["focus", focus], ["disabled", disabled]]:
		theme.set_stylebox(pair[0], "Button", pair[1])

	# ---- Label + type variations ----------------------------------------
	theme.set_font("font", "Label", mini)
	theme.set_font_size("font_size", "Label", 16)
	theme.set_color("font_color", "Label", TEXT_DIM)

	theme.set_type_variation("Title", "Label")
	theme.set_font("font", "Title", blocks)
	theme.set_font_size("font_size", "Title", 48)
	theme.set_color("font_color", "Title", TEXT)
	theme.set_color("font_shadow_color", "Title", BG_DEEP)
	theme.set_constant("shadow_offset_x", "Title", 0)
	theme.set_constant("shadow_offset_y", "Title", 4)

	theme.set_type_variation("Tagline", "Label")
	theme.set_font("font", "Tagline", mini)
	theme.set_font_size("font_size", "Tagline", 16)
	theme.set_color("font_color", "Tagline", ACCENT)

	theme.set_type_variation("Footer", "Label")
	theme.set_font("font", "Footer", mini)
	theme.set_font_size("font_size", "Footer", 12)
	theme.set_color("font_color", "Footer", TEXT_DIM.darkened(0.2))

	# ---- Pause panel -----------------------------------------------------
	# Slightly translucent so the paused game stays faintly visible behind it.
	var pause_panel := _flat(Color(BG_DEEP, 0.96), ACCENT)
	pause_panel.content_margin_left = 28
	pause_panel.content_margin_right = 28
	pause_panel.content_margin_top = 20
	pause_panel.content_margin_bottom = 20
	theme.set_stylebox("panel", "PanelContainer", pause_panel)

	theme.set_type_variation("Heading", "Label")
	theme.set_font("font", "Heading", blocks)
	theme.set_font_size("font_size", "Heading", 28)
	theme.set_color("font_color", "Heading", TEXT)
	theme.set_color("font_shadow_color", "Heading", BG_DEEP)
	theme.set_constant("shadow_offset_x", "Heading", 0)
	theme.set_constant("shadow_offset_y", "Heading", 3)

	# ---- Settings controls -----------------------------------------------
	# OptionButton inherits Button's styleboxes through the theme's class
	# fallback, but the popup it opens is a separate control and stays stock
	# grey unless it is styled here too.
	theme.set_font("font", "OptionButton", mini)
	theme.set_font_size("font_size", "OptionButton", 16)
	theme.set_constant("arrow_margin", "OptionButton", 6)

	var popup := _flat(SURFACE.darkened(0.35), ACCENT)
	popup.content_margin_left = 6
	popup.content_margin_right = 6
	popup.content_margin_top = 6
	popup.content_margin_bottom = 6
	theme.set_stylebox("panel", "PopupMenu", popup)
	theme.set_stylebox("hover", "PopupMenu", _flat(SURFACE_HI, SURFACE_HI, 0))
	theme.set_font("font", "PopupMenu", mini)
	theme.set_font_size("font_size", "PopupMenu", 16)
	theme.set_color("font_color", "PopupMenu", TEXT_DIM)
	theme.set_color("font_hover_color", "PopupMenu", TEXT)
	theme.set_color("font_separator_color", "PopupMenu", BORDER)
	theme.set_constant("v_separation", "PopupMenu", 6)

	# Row labels sit beside their control, so they read quieter than a heading
	# but brighter than the footer.
	theme.set_type_variation("SettingLabel", "Label")
	theme.set_font("font", "SettingLabel", mini)
	theme.set_font_size("font_size", "SettingLabel", 16)
	theme.set_color("font_color", "SettingLabel", TEXT)

	# ---- Quit dialog -----------------------------------------------------
	var panel := _flat(SURFACE.darkened(0.35), BORDER)
	panel.content_margin_left = 20
	panel.content_margin_right = 20
	panel.content_margin_top = 16
	panel.content_margin_bottom = 16
	theme.set_stylebox("panel", "AcceptDialog", panel)
	theme.set_stylebox("embedded_border", "Window", _flat(SURFACE.darkened(0.35), ACCENT))
	theme.set_font("title_font", "Window", mini)
	theme.set_font_size("title_font_size", "Window", 16)
	theme.set_color("title_color", "Window", TEXT)
	theme.set_constant("title_height", "Window", 28)

	var err := ResourceSaver.save(theme, OUT)
	print("saved ", OUT, " -> ", error_string(err))

	# Size the dialog against real measured text rather than a guess.
	var q := "Really quit?"
	print("dialog text '%s' measures %.0f px at MiniSquare 16"
		% [q, mini.get_string_size(q, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x])
	print("title measures %.0f px at Blocks 48"
		% blocks.get_string_size("ZA COMPANY", HORIZONTAL_ALIGNMENT_LEFT, -1, 48).x)
	print("heading 'PAUSED' measures %.0f px at Blocks 28"
		% blocks.get_string_size("PAUSED", HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x)
	print("button label 'PLAY' measures %.0f px at MiniSquare 20"
		% mini.get_string_size("PLAY", HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x)
	quit(0 if err == OK else 1)
