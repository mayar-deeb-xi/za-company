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
	{
		"id": "wraith",
		"frames": "res://game/enemies/wraith/wraith_frames.tres",
		"recipe": {
			"hair": "eef1f7", "hair_light": "ffffff",   # white
			"skin": "d7dde9",                           # bloodless, cooler than
			                                            # the hair so it reads
			"eye": "1b2a52",                            # dark blue
			"shirt": "232f5c", "shirt_dark": "141c38",  # dark blue
			"pants": "1b2450", "pants_dark": "0e1430",
			# Straight hair, normal build: deliberately one of the cast, drained
			# of colour, rather than a monster.
			"hair_style": "straight", "beard": false, "build": "normal",
		},
	},
	{
		"id": "warden",
		"frames": "res://game/enemies/warden/warden_frames.tres",
		"recipe": {
			"hair": "4a3a6b", "hair_light": "6d59a0",   # deep violet
			"skin": "8f86b8",
			"eye": "d8e8ff",                            # pale, lit from inside
			"shirt": "3a2f5c", "shirt_dark": "241d3a",
			"pants": "2e2748", "pants_dark": "1b1730",
			# Heavy and bearded: it plants itself and holds ground, so it wants
			# the widest silhouette of the three.
			"hair_style": "short_curly", "beard": true, "build": "wide",
		},
	},
]
