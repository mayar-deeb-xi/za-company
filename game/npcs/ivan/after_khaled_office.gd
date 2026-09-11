extends RefCounted
## What Ivan says in the top-floor office, after the last fight in the game.
## Data only - the shape of one of these is in after_call_center.gd.
##
## The send-off, and the one file that had to be written around a question the
## design has not answered yet: whether Silverman IS Khaled (DESIGN.md's open
## item). So Ivan names nobody and points at no door. He says how far up this
## is, how long he has worked under it, and that whatever is next should not be
## done hungry - all of which stays true whichever way that decision lands.
##
## It is also the last of the six, so it is the only one that does not end by
## sending the player anywhere. Every other floor has a floor above it.

const BEATS := [
	{
		"name": "Ivan",
		"text": "We heard that from the kitchen. I think the whole building "
			+ "heard that.",
		"voice": "res://game/npcs/ivan/sfx/voice/khaled_heard.wav",
	},
	{
		"text": "Sixteen years I have worked under this room. Nobody has ever "
			+ "got up here, and nobody has ever carried a tray this far.",
		"voice": "res://game/npcs/ivan/sfx/voice/khaled_sixteen.wav",
	},
	{
		"text": "There is nothing above us now. Whatever happens next, do not "
			+ "do it hungry. Eat.",
		"voice": "res://game/npcs/ivan/sfx/voice/khaled_nothing_above.wav",
	},
]
