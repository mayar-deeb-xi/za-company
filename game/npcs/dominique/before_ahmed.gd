extends RefCounted
## What Dominique says on the call centre floor, once it is quiet and the only
## thing left up the stairs is Ahmed. Data only - the beat format is in
## game/dialogue/dialogue_director.gd.
##
## ## A signpost that is worth stopping for
##
## She is the fourth beat (`briefing` in biome data, game/levels/relief.gd), and
## the whole reason she is a beat rather than a line at a door is that a warning
## about a fight is only information while the fight is still ahead. She comes
## DOWN through the north door - the one the player is about to go up - so she
## is standing between them and it, and walking past her is a choice.
##
## Every briefing in this folder ends on the boss's actual TELL, because Ahmed
## is the teaching boss and this is the floor before him: the fire wave is the
## one attack in his menu that the player cannot read off his body, since it is
## cued by THEIR behaviour rather than by his. Being told "step to the side"
## before it happens is the difference between a lesson and an ambush. The
## middle beats are the fight's shape; the last one is the thing to do.
##
## Four beats and no question. She has no branch anywhere in the game - a guide
## who asks you things is a conversation, and she is a road sign.

const BEATS := [
	{
		"name": "Dominique",
		"text": "So you are going up. Fine. I will say this once, because I "
			+ "have said it to others and they also went up.",
		"voice": "res://game/npcs/dominique/sfx/voice/ahmed_listen.wav",
	},
	{
		"text": "Ahmed is family. That is the whole reason nobody has taken "
			+ "the axe off him. Nobody has put out the axe either.",
		"voice": "res://game/npcs/dominique/sfx/voice/ahmed_family.wav",
	},
	{
		"text": "He swings wide, he swings close. Every third one he puts "
			+ "into the floor instead, and that one finds everybody standing "
			+ "near him. His own people included.",
		"voice": "res://game/npcs/dominique/sfx/voice/ahmed_slam.wav",
	},
	{
		"text": "And do not back away from him. Back away and he sends fire "
			+ "down the room after you. Step to the side. Not back. Side.",
		"voice": "res://game/npcs/dominique/sfx/voice/ahmed_fire.wav",
	},
]
