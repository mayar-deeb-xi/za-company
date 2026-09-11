extends RefCounted
## What Dominique says on the executive floor, with the penthouse above it and
## nothing above that. Data only - the beat format is in
## game/dialogue/dialogue_director.gd, and the shape of a briefing is in
## before_ahmed.gd, which carries the reasoning for all three.
##
## Silverman is a LADDER (game/bosses/CLAUDE.md): three phases, each keeping
## what the last one had, and the interrupts narrowing to none. That last part
## is the only thing in the three briefings that is about the player's clock
## rather than about the boss - everything they have been saving stops working
## at 64 health, so the advice is to spend it before then.
##
## It is also the last thing she says in the game, which is why she says so.
## There is no floor after the penthouse and no fourth briefing to write: this
## one closes her out.

const BEATS := [
	{
		"name": "Dominique",
		"text": "The penthouse. Last door in the building. After this one you "
			+ "will not need me, which is either good news or it is not.",
		"voice": "res://game/npcs/dominique/sfx/voice/silverman_last_door.wav",
	},
	{
		"text": "Silverman does not hurry. That is not manners. He has been "
			+ "doing this since before they hired any of us.",
		"voice": "res://game/npcs/dominique/sfx/voice/silverman_slow.wav",
	},
	{
		"text": "He changes three times, and he keeps everything he had. "
			+ "First he is almost fair. Then the room goes cold wherever he "
			+ "is standing. Then he splits, and the copy walks at you while "
			+ "he watches.",
		"voice": "res://game/npcs/dominique/sfx/voice/silverman_phases.wav",
	},
	{
		"text": "By the last part, nothing you do stops him. Nothing. So "
			+ "whatever you were saving for the end - spend it early.",
		"voice": "res://game/npcs/dominique/sfx/voice/silverman_early.wav",
	},
]
