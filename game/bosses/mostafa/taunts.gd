extends RefCounted
## What Mostafa says, and the whole file is data - `game/enemies/enemy_lines.gd`
## is the only thing that reads it, and the only thing that decides when.
##
## He is Ahmed's brother, which the floor below already told you: Ahmed asks
## "Do you know who my brother is?" when he is hurt, and goes down saying "I'm
## telling Mostafa." So the first thing this man says has to be the answer to
## that, and the last thing he says has to pass it up the building the same way.
##
## ## He is the opposite of his brother, on purpose
##
## Ahmed is entitled and loud and quite sure this is HR's fault. Mostafa runs
## CONFLICT RESOLUTION - a company gym with a boxing ring painted on the floor
## and a poster reading TALK IT OUT, crossed out, GLOVE IT OUT under it - and he
## talks like the process he is named after: calm, procedural, booking the room,
## noting your feedback, closing the distance. The joke is that none of it is a
## threat and all of it is one. Two brothers shouting the same way would be one
## boss fought twice.
##
## **The rage is where the language breaks.** He catches fire at half health,
## once, and never comes back down, and `rage` is the only cue that fires on
## that frame. It is the one line in the file with no procedure left in it -
## which is the whole character arc spent in a single bark, and why that cue has
## exactly one line the way `concede` does.
##
## ## Cues
##
## `boss_base` fires `spot`, `hurt`, `stagger` and `concede`, plus `taunt` when
## the player keeps their distance, plus one named after each attack as it winds
## up - so `jab`, `hook` and `rush` are HIS, off his own attack ids, three where
## Ahmed has four. `rage` is his alone, said by `mostafa.gd` on the frame he
## goes up.
##
## A cue with no entry here is a cue he has nothing to say on, which is legal
## and silent.

## Where his recordings live. A prefix rather than a path on every line: a
## folder spelled out twenty times is a folder that cannot be moved.
const VOICE := "res://game/bosses/mostafa/sfx/voice/"

const LINES := {
	# He has noticed you. Jumps every queue, so it lands on the frame he looks
	# up - and the first one is the answer to the last thing Ahmed said.
	"spot": [
		{"text": "So you're the one who upset my brother.",
			"voice": VOICE + "spot_1.wav"},
		{"text": "Conflict Resolution. Take a seat. Actually - stand up.",
			"voice": VOICE + "spot_2.wav"},
	],

	# Kept out of his reach and staying there. The one cue that is about the
	# player's behaviour rather than his own, so it is the one where the
	# process language does the most work.
	"taunt": [
		{"text": "Avoidance is not a resolution.",
			"voice": VOICE + "taunt_1.wav"},
		{"text": "You can't de-escalate from over there.",
			"voice": VOICE + "taunt_2.wav"},
		{"text": "Step into the ring. That's where we talk.",
			"voice": VOICE + "taunt_3.wav"},
		{"text": "I've booked this room for an hour.",
			"voice": VOICE + "taunt_4.wav"},
		{"text": "Running is not on the agenda.",
			"voice": VOICE + "taunt_5.wav"},
		{"text": "This is a safe space. Get in it.",
			"voice": VOICE + "taunt_6.wav"},
	],

	# One per attack, said on the wind-up - so the shout is part of the
	# telegraph rather than a comment on it. The jab winds up in 0.250 s and
	# comes in pairs, so its lines are the shortest in the game on purpose:
	# he is counting points, not making speeches.
	"jab": [
		{"text": "Point one.", "voice": VOICE + "jab_1.wav"},
		{"text": "Point two.", "voice": VOICE + "jab_2.wav"},
		{"text": "Still talking.", "voice": VOICE + "jab_3.wav"},
	],
	# The one that hurts - eighteen, three times a jab - and the one he winds
	# up longest for, so it gets the full sentence.
	"hook": [
		{"text": "And THAT is my position!", "voice": VOICE + "hook_1.wav"},
		{"text": "Let me be perfectly clear!", "voice": VOICE + "hook_2.wav"},
	],
	"rush": [
		{"text": "Closing the distance!", "voice": VOICE + "rush_1.wav"},
		{"text": "Meeting you halfway!", "voice": VOICE + "rush_2.wav"},
	],

	"hurt": [
		{"text": "Noted.", "voice": VOICE + "hurt_1.wav"},
		{"text": "I hear you. I disagree.", "voice": VOICE + "hurt_2.wav"},
		{"text": "That's feedback. I'll take it.",
			"voice": VOICE + "hurt_3.wav"},
	],

	# An interrupt. He is not hurt, he is INTERRUPTED, and for this man that is
	# the worse of the two.
	"stagger": [
		{"text": "You interrupted me.", "voice": VOICE + "stagger_1.wav"},
		{"text": "Let me finish!", "voice": VOICE + "stagger_2.wav"},
	],

	# Half health, once, never again - the frame he catches fire. Alone in its
	# cue like `concede` is, because there is no second thing to say here: it
	# is the moment the process stops.
	"rage": [
		{"text": "I tried. I TRIED to do this properly.",
			"voice": VOICE + "rage_1.wav"},
	],

	# The end, and it passes you up the building exactly as Ahmed passed you to
	# him. Khaled is the name on the top floor.
	"concede": [
		{"text": "I'm escalating this. To Khaled.",
			"voice": VOICE + "concede_1.wav"},
	],
}
