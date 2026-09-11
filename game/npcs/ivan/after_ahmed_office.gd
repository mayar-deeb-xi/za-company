extends RefCounted
## What Ivan says in Ahmed's office, with Ahmed still kneeling in it. Data only
## - the shape of one of these, and the three rules all six obey, are in
## after_call_center.gd, which is the first one.
##
## The first boss floor, and the first time the man who feeds you and the man
## who just tried to kill you are the same building's problem. He does not take
## the player's side and he does not take Ahmed's: he complains about the soup.
## That is the whole of the tone rule in one beat - these are colleagues, and
## the kitchen has an opinion about all of them.
##
## "He brought an axe to an office" is the one line that says out loud what
## DESIGN.md calls him, and it is Ivan's permission slip: the player has just
## beaten up a relative of the man upstairs and is allowed not to feel bad.

const BEATS := [
	{
		"name": "Ivan",
		"text": "Leave him. He is not hurt - he is embarrassed. For Ahmed "
			+ "that is worse.",
		"voice": "res://game/npcs/ivan/sfx/voice/ahmed_embarrassed.wav",
	},
	{
		"text": "He eats in my kitchen every day of the week. Every day he "
			+ "tells me the soup needs salt. It has never needed salt.",
		"voice": "res://game/npcs/ivan/sfx/voice/ahmed_salt.wav",
	},
	{
		"text": "So do not feel bad about this. He is the one who brought an "
			+ "axe to an office. Eat.",
		"voice": "res://game/npcs/ivan/sfx/voice/ahmed_axe.wav",
	},
]
