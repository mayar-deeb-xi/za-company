extends RefCounted
## The building's three friendly faces. One entry per NPC: id, display name, its
## own source sheet, where the baked SpriteFrames go, and the recipe + robe that
## SEEDED that sheet.
##
## **Every NPC owns its sheet**, on exactly the enemies' terms and for the same
## reason: tools/build_npcs.gd writes `src` once, from `recipe` and `robe`, only
## if it is missing, and slices whatever is on disk every run after that. Draw
## into an NPC's own PNG and rebuild - nothing else in the game moves. The cast
## is the one thing that shares a sheet, because the seven of them will always
## want one animation set between them; these three will not.
##
## `recipe` and `robe` stay as provenance and as the way back: delete an NPC's
## PNG, run build_npcs.gd, and its art starts over from the cast body.
##
## Only looks live here. Where an NPC stands, what it says and how fast it walks
## are the scene's business - see game/npcs/npc_base.gd.
##
## Preloaded by path rather than reached via `class_name`, like every other
## cross-feature script in this project.

## Idle and walk in three directions, at 64px. An NPC has no swing to draw and
## no attack to play, so those rows are not in the sheet - the same trim the
## wraith and the warden take.
const LAYOUT := {
	"down": {"idle": 0, "walk": 1},
	"up": {"idle": 2, "walk": 3},
	"side": {"idle": 4, "walk": 5},
}
const SPECS := {
	"idle": {"frames": 1, "fps": 1.0, "loop": true},
	"walk": {"frames": 4, "fps": 10.0, "loop": true},
}

const NPCS := [
	{
		# The guide at the front desk, and the first person in the building who
		# is pleased to see you. Long blonde hair, which is the whole reason the
		# `long` recipe key exists - and the reason npc_art.gd lays the head
		# over the robe rather than under it, so the hair falls onto the cloth.
		"id": "dominique",
		"name": "Dominique",
		"src": "res://game/npcs/dominique/src/dominique.png",
		"frames": "res://game/npcs/dominique/dominique_frames.tres",
		"recipe": {
			"hair": "d9b64f", "hair_light": "ecd27e",   # blonde
			"skin": "f0d5c4",
			"eye": "2e7d4f",                            # green
			"shirt": "2e7d7d", "shirt_dark": "1c4f4f",  # teal robe
			"pants": "33333d", "pants_dark": "202028",  # unseen under a floor hem
			"hair_style": "straight", "beard": false, "build": "skinny",
			"long": [8, 11],
		},
		"robe": {"head_scale": 2, "hem": "floor", "cord": true, "sway": true},
	},
	{
		# The healer in the cafeteria. Cropped black curls and a red robe; the
		# hemp cord is doing real work on him, breaking the red into two blocks
		# so a floor-length NPC does not read as a walking heart pickup.
		"id": "ivan",
		"name": "Ivan",
		"src": "res://game/npcs/ivan/src/ivan.png",
		"frames": "res://game/npcs/ivan/ivan_frames.tres",
		"recipe": {
			"hair": "221d29", "hair_light": "4d4560",   # black
			"skin": "f0d5c4",
			"eye": "2e7d4f",                            # green
			"shirt": "b3242c", "shirt_dark": "7a1218",  # red robe
			"pants": "e8e8ec", "pants_dark": "bcbcc8",  # unseen under a floor hem
			"hair_style": "short_curly", "beard": false, "build": "skinny",
		},
		"robe": {"head_scale": 2, "hem": "floor", "cord": true, "sway": true},
	},
	{
		# HR, and she is not given a first name on purpose - everyone else in
		# the building has one, and the joke is that she is a department. Light
		# pink hair past the shoulders over a white dress, belted like the
		# other two: an unbelted white column reads flat, and the cord is the
		# only thing breaking the dress into two blocks.
		#
		# She is also the only NPC whose garment can lose its silhouette to the
		# floor - the lobby is blue-grey marble and the marble hall tops out at
		# pure white - so her 1px outline is doing the work the other two get
		# from a saturated robe. Worth remembering before she is placed.
		"id": "hr_lady",
		"name": "HR",
		"src": "res://game/npcs/hr_lady/src/hr_lady.png",
		"frames": "res://game/npcs/hr_lady/hr_lady_frames.tres",
		"recipe": {
			"hair": "e89ab8", "hair_light": "f8cfe0",   # light pink
			"skin": "f0d5c4",
			# Dark plum rather than the green the other two share: against pink
			# hair a saturated eye reads as a band across the face at 1x.
			"eye": "4a3140",
			"shirt": "f2f2f6", "shirt_dark": "c6c6d4",  # white dress
			"pants": "e8e8ec", "pants_dark": "bcbcc8",  # unseen under a floor hem
			"hair_style": "straight", "beard": false, "build": "skinny",
			"long": [8, 11],
		},
		"robe": {"head_scale": 2, "hem": "floor", "cord": true, "sway": true},
	},
]


static func find(id: String) -> Dictionary:
	for entry in NPCS:
		if entry["id"] == id:
			return entry
	return {}


## Empty string for an unknown id; callers keep whatever frames they have.
static func frames_path(id: String) -> String:
	return find(id).get("frames", "")
