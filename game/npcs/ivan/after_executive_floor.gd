extends RefCounted
## What Ivan says on the executive floor. Data only - the shape of one of these
## is in after_call_center.gd.
##
## This is the floor where the reskins stop and the ORIGINALS stand (see the
## root CLAUDE.md): the building has stopped pretending to be an office and the
## people in it have stopped looking like colleagues. Ivan is the one character
## who could possibly notice, because he is the one who knows every face in the
## building by what they order - so his tell is not that they were monsters, it
## is that they have never been to lunch.
##
## He is also frightened here for the only time, and it is of being SEEN, not of
## the fight. A cook standing on the executive floor with a tray is a cook with
## something to explain, which is a smaller and much more office fear than the
## one the room is for.

const BEATS := [
	{
		"name": "Ivan",
		"text": "Those ones were not staff. Nobody with a face like that has "
			+ "ever stood in my queue for lunch.",
		"voice": "res://game/npcs/ivan/sfx/voice/exec_not_staff.wav",
	},
	{
		"text": "I do not come up here. The kitchen does not come up here. "
			+ "Today the kitchen came up here.",
		"voice": "res://game/npcs/ivan/sfx/voice/exec_kitchen.wav",
	},
	{
		"text": "So take it quickly, before somebody important asks me what I "
			+ "am doing on this floor. Eat.",
		"voice": "res://game/npcs/ivan/sfx/voice/exec_quickly.wav",
	},
]
