extends SceneTree
## Regenerates res://icon.svg - the project icon: the new hire, open to work.
## Run: godot --headless --path . --script res://tools/build_icon.gd
##
## The default character's real idle frame as a head-and-shoulders portrait in
## a round frame, with a green band round the lower left lettered #OPENTOWORK,
## after LinkedIn's frame - the first-day joke the whole game is. Picked from a
## preview and shipped as previewed: this is the code that drew it.
##
## 64 x 64 rather than 32, so the band and its letters get a finer grid than
## the sprite, which is drawn at 4x. Written as one crisp rect per run of one
## colour at 128 x 128, the size Godot expects of icon.svg, so it is sharp at
## any size the OS asks for. The colours are the menu theme's
## (build_ui_theme.gd) plus the band's own two greens.

const OUT := "res://icon.svg"
## The boot splash takes only a PNG ("the only supported format"), so the same
## painted image is written again for it, enlarged with no filtering by a whole
## 4 - which is also exactly the size the web build's loading page shows it at
## (export_presets.cfg's `html/head_include`).
const SPLASH := "res://splash.png"
const SPLASH_SCALE := 4
const Roster := preload("res://game/player/characters/roster.gd")
const Brush := preload("res://tools/props/_brush.gd")

const N := 64
const C := Vector2(32, 32)
const BG_DEEP := Color("1b1119")
const BORDER := Color("674949")
const TEXT := Color("fff8e1")
const GREEN := Color("57a64a")
const GREEN_DARK := Color("3b7a33")

## The band: its outer edge is the disc's, and it is THICK at the bottom-left
## and tapers to nothing at both ends, the way the real frame does.
const BAND_OUT := 31.5
const BAND_IN := 22.0
const BAND_FROM := 236.0   # degrees, y down: 180 is 9 o'clock, 90 is 6
const BAND_TO := 30.0
const TAPER := 24.0        # degrees over which each end thins out

const WORDS := "#OPENTOWORK"
## The props' font has no #, so it is drawn here on the same 5 x 5 grid.
const HASH := [".X.X.", "XXXXX", ".X.X.", "XXXXX", ".X.X."]


func _initialize() -> void:
	var img := _paint()
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(svg(img))
	f.close()
	print("wrote ", OUT)
	img.resize(N * SPLASH_SCALE, N * SPLASH_SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png(SPLASH)
	print("wrote ", SPLASH)
	quit()


func _paint() -> Image:
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# The disc, and its rim where the band is not.
	for y in N:
		for x in N:
			var d := (Vector2(x, y) + Vector2(0.5, 0.5)).distance_to(C)
			if d <= BAND_OUT:
				img.set_pixel(x, y, BORDER if d > BAND_OUT - 1.0 else BG_DEEP)
	# The portrait: the default character's idle frame at 4x, head and
	# shoulders, kept inside the disc.
	var sprite := _frame("idle_down", 0)
	var used := sprite.get_used_rect()
	var at := Vector2i((N - used.size.x * 4) / 2, 7)
	for sy in 14:
		for sx in used.size.x:
			var c := sprite.get_pixel(used.position.x + sx, used.position.y + sy)
			if c.a < 0.5:
				continue
			for yy in 4:
				for xx in 4:
					var p := at + Vector2i(sx * 4 + xx, sy * 4 + yy)
					var d := (Vector2(p) + Vector2(0.5, 0.5)).distance_to(C)
					if d <= BAND_OUT - 1.0 and p.y < N:
						img.set_pixelv(p, c)
	# The band.
	for y in N:
		for x in N:
			var v := Vector2(x, y) + Vector2(0.5, 0.5) - C
			var d := v.length()
			var a := _deg(v)
			var inner := _inner(a)
			if inner < 0.0 or d > BAND_OUT or d < inner:
				continue
			var edge := d < inner + 1.0 or d > BAND_OUT - 1.0
			img.set_pixel(x, y, GREEN_DARK if edge else GREEN)
	_letter(img)
	return img


## The band's inner radius at angle `a`, or -1 outside it. Full thickness in
## the middle, easing to zero over TAPER degrees at each end.
func _inner(a: float) -> float:
	var span := _span(a)
	if span < 0.0:
		return -1.0
	var total := _span(BAND_TO)
	var from_end := minf(span, total - span)
	var t := clampf(from_end / TAPER, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	return lerpf(BAND_OUT, BAND_IN, t)


## Degrees travelled from BAND_FROM towards BAND_TO (decreasing angle), or -1
## if `a` is not on that stretch.
func _span(a: float) -> float:
	var s := fposmod(BAND_FROM - a, 360.0)
	return s if s <= fposmod(BAND_FROM - BAND_TO, 360.0) else -1.0


func _deg(v: Vector2) -> float:
	return fposmod(rad_to_deg(atan2(v.y, v.x)), 360.0)


## #OPENTOWORK round the band in the props' own 5 x 5 font, tops of the
## letters towards the middle, read from the left side down and round, the
## way the real frame reads. Each letter is a RIGID square turned to the
## curve, not bent along it - bending squeezes the inner row and stretches the
## outer one, which is what turned W into H - and is sampled 4 x 4 per pixel
## so a stroke at an angle keeps its weight.
func _letter(img: Image) -> void:
	var radius := 26.75   # the text's centre line
	var advance := float(Brush.GLYPH_ADVANCE)
	var length := WORDS.length() * advance - 1.0
	var mid := deg_to_rad(fposmod(BAND_FROM - _span(BAND_TO) / 2.0, 360.0))
	var start := mid + (length / 2.0) / radius
	var ink := {}
	for gi in WORDS.length():
		var ch := WORDS[gi]
		var rows: Array = HASH if ch == "#" else Brush.FONT[ch]
		# The glyph's centre along the arc, and its frame there: `along` is
		# the reading direction, `down` points out of the circle.
		var ang := start - (gi * advance + 2.5) / radius
		var centre := C + Vector2(cos(ang), sin(ang)) * radius
		var down := Vector2(cos(ang), sin(ang))
		var along := Vector2(sin(ang), -cos(ang))
		for y in range(int(centre.y) - 5, int(centre.y) + 6):
			for x in range(int(centre.x) - 5, int(centre.x) + 6):
				var hits := 0
				for sy in 4:
					for sx in 4:
						var v := Vector2(x + (sx + 0.5) / 4.0, y + (sy + 0.5) / 4.0) - centre
						var gx := floori(v.dot(along) + 2.5)
						var gy := floori(v.dot(down) + 2.5)
						if gx >= 0 and gx < 5 and gy >= 0 and gy < 5 and rows[gy][gx] == "X":
							hits += 1
				if hits >= 7:
					ink[Vector2i(x, y)] = true
	for p in ink:
		img.set_pixelv(p, TEXT)


func _frame(anim: String, i: int) -> Image:
	var sf := load(Roster.frames_path(Roster.DEFAULT_ID)) as SpriteFrames
	var img := sf.get_frame_texture(anim, i).get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


## Crisp rects, one per horizontal run of one colour, 128 x 128 like the
## icon.svg Godot expects.
static func svg(img: Image) -> String:
	var s := '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 %d %d" shape-rendering="crispEdges">' % [img.get_width(), img.get_height()]
	for y in img.get_height():
		var x := 0
		while x < img.get_width():
			var c := img.get_pixel(x, y)
			var run := 1
			while x + run < img.get_width() and img.get_pixel(x + run, y) == c:
				run += 1
			if c.a > 0.0:
				s += '<rect x="%d" y="%d" width="%d" height="1" fill="#%s"/>' % [x, y, run, c.to_html(false)]
			x += run
	return s + "</svg>\n"
