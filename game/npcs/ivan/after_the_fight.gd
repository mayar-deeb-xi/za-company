extends RefCounted
## What Ivan says when he finds you standing in a room you have just cleared.
## Data only - the beat format is in game/dialogue/dialogue_director.gd, and the
## hearts are in game/npcs/ivan/ivan.gd, which throws them when this runs out.
##
## Three lines and no question, on purpose. He turns up at the one moment the
## player has earned a breath, and a branch at that moment is one more thing to
## decide. The last word is DESIGN.md's only line for him - "Eat." - and the
## hearts land on it.
##
## A floor is free to name a file of its own instead: `conversation` is
## placement, exactly as which way he faces is, which is how the finale gets a
## different man at the door without a second Ivan.

const BEATS := [
	{"name": "Ivan",
		"text": "There you are. Still standing. I hate this part - I always count you twice."},
	{"text": "Sit down. No - do not sit down, you will bleed on the chair."},
	{"text": "I made too much again. I always make too much. Eat."},
]
