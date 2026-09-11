extends RefCounted
## What Ahmed shouts, and the whole file is data - `game/enemies/enemy_lines.gd`
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
## ## The voice
##
## Every line carries its recording, and they are all cut: Eleven v3, one
## voice, with the DELIVERY tagged per cue rather than left to a stability
## slider - `[furious, roaring]` for a taunt, `[contemptuous, sneering]` when
## he first looks up, `[defeated, bitter, muttering]` for the last line. The
## tags are not in this file because they are not what he says; they are how
## it was said, and they live in the generator beside the rest of the recipe.
##
## Nothing here had to change for the audio to work - `enemy_lines.gd` already
## played a clip and already fitted the subtitle to its length. A line whose
## file is missing, or a checkout before the import pass, still reads on its
## own time and plays nothing.

## Where his recordings live. A prefix rather than twenty-three copies of one
## path: a folder spelled out on every line is a folder that cannot be moved.
const VOICE := "res://game/bosses/ahmed/sfx/voice/"

const LINES := {
	# He has noticed you. Jumps every queue, so it lands on the frame he
	# looks up whatever else is going on.
	"spot": [
		{"text": "There he is. The new hire.", "voice": VOICE + "spot_1.wav"},
		{"text": "You're late. Sit down. This is your review.",
			"voice": VOICE + "spot_2.wav"},
	],

	# Kept out of his reach and staying there. The one cue that is about the
	# player's behaviour rather than his own.
	"taunt": [
		{"text": "Get over here!", "voice": VOICE + "taunt_1.wav"},
		{"text": "Come here, coward!", "voice": VOICE + "taunt_2.wav"},
		{"text": "Don't run away from me!", "voice": VOICE + "taunt_3.wav"},
		{"text": "Let's fight! Or are you busy?",
			"voice": VOICE + "taunt_4.wav"},
		{"text": "Stand still. This is a conversation.",
			"voice": VOICE + "taunt_5.wav"},
		{"text": "Where are you going? We're not finished!",
			"voice": VOICE + "taunt_6.wav"},
		{"text": "Twenty years I've been here. Twenty!",
			"voice": VOICE + "taunt_7.wav"},
	],

	# One per attack, said on the wind-up - so the shout is part of the
	# telegraph rather than a comment on it.
	"chop": [
		{"text": "This is for your attitude!", "voice": VOICE + "chop_1.wav"},
		{"text": "Take it! Take it like a professional!",
			"voice": VOICE + "chop_2.wav"},
	],
	"sweep": [
		{"text": "Hold still!", "voice": VOICE + "sweep_1.wav"},
		{"text": "Closer. Come on.", "voice": VOICE + "sweep_2.wav"},
	],
	"slam": [
		{"text": "EVERYBODY DOWN!", "voice": VOICE + "slam_1.wav"},
		{"text": "This is MY floor!", "voice": VOICE + "slam_2.wav"},
	],
	"wave": [
		{"text": "You can't run from fire!", "voice": VOICE + "wave_1.wav"},
		{"text": "Burn, then!", "voice": VOICE + "wave_2.wav"},
	],

	"hurt": [
		{"text": "That's all you have?", "voice": VOICE + "hurt_1.wav"},
		{"text": "You'll pay for that. In writing.",
			"voice": VOICE + "hurt_2.wav"},
		{"text": "Do you know who Mostafa is?",
			"voice": VOICE + "hurt_3.wav"},
	],

	# An interrupt. He is not hurt, he is INSULTED - the swing died, and the
	# line is about the swing.
	"stagger": [
		{"text": "Enough!", "voice": VOICE + "stagger_1.wav"},
		{"text": "That was lucky. That was luck.",
			"voice": VOICE + "stagger_2.wav"},
	],

	# The end, and the one line DESIGN.md wrote for him. Alone in its cue on
	# purpose: there is no second thing to say here, and jumping the queue is
	# what makes sure it is the last thing heard.
	"concede": [
		{"text": "I'm telling Mostafa.", "voice": VOICE + "concede_1.wav"},
	],
}
