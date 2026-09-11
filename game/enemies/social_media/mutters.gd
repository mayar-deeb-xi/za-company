extends RefCounted
## What the Content Studio says to itself. The whole file is data -
## `game/enemies/enemy_lines.gd` is the only thing that reads it, and the only
## thing that decides when.
##
## Lives with the mouth it comes out of, the placement rule a boss's taunts.gd
## and an NPC's conversation already follow.
##
## ## One cue, and it is not aimed at you
##
## A boss's lines are all ADDRESSED - he has noticed you, he is swinging at
## you, he has lost to you. These are the opposite and that is the whole
## effect: she is not talking to the player, she is talking to herself, and the
## player is overhearing an office. `enemy_base` asks for `mutter` on a slow
## poll while she is alive, so it never lands on a moment - there is no moment
## to land on.
##
## She is a wraith: no attack, no telegraph, and standing near her costs you
## three health a second. So the joke writes itself and the lines lean on it -
## every one of them is about not having enough time, said by the thing that is
## taking yours. The two halves have to stay in step; a line about anything
## else would just be an NPC standing in a fight.
##
## Kept SHORT on purpose. A mutter plays under a fight at -31 dBFS with no
## subtitle behind it, so anything longer than about six words is heard as
## texture rather than as a sentence, and the one clause that carries the joke
## should be the one clause there is. The longest here is eight words and it is
## the only one that repeats itself.

const VOICE := "res://game/enemies/social_media/sfx/voice/"

const LINES := {
	# One cue, polled. The order here is not an order - enemy_lines.gd picks at
	# random and never twice running, so what matters is that no two read the
	# same way rather than what follows what.
	"mutter": [
		{"text": "I don't have time for this.", "voice": VOICE + "mutter_1.wav"},
		{"text": "The deadline was yesterday.", "voice": VOICE + "mutter_2.wav"},
		{"text": "I'm so behind. I'm so far behind.",
			"voice": VOICE + "mutter_3.wav"},
		{"text": "There's never any time. Never.", "voice": VOICE + "mutter_4.wav"},
		# The one that says out loud what her aura is doing.
		{"text": "I just need five more minutes.", "voice": VOICE + "mutter_5.wav"},
		{"text": "I was supposed to be done by now.",
			"voice": VOICE + "mutter_6.wav"},
		{"text": "It's due at five. It's always five.",
			"voice": VOICE + "mutter_7.wav"},
		{"text": "Three more before midnight.", "voice": VOICE + "mutter_8.wav"},
	],
}
