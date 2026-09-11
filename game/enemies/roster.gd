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
## An enemy whose sheet does not match the CC0 grid adds a `layout` (and `specs`
## if the timing differs) here - rows grown as well as rows dropped, which is
## what `NO_ATTACK_LAYOUT` below is. Without one it uses `CC0_LAYOUT` in
## tools/character_art.gd - the layout seeding produced, frozen. The cast's
## layout is a separate constant in tools/build_characters.gd on purpose, so a
## new PLAYER animation can never tell an enemy to slice a row its own sheet
## does not have.
##
## Only looks live here. Stats (health, damage, speed, sight, and each type's
## own ability numbers) are @exports on the enemy scripts, set per scene, so a
## level can retune the copy it places without touching any other.

## Six rows, no attack: idle and walk in the three directions and nothing else.
##
## The CC0 grid's bottom three rows are a sword swing, and two of the enemies
## deliberately never draw a weapon - the wraith has no attack at all
## (`_attacks()` is false; its harm is proximity) and the warden animates its
## charge as `idle` on purpose, since a harmless enemy raising a sword for two
## seconds reads as the one thing it is not. Rows nothing can ever play are dead
## weight in a hand-owned sheet, so those two PNGs are 6 rows tall and say so
## here. Draw a swing into one of them later and it wants its own `layout` back.
const NO_ATTACK_LAYOUT := {
	"down": {"idle": 0, "walk": 1},
	"up": {"idle": 2, "walk": 3},
	"side": {"idle": 4, "walk": 5},
}

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
		# Floor 2's crowd, and the first enemy that is a COLLEAGUE rather than a
		# monster: the company's maintenance staff, met on the floor they work
		# on, surrounded by everything they have not got round to fixing. So the
		# look is deliberately mundane - company-teal polo, dark work trousers,
		# nothing drained or violet about it. The teal is the lobby's accent on
		# purpose: this is the same company's uniform, one floor up.
		#
		# **His sheet is hand-drawn past this recipe and the recipe below is now
		# only provenance.** What is on disk is the polo with a dark apron over
		# it, and a WRENCH rather than the seed's sword - a short thrust along
		# the facing, and DESIGN.md's "wind-up = raising a tool" made literal.
		# Two things about it are load-bearing and easy to undo by accident:
		# the thrust reads by the LENGTH of the silhouette (ready, coiled,
		# driving, extended) with the impact on frame 3, which is the frame the
		# 0.45s wind-up holds on while the blow lands; and the wrench is drawn
		# into the idle and walk rows too, so it does not appear out of thin air
		# the moment he attacks. Redraw from the recipe only to start over.
		#
		# Mechanically it IS the regular - 24 HP, the same cycle, the base's
		# numbers - which is what DESIGN.md means by a reskin. Only the sheet
		# and the name differ, so everything the interrupt rules were tuned
		# against still holds.
		"id": "office_boy",
		"src": "res://game/enemies/office_boy/src/office_boy.png",
		"frames": "res://game/enemies/office_boy/office_boy_frames.tres",
		"recipe": {
			"hair": "241c16", "hair_light": "3d2f24",   # dark, short
			"skin": "c8a882",
			"eye": "2a1f18",
			"shirt": "3fae87", "shirt_dark": "24705a",  # the company polo
			"pants": "2f3540", "pants_dark": "1c2028",  # dark work trousers
			# Ordinary build and no beard: the threat is that there are four of
			# them, not that any one of them looks frightening.
			"hair_style": "straight", "beard": false, "build": "normal",
		},
	},
	{
		"id": "wraith",
		"src": "res://game/enemies/wraith/src/wraith.png",
		"frames": "res://game/enemies/wraith/wraith_frames.tres",
		"layout": NO_ATTACK_LAYOUT,
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
		# Floor 2's crowd, and a wraith in everything but colour: 17 HP, no
		# attack, harm by proximity. The wraith is a person with the colour
		# taken out of them; this one is the same silhouette arriving from the
		# opposite direction - she wears the Content Studio's own neon violet
		# (`a64dff` is that floor's accent) in dyed hair over a black tee, so
		# on the darkest floor in the game the HAIR is the silhouette and the
		# body is barely there.
		#
		# The cost of that, and it was chosen with eyes open: violet under the
		# wraith's cold feed tint (0.55, 0.85, 1.0) moves less than a warm
		# character would, so the drain reads off the aura and the motes more
		# than off the body. drain_aura.gd is carrying the telling here.
		"id": "social_media",
		"src": "res://game/enemies/social_media/src/social_media.png",
		"frames": "res://game/enemies/social_media/social_media_frames.tres",
		"layout": NO_ATTACK_LAYOUT,
		"recipe": {
			"hair": "b45cf0", "hair_light": "d89bff",   # dyed, the floor's neon
			"skin": "e0c4b0",
			"eye": "2a1f33",
			"shirt": "1b1524", "shirt_dark": "0d0913",  # black tee
			"pants": "2a2038", "pants_dark": "160f20",
			# Skinny and unbearded: the squishiest thing in the game at 17 HP,
			# and it should look it.
			"hair_style": "straight", "beard": false, "build": "skinny",
		},
	},
	{
		# Floor 3's denial, and a warden in everything but colour: 36 HP, the
		# two-second charge, the hold that slows. Deliberately the most ORDINARY
		# person in the building - a light grey button-up and navy slacks, no
		# beard - because everything frightening about him is on the floor
		# around him rather than on him.
		#
		# The pale shirt is the working part. The charge tints the body toward
		# violet (0.55, 0.45, 1.0) in proportion to the wind-up, and a light
		# neutral takes that tint harder than any other colour here - so the two
		# seconds of warning read on him as clearly as they do on the ring, which
		# is the counterplay being visible at all.
		"id": "call_center",
		"src": "res://game/enemies/call_center/src/call_center.png",
		"frames": "res://game/enemies/call_center/call_center_frames.tres",
		"layout": NO_ATTACK_LAYOUT,
		"recipe": {
			"hair": "4a4038", "hair_light": "6b5c4e",
			"skin": "d6b191",
			"eye": "2a2119",
			"shirt": "c8ccd4", "shirt_dark": "8b919c",  # office grey
			"pants": "2c3242", "pants_dark": "171c28",  # navy slacks
			# Wide like the warden: it plants itself and holds ground, so it
			# wants the same widest-in-the-room silhouette.
			"hair_style": "straight", "beard": false, "build": "wide",
		},
	},
	{
		"id": "warden",
		"src": "res://game/enemies/warden/src/warden.png",
		"frames": "res://game/enemies/warden/warden_frames.tres",
		"layout": NO_ATTACK_LAYOUT,
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
	{
		# The FOURTH archetype, and the first enemy in the game that is not the
		# size of the cast. The other three take your health, your time and your
		# speed; this one takes your POSITION - a slam that lands as a ring
		# around its own feet and throws you out of it. Which makes the name the
		# mechanic again, the way the two mutterers already are: social media
		# drains your time, the call centre puts you on hold, and security
		# removes you from the premises.
		#
		# **`frame` is the only new key in this file**, and it is why it exists:
		# 64px cells, the size the bosses and the NPCs already slice at, so
		# tools/enemy_art.gd doubles the seed and character_art.slice() cuts it
		# at the size it has taken since the first boss. A 1.5x enemy was the
		# other option and was dropped for a reason worth keeping written down:
		# nearest-neighbour 1.5 puts some source pixels on two destination
		# pixels and their neighbours on one, which wrecks the 1px outline that
		# is the whole silhouette. 2x is exact.
		#
		# He keeps the full nine-row CC0 layout - unlike every other reskin on
		# this floor band, he really does swing something, so the attack rows
		# are rows he can reach.
		#
		# The look is the company uniform gone DARK. The office boy wears the
		# teal service polo; this is the same building's night shift, in
		# charcoal over black, and the colour is chosen against the floor he
		# debuts on rather than in the abstract: the marble hall is pale and
		# tops out near white, so the one thing that must never happen is a big
		# body that reads as a smudge. Dark on pale is the whole of it, and it
		# is the same argument HR's white dress needs in the other direction.
		"id": "security",
		"src": "res://game/enemies/security/src/security.png",
		"frames": "res://game/enemies/security/security_frames.tres",
		"frame": 64,
		"recipe": {
			"hair": "1e1a18", "hair_light": "332b26",   # black, cropped
			"skin": "b08258",
			"eye": "1a1410",
			"shirt": "2b3340", "shirt_dark": "161b24",  # charcoal uniform
			"pants": "1b1f28", "pants_dark": "0d1016",  # black trousers
			# Wide and bearded, like the warden: the widest silhouette in the
			# bestiary, at twice the height of anything else in the room.
			"hair_style": "short_curly", "beard": true, "build": "wide",
		},
	},
]
