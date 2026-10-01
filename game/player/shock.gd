extends Node2D
## ELECTRIFIED - every body the arc touched stays lit for half a second, so the
## player can see who the chain went through after the bolt itself is gone.
##
## Drawn as the body's own current frame in solid spark colour at four
## one-pixel offsets BEHIND it, flickering at 30 Hz, which reads as an outline
## crackling round the figure. The silhouette is a two-line shader rather than
## a sheet, because it has to follow whatever frame the body happens to be on -
## a wind-up, a walk, a 64 px body - and only the body's own sprite knows that.
##
## A child of the body, moved to the front of its children so it draws under
## the sprite. Nothing in enemy_base knows it is there; it finds the sprite by
## the name every enemy scene gives it. Frees itself.

const NAME := "Shock"
const SECONDS := 0.5
const FLICKER_HZ := 30.0
const OFFSETS: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]

const SILHOUETTE := """
shader_type canvas_item;
uniform vec4 tint : source_color;
void fragment() {
	COLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * tint.a);
}
"""

static var _shader: Shader = null

var colour := Color.WHITE
var _sprite: AnimatedSprite2D = null
var _left := SECONDS
var _time := 0.0


## Lights `body` up, or restarts the clock on one already lit.
static func apply(body: Node2D, spark: Color) -> void:
	var node := body.get_node_or_null(NAME)
	if node == null or node.is_queued_for_deletion():
		node = (load("res://game/player/shock.gd") as GDScript).new()
		node.name = NAME
		node.colour = spark
		body.add_child(node)
		body.move_child(node, 0)
	node._left = SECONDS


func _ready() -> void:
	_sprite = get_parent().get_node_or_null("AnimatedSprite2D")
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SILHOUETTE
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("tint", Color(colour, 0.9))
	material = mat


func _process(delta: float) -> void:
	_time += delta
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if int(_time * FLICKER_HZ) % 2 == 1:
		return
	var tex := _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
	if tex == null:
		return
	var size := tex.get_size()
	var corner := _sprite.position + _sprite.offset - size / 2.0
	if not _sprite.centered:
		corner = _sprite.position + _sprite.offset
	for off in OFFSETS:
		var at := (corner + off).round()
		# A flipped body is drawn mirrored about its own centre, exactly as the
		# AnimatedSprite2D mirrors it.
		if _sprite.flip_h:
			draw_set_transform(at + Vector2(size.x, 0), 0.0, Vector2(-1, 1))
			draw_texture(tex, Vector2.ZERO)
		else:
			draw_set_transform(Vector2.ZERO)
			draw_texture(tex, at)
	draw_set_transform(Vector2.ZERO)
