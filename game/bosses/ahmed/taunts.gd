extends RefCounted
## What Ahmed shouts, and the whole file is data - `game/bosses/boss_lines.gd`
## is the only thing that reads it, and the only thing that decides when.
##
## Lives with the mouth it comes out of, on the placement rule an NPC's own
## conversation already follows. He is the relative who brought an axe to a
## performance review: entitled, loud, and quite sure this is all HR's fault.
## Nothing he says is a threat the fight does not already make - the axe is the
## threat - so the lines are all attitude, which is what makes the one at the
## bottom of the file land.
##
## ## Cues
##
## `boss_base` fires `spot`, `hurt`, `stagger` and `concede`, plus `taunt` when
## the player keeps their distance, plus one named after each attack as it
## winds up - so `chop`, `sweep`, `slam` and `wave` are HIS, off his own attack
## ids, and a boss with different attacks names different cues by having them.
##
## A cue with no entry here is a cue he has nothing to say on, which is legal
## and silent.
##
## ## Adding the voice
##
## Every line may carry `"voice"`, a path to its recording, and that is the
## whole of what this file needs when the clips arrive - the player, the
## timing and the fitting of the subtitle to the clip's length are all built
## (see boss_lines.gd). A line with no clip, or one naming a file that is not
## there yet, plays nothing and reads on its own time.

const LINES := {
	# He has noticed you. Jumps every queue, so it lands on the frame he
	# looks up whatever else is going on.
	"spot": [
		{"text": "There he is. The new hire."},
		{"text": "You're late. Sit down. This is your review."},
	],

	# Kept out of his reach and staying there. The one cue that is about the
	# player's behaviour rather than his own.
	"taunt": [
		{"text": "Get over here!"},
		{"text": "Come here, coward!"},
		{"text": "Don't run away from me!"},
		{"text": "Let's fight! Or are you busy?"},
		{"text": "Stand still. This is a conversation."},
		{"text": "Where are you going? We're not finished!"},
		{"text": "Twenty years I've been here. Twenty!"},
	],

	# One per attack, said on the wind-up - so the shout is part of the
	# telegraph rather than a comment on it.
	"chop": [
		{"text": "This is for your attitude!"},
		{"text": "Take it! Take it like a professional!"},
	],
	"sweep": [
		{"text": "Hold still!"},
		{"text": "Closer. Come on."},
	],
	"slam": [
		{"text": "EVERYBODY DOWN!"},
		{"text": "This is MY floor!"},
	],
	"wave": [
		{"text": "You can't run from fire!"},
		{"text": "Burn, then!"},
	],

	"hurt": [
		{"text": "That's all you have?"},
		{"text": "You'll pay for that. In writing."},
		{"text": "Do you know who my brother is?"},
	],

	# An interrupt. He is not hurt, he is INSULTED - the swing died, and the
	# line is about the swing.
	"stagger": [
		{"text": "Enough!"},
		{"text": "That was lucky. That was luck."},
	],

	# The end, and the one line DESIGN.md wrote for him. Alone in its cue on
	# purpose: there is no second thing to say here, and jumping the queue is
	# what makes sure it is the last thing heard.
	"concede": [
		{"text": "I'm telling Mostafa."},
	],
}
