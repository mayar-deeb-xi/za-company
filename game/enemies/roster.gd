extends RefCounted
## The bestiary. One entry per enemy type: id, its own source sheet, where its
## baked SpriteFrames go, and the recipe that SEEDED that sheet.
##
## **Every enemy owns its sheet.** `src` is hand-owned art from the moment it
## exists: tools/build_enemies.gd writes it once, from `recipe`, only if it is
## missing, and slices whatever is on disk every run after that. Draw a new
## animation into an enemy's own PNG and rebuild - nothing else in the game
## moves. That is the whole reason enemies do not share the cast's sheet the way
## the seven characters do: the cast will always want one animation set between
## them, while each enemy is heading somewhere different, and one shared sheet
## would pile every enemy's moves into a single file.
##
## `recipe` stays as provenance and as the way back: delete an enemy's PNG, run
## build_enemies.gd, and its art starts over from the plain CC0 body.
##
## An enemy whose sheet grows rows the CC0 grid does not have adds a `layout`
## (and `specs` if the timing differs) here; without one it uses `CC0_LAYOUT` in
## tools/character_art.gd - the layout seeding produced, frozen. The cast's
## layout is a separate constant in tools/build_characters.gd on purpose, so a
## new PLAYER animation can never tell an enemy to slice a row its own sheet
## does not have.
##
## Only looks live here. Stats (health, damage, speed, sight, and each type's
## own ability numbers) are @exports on the enemy scripts, set per scene, so a
## level can retune the copy it places without touching any other.

const ENEMIES := [
	{
		"id": "regular",
		"src": "res://game/enemies/regular/src/regular.png",
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
		"src": "res://game/enemies/wraith/src/wraith.png",
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
		"src": "res://game/enemies/warden/src/warden.png",
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
