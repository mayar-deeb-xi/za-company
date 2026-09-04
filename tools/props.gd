extends RefCounted
## The front door to tools/props/ - the folder IS the catalogue.
##
## The catalogue is shelved by what a prop IS - furniture/, hardware/,
## signs/, markings/, openings/, fixtures/ - and every file on a shelf is one
## placeable prop type, named by its filename alone: `{"type": "desk"}` in a
## biome's props list resolves to whichever shelf holds desk.gd, no registry
## in between and no shelf name in the data. A shelf is where a file sits,
## never part of its name, so re-shelving a prop touches no floor's data.
## Adding a prop to the game is writing one new file on the shelf it belongs
## to and giving it a position in tools/biomes.gd - nothing else changes, this
## file included, and a shelf that does not exist yet is made by putting the
## first file on it. Two shelves claiming one name is an error at first lookup.
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
## fixtures/ (column, hazard, heart) is the shelf known() refuses: a level
## places those itself, so they can be painted here but never listed as
## furniture. _brush.gd is the shared painting kit, kept out of the catalogue
## by sitting at the root - only the shelves are scanned.
##
## Editor-side only, like the rest of tools/: nothing under game/ loads this.

const DIR := "res://tools/props"

## type -> "res://tools/props/<shelf>/<type>.gd", filled by the first lookup.
static var _catalogue: Dictionary = {}


static func _path(type: String) -> String:
	if _catalogue.is_empty():
		for shelf in DirAccess.get_directories_at(DIR):
			for file in DirAccess.get_files_at("%s/%s" % [DIR, shelf]):
				if not file.ends_with(".gd"):
					continue
				var found := "%s/%s/%s" % [DIR, shelf, file]
				var name := file.get_basename()
				if _catalogue.has(name):
					push_error("two props named '%s': %s and %s"
							% [name, _catalogue[name], found])
					continue
				_catalogue[name] = found
	return _catalogue.get(type, "")


## Untyped on purpose: painters are dispatched by filename at runtime, and a
## typed GDScript var would make every .paint() a compile-time member lookup.
static func _painter(type: String):
	var path := _path(type)
	assert(path != "", "nothing in tools/props/ draws '%s'" % type)
	return load(path)


static func _const(type: String, key: String, fallback: Variant) -> Variant:
	return _painter(type).get_script_constant_map().get(key, fallback)


## A type is placeable when a shelf other than fixtures/ declares it: levels
## place the fixtures themselves, so being shelved there IS the opt-out that a
## missing SIZE used to signal.
static func known(type: String) -> bool:
	var path := _path(type)
	return path != "" and not path.begins_with(DIR + "/fixtures/")


## Which shelf a catalogue type sits on - "furniture", "hardware", "signs".
## build_levels.gd mirrors it into a level's own props/ folder, so finding a
## prop's scene in a level is the same walk as finding its painter here.
static func shelf_of(type: String) -> String:
	return _path(type).get_base_dir().get_file()


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
