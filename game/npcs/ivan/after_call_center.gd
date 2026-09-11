extends RefCounted
## What Ivan says on the call floor - the FIRST time the player ever meets him,
## and the file that carries the reasoning for the other five. Data only: the
## beat format is in game/dialogue/dialogue_director.gd, and the hearts are in
## game/npcs/ivan/ivan.gd, which throws them when this runs out.
##
## ## One file per floor, and the floor is why
##
## He used to say one set of three lines on all six floors. A man who walks in
## after a fight you have just had and says something that fits no fight in
## particular is a vending machine with a voice - and by the fourth floor the
## player has heard it three times and reads none of it. `conversation` was
## always placement, exactly as which way he faces is, so six floors is six
## files and no code: the biome names one under `relief.say`.
##
## Three rules hold across all six, and they are what stop six files becoming
## six different men:
##
## - **He talks about the room he just walked into**, because that is the one
##   thing he could not have said downstairs. The floor's own fight, its own
##   people, its own joke.
## - **He knows everybody**, which is what makes him warm rather than merely
##   useful: Ahmed and Mostafa eat in his kitchen, the office boys fix his
##   ovens. DESIGN.md's tone rule is affectionate and never mean, and the man
##   who feeds the enemy is how a beat-em-up keeps it.
## - **The last word is "Eat."** on every floor. It is DESIGN.md's one line for
##   him and the hearts land on it (ivan.gd gives on the falling edge of the
##   talk), so it is a refrain rather than a repeat - the sentence in front of
##   it is different every time, and the word that pays out never moves.
##
## ## This floor
##
## The introduction, so he says his name and what he does here - nobody has
## told the player there is a kitchen in this building. The joke is the floor's
## own: a room whose wallboard says 142 CALLS WAITING is a room where nobody
## has stopped to eat.
##
## He is VOICED. The clip names are namespaced by floor (`call_`) because all
## six files cut into ONE folder and nothing dedupes across them - two floors
## that both named a clip `eat` would cut once and the second floor would play
## the first floor's read. tools/voice/ivan.py, on cut.py's terms.

const BEATS := [
	{
		"name": "Ivan",
		"text": "Ivan. I run the kitchen. The phone stopped ringing, so I "
			+ "came up to see who stopped them.",
		"voice": "res://game/npcs/ivan/sfx/voice/call_kitchen.wav",
	},
	{
		"text": "Nobody on this floor eats. They drink coffee and they say "
			+ "they are on hold. That is not a lunch.",
		"voice": "res://game/npcs/ivan/sfx/voice/call_hold.wav",
	},
	{
		"text": "You are new, so I will say this once. When I bring you food, "
			+ "you take the food. Eat.",
		"voice": "res://game/npcs/ivan/sfx/voice/call_eat.wav",
	},
]
