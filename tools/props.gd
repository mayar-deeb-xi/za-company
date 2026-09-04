extends RefCounted
## The front door to tools/props/ - the folder IS the catalogue.
##
## Every file in that folder except _brush.gd is one placeable prop type, named
## by its filename: `{"type": "desk"}` in a biome's props list resolves to
## tools/props/desk.gd, no registry in between. Adding a prop to the game is
## writing one new file there and giving it a position in tools/biomes.gd -
## nothing else changes, this file included.
##
## A prop file declares what the generators need to wrap it in a scene:
##
##   const SIZE   := Vector2i(...)   how big its art is
##   const BLOCKS := Vector2(...)    the box it blocks (ZERO = decor)
##   const PIN    := Vector2i(...)   optional: which pixel lands on the
##                                   placement position; defaults to
##                                   bottom-centre, which is what Y-sorting
##                                   reads. The banner pins its top-left
##                                   corner - the nail it hangs from.
##   static func paint(spec) -> Image   the picture, in the biome's palette
##
## column.gd, hazard.gd and heart.gd are FIXTURES, not catalogue props: a level
## places those itself, so they carry no SIZE or BLOCKS and known() is what
## keeps a biome from placing them like furniture. _brush.gd is the shared
## painting kit, kept out of the catalogue by its underscore.
##
## Editor-side only, like the rest of tools/: nothing under game/ loads this.

## Untyped on purpose: painters are dispatched by filename at runtime, and a
## typed GDScript var would make every .paint() a compile-time member lookup.
static func _painter(type: String):
	return load("res://tools/props/%s.gd" % type)


static func _const(type: String, key: String, fallback: Variant) -> Variant:
	return _painter(type).get_script_constant_map().get(key, fallback)


## A type is placeable when its file exists AND declares a SIZE - which is what
## excludes the fixtures and would exclude _brush.gd even without its underscore.
static func known(type: String) -> bool:
	if type.begins_with("_") \
			or not ResourceLoader.exists("res://tools/props/%s.gd" % type):
		return false
	return _painter(type).get_script_constant_map().has("SIZE")


static func size_of(type: String) -> Vector2i:
	return _const(type, "SIZE", Vector2i.ZERO)


static func blocks(type: String) -> Vector2:
	return _const(type, "BLOCKS", Vector2.ZERO)


## Offset from the placement position to the art's top-left corner - what the
## Sprite2D's position has to be for the prop to stand where the level put it.
static func offset(type: String) -> Vector2:
	var art := size_of(type)
	var pin: Vector2i = _const(type, "PIN", Vector2i(art.x / 2, art.y))
	return Vector2(-pin.x, -pin.y)


## The picture of a catalogue prop, painted in the biome's own palette.
static func paint(type: String, spec: Dictionary) -> Image:
	return _painter(type).paint(spec)


## The fixtures. Two of the three are per-biome STYLE choices keyed off the
## biome dictionary (`column`, `hazard`); every style keeps the same canvas and
## foot, so the scenes and collision boxes that wrap them never change.
static func column(spec: Dictionary) -> Image:
	return _painter("column").paint(spec)


static func hazard(spec: Dictionary) -> Image:
	return _painter("hazard").paint(spec)


static func heart() -> Image:
	return _painter("heart").paint()


## Wraps a painted image as an embeddable texture. Every picture in this project
## goes through here, and it is a PortableCompressedTexture2D rather than a PNG
## for one reason: a PNG is useless until Godot imports it, which needs the
## editor or a --import pass, while this is usable the instant it exists. That
## matters because the editor is usually open while these run.
##
## Left unsaved by the caller, it has no resource_path, which is exactly what
## makes PackedScene embed it as a sub-resource instead of writing a separate
## file to point at - see build_levels.gd.
static func texture(img: Image) -> PortableCompressedTexture2D:
	var tex := PortableCompressedTexture2D.new()
	tex.keep_compressed_buffer = true
	tex.create_from_image(img, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
	return tex
