extends RefCounted
## What the phone team says while you are standing in its field. The whole file
## is data - `game/enemies/enemy_lines.gd` is the only thing that reads it, and
## the only thing that decides when.
##
## Lives with the mouth it comes out of, the placement rule a boss's taunts.gd
## and an NPC's conversation already follow.
##
## ## He is being helpful, and that is the threat
##
## He is a warden: he deals no damage of any kind, and what he does instead is
## take four seconds of your speed away. He is also, deliberately, the most
## ORDINARY-looking person in the building - grey button-up, navy slacks, no
## beard - because everything frightening about him is the field on the floor
## and not him (see this folder's CLAUDE.md).
##
## The lines are written to that exact brief, so **none of them is a threat**.
## They are the things a call centre actually says to you, said kindly, by
## somebody whose entire mechanical purpose is to make you wait. "You're not
## going anywhere" is a reassurance and a description of the slow at the same
## time, and it only works because the seven around it are sincere. A line that
## dropped the mask would turn him into a small boss, which is the one thing
## the character is built not to be.
##
## Kept SHORT for the reason social_media/mutters.gd gives: a mutter plays
## under a fight at -31 dBFS with no subtitle behind it.

const VOICE := "res://game/enemies/call_center/sfx/voice/"

const LINES := {
	# One cue, polled. enemy_lines.gd picks at random and never twice running.
	"mutter": [
		{"text": "Please hold.", "voice": VOICE + "mutter_1.wav"},
		{"text": "Your call is very important to us.",
			"voice": VOICE + "mutter_2.wav"},
		{"text": "Someone will be with you shortly.",
			"voice": VOICE + "mutter_3.wav"},
		{"text": "Just a moment. Take a seat.", "voice": VOICE + "mutter_4.wav"},
		{"text": "There's no need to rush.", "voice": VOICE + "mutter_5.wav"},
		{"text": "You're number four in the queue.",
			"voice": VOICE + "mutter_6.wav"},
		# The two that are the slow, described as a kindness.
		{"text": "I can keep you waiting all day.",
			"voice": VOICE + "mutter_7.wav"},
		{"text": "Relax. You're not going anywhere.",
			"voice": VOICE + "mutter_8.wav"},
	],
}
