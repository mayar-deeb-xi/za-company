extends RefCounted
## The dead plant is the living one drooped and browned - one painter, two
## catalogue types, because DESIGN.md places them independently.

const Plant := preload("plant.gd")

const SIZE := Plant.SIZE
const BLOCKS := Plant.BLOCKS


static func paint(spec: Dictionary) -> Image:
	return Plant.grow(spec, true)
