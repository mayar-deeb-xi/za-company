extends RefCounted
## The bestiary. One entry per enemy type: id, where its SpriteFrames live, and
## the recipe tools/build_characters.gd bakes for it - enemies wear the same CC0
## body and animation set as the playable cast, restyled the same way biome art
## is restyled from the dungeon sheet.
##
## Only looks live here. Stats (health, damage, speed, sight) are @exports on
## enemy_base.gd, set per scene, so a level can retune the copy it places
## without touching any other.

const ENEMIES := [
	{
		"id": "regular",
		"frames": "res://game/enemies/regular/regular_frames.tres",
		"recipe": {
			"hair": "9db06b", "hair_light": "9db06b",   # unused - bald
			"skin": "9db06b",                           # sickly green
			"eye": "c22a2a",                            # red
			"shirt": "4a4452", "shirt_dark": "2e2a34",  # ragged grey-purple
			"pants": "3a3a34", "pants_dark": "242420",
			"hair_style": "bald", "beard": false, "build": "skinny",
		},
	},
]
