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
##
## He is VOICED, so every beat carries its clip. The read is directed per line
## in tools/voice/ivan.py and the names here are what cut.py writes - reword a
## line and its clip is stale until it is re-cut, but rename one and the cut is
## paid for twice. The box holds each line for as long as its recording runs
## (ui/dialogue/dialogue_box.gd), so the hearts land after he has finished
## saying the last word rather than while he is still saying it.

const BEATS := [
	{
		"name": "Ivan",
		"text": "There you are. Still standing. I hate this part - I always count you twice.",
		"voice": "res://game/npcs/ivan/sfx/voice/still_standing.wav",
	},
	{
		"text": "Sit down. No - do not sit down, you will bleed on the chair.",
		"voice": "res://game/npcs/ivan/sfx/voice/chair.wav",
	},
	{
		"text": "I made too much again. I always make too much. Eat.",
		"voice": "res://game/npcs/ivan/sfx/voice/eat.wav",
	},
]
