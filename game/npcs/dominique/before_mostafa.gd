extends RefCounted
## What Dominique says on the innovation lab floor, with the gym above it. Data
## only - the beat format is in game/dialogue/dialogue_director.gd, and the shape
## of a briefing is in before_ahmed.gd, which is the first one and carries the
## reasoning for all three.
##
## Mostafa is a RHYTHM (game/bosses/CLAUDE.md), so the briefing is about
## counting rather than about reading him: two fast, one slow, always in that
## order. That is a thing a player can be told once and then use for the whole
## fight, which is exactly what a signpost is for - and it is the one boss whose
## pattern is the same every time, so telling it gives nothing away that the
## third repetition would not.
##
## The fire is last because it is the only part that changes the fight rather
## than the reading of it: he goes up at half health and never comes back down.

const BEATS := [
	{
		"name": "Dominique",
		"text": "Upstairs is the gym. On the floor plan it says Conflict "
			+ "Resolution. Nothing has ever been resolved in there.",
		"voice": "res://game/npcs/dominique/sfx/voice/mostafa_gym.wav",
	},
	{
		"text": "Mostafa boxes. Two fast, then one slow. Always that order, "
			+ "every time, until one of you stops.",
		"voice": "res://game/npcs/dominique/sfx/voice/mostafa_rhythm.wav",
	},
	{
		"text": "The two fast ones you cannot stop, so do not stand there "
			+ "trying. Move, and they hit the air. The slow one you can stop. "
			+ "That is your whole job in that room.",
		"voice": "res://game/npcs/dominique/sfx/voice/mostafa_break.wav",
	},
	{
		"text": "One more thing. Halfway through, he catches fire, and he "
			+ "stays that way. He does not get tired after that. You still do.",
		"voice": "res://game/npcs/dominique/sfx/voice/mostafa_fire.wav",
	},
]
