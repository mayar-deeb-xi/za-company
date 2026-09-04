extends RefCounted
## The playable cast. One entry per character: id, display name, and where that
## character's SpriteFrames live. Everyone shares the same body and animations -
## the differences are cosmetic (hair, clothes, eyes) plus a one-pixel build
## tweak, all described by `recipe` and baked by tools/build_characters.gd.
##
## Preloaded by path rather than reached via `class_name`, like every other
## cross-feature script in this project.

const DEFAULT_ID := "mayar"

## Recipe colour keys replace the matching colour of the source sheet; see the
## SRC_* palette in tools/build_characters.gd. Shape keys:
##   hair_style: "straight" | "curly" | "short_curly" | "bald"
##   beard:      true paints the jaw in the hair colour (front/side frames only)
##   build:      "normal" | "wide" | "tall" | "skinny" - one duplicated or
##               removed pixel column/row, applied to every frame
const CHARACTERS := [
	{
		"id": "mayar",
		"name": "Mayar",
		"frames": "res://game/player/characters/mayar_frames.tres",
		"recipe": {
			"hair": "221d29", "hair_light": "4d4560",   # black curls
			"skin": "f0d5c4",
			"eye": "2b2130",
			"shirt": "a9a9b4", "shirt_dark": "6a6a76",  # grey shirt
			"pants": "4a6a9c", "pants_dark": "31486e",  # denim
			"hair_style": "curly", "beard": false, "build": "normal",
		},
	},
	{
		"id": "monaf",
		"name": "Monaf",
		"frames": "res://game/player/characters/monaf_frames.tres",
		"recipe": {
			"hair": "d9b64f", "hair_light": "ecd27e",   # blond
			"skin": "f0d5c4",
			"eye": "2e7d4f",                            # green
			"shirt": "2e2e38", "shirt_dark": "1c1c24",  # black t-shirt
			"pants": "355080", "pants_dark": "243858",  # dark blue jeans
			"hair_style": "straight", "beard": true, "build": "wide",
		},
	},
	{
		"id": "omar",
		"name": "Omar",
		"frames": "res://game/player/characters/omar_frames.tres",
		"recipe": {
			"hair": "221d29", "hair_light": "4d4560",   # black
			"skin": "f0d5c4",
			"eye": "141018",                            # black
			"shirt": "e8e8ec", "shirt_dark": "bcbcc8",  # white shirt
			"pants": "33333d", "pants_dark": "202028",  # black pants
			"hair_style": "straight", "beard": false, "build": "skinny",
		},
	},
	{
		"id": "anas",
		"name": "Anas",
		"frames": "res://game/player/characters/anas_frames.tres",
		"recipe": {
			"hair": "f0d5c4", "hair_light": "f0d5c4",   # unused - bald
			"skin": "f0d5c4",
			"eye": "2b2130",
			"shirt": "b3242c", "shirt_dark": "7a1218",  # red shirt
			"pants": "355080", "pants_dark": "243858",  # dark blue jeans
			"hair_style": "bald", "beard": false, "build": "tall",
		},
	},
	{
		"id": "amr",
		"name": "Amr",
		"frames": "res://game/player/characters/amr_frames.tres",
		"recipe": {
			"hair": "5a3a22", "hair_light": "7c5535",   # brown
			"skin": "f0d5c4",
			"eye": "2b2130",
			"shirt": "8e2634", "shirt_dark": "5c1620",  # dark red shirt
			"pants": "33333d", "pants_dark": "202028",  # black pants
			"hair_style": "straight", "beard": false, "build": "normal",
		},
	},
	{
		"id": "hamza",
		"name": "Hamza",
		"frames": "res://game/player/characters/hamza_frames.tres",
		"recipe": {
			"hair": "3a2a1e", "hair_light": "5c4a36",   # dark brown curls
			"skin": "f0d5c4",
			"eye": "2b2130",
			"shirt": "7d7c46", "shirt_dark": "51502c",  # olive shirt
			"pants": "33333d", "pants_dark": "202028",  # black pants
			"hair_style": "short_curly", "beard": false, "build": "skinny",
		},
	},
	{
		"id": "reem",
		"name": "Reem",
		"frames": "res://game/player/characters/reem_frames.tres",
		"recipe": {
			"hair": "e87fb8", "hair_light": "f4b1d4",   # pink
			"skin": "f0d5c4",
			"eye": "c9578f",                            # pink
			"shirt": "7d7c46", "shirt_dark": "51502c",  # olive shirt
			"pants": "e8e8ec", "pants_dark": "bcbcc8",  # white pants
			"hair_style": "straight", "beard": false, "build": "skinny",
		},
	},
]


static func find(id: String) -> Dictionary:
	for entry in CHARACTERS:
		if entry["id"] == id:
			return entry
	return {}


## Empty string for an unknown id; callers keep whatever frames they have.
static func frames_path(id: String) -> String:
	return find(id).get("frames", "")
