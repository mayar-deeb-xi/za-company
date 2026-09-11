extends Node2D
## Silverman's dash trail, drawn live rather than baked into the sheet -
## the same arrangement as Ahmed's axe_fire.gd, for the same reason: the sheet
## stays a clean body you can hand-draw into, and the effect follows whatever
## is on it.
##
## The dash is THE SMEAR: seven copies of him six pixels apart, each one step
## down the ramp and fading back, so they overlap into one continuous length of
## metal with the real Silverman at the bright end of it. That is the whole
## trick of this boss's movement - his body never stretches, squashes or leans
## (see poses.gd), and all the speed is in what he leaves behind.
##
## Six apart rather than fourteen is deliberate and is what makes it a smear
## instead of three afterimages: at 6 px the copies overlap, and what the eye
## gets is a band rather than a count.
##
## Nothing tells this node anything. It reads the boss for whether he is
## travelling and the sprite for which way he is facing, and it takes the
## dulled picture straight off the sheet's `ghost` row - a row the boss never
## plays, which exists so the trail is painted in the palette's own values
## instead of a modulate landing between two of them.

## Offset behind him in world px, and how much of him is left there. Verbatim
## from the approved mockup; the ramp is linear-ish rather than exponential so
## the far end of the band does not vanish before it reaches its length.
const GHOSTS := [
	{"back": 6.0, "alpha": 0.30},
	{"back": 12.0, "alpha": 0.25},
	{"back": 18.0, "alpha": 0.21},
	{"back": 24.0, "alpha": 0.17},
	{"back": 30.0, "alpha": 0.13},
	{"back": 36.0, "alpha": 0.09},
	{"back": 42.0, "alpha": 0.06},
]

## The sheet row holding the dulled body. Never played by the boss.
const GHOST_ANIM := "ghost_side"

var _boss: Node2D
var _sprite: AnimatedSprite2D


func _ready() -> void:
	_boss = get_parent() as Node2D
	_sprite = _boss.get_node("AnimatedSprite2D") as AnimatedSprite2D


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	# Only while he is actually crossing: the coil, the arrival and the settle
	# are all standing still, and a trail on a standing boss reads as a bug.
	if _sprite == null or not _boss.dash_moving:
		return
	var frames := _sprite.sprite_frames
	if frames == null or not frames.has_animation(GHOST_ANIM):
		return
	var tex := frames.get_frame_texture(GHOST_ANIM, 0)
	if tex == null:
		return

	# He travels the way he faces, so the trail goes the other way. The copies
	# are mirrored exactly as the sprite is - flip_h on an AnimatedSprite2D
	# mirrors about its offset, and this offset's x is zero, so mirroring about
	# the boss's own origin is the same transform.
	var facing := -1.0 if _sprite.flip_h else 1.0
	var size := tex.get_size()
	var corner := Vector2(-size.x * 0.5, _sprite.offset.y - size.y * 0.5)
	for ghost in GHOSTS:
		draw_set_transform(Vector2(-facing * ghost["back"], 0.0), 0.0,
			Vector2(facing, 1.0))
		draw_texture(tex, corner, Color(1.0, 1.0, 1.0, ghost["alpha"]))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
