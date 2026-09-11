extends RefCounted
## HR's induction: the tour of the lobby and the contract at the end of it.
## Data only, read by game/dialogue/dialogue_director.gd, which documents every
## key a beat may carry.
##
## ## The walk is the tour
##
## Each `walk` here is a real position in `tools/biomes/lobby.gd` - the sign-in
## desks, reception, the cooler - so the guide stops AT the thing she is talking
## about and the player, towed along behind by `escort`, is looking at it while
## she does. Move a prop in the biome and the line stops landing; the two files
## are a pair, and this is the one that has to follow.
##
## The route ends where it began, at her post. A room keeps no state (see the
## root CLAUDE.md), so an induction that ends anywhere else would leave her
## standing in the middle of the floor for a player who walks back in.
##
## ## The contract cannot be refused
##
## That is the joke and it is load-bearing, so it is built rather than written:
## REFUSE does not end the conversation, it goes to the next offer, and the
## third offer loops to itself forever. There is exactly one way out of this
## room's induction and it is signing. Each refusal gets its own beat instead of
## a counter, because the runner holds no variables - which keeps a conversation
## a list of lines rather than a little program, and costs three labels.
##
## The agreement itself is `ui/contract/contract_panel.tscn`, raised by `show`
## and taken away by `hide`: fifteen lines of randomly generated letters under
## an English header. Reading it is an option, and reading it changes nothing,
## which is the same gag told a second way.

const BEATS := [
	{
		"name": "HR",
		"text": "There you are! The new hire. We were beginning to think you'd "
			+ "taken the other offer.",
	},
	{"text": "I'm HR. Just HR."},
	{
		"text": "We retired first names in Q2. They were creating attachment.",
		"options": [
			{"text": "NICE TO MEET YOU", "goto": "tour"},
			{"text": "JUST... HR?", "goto": "just_hr"},
		],
	},

	{
		"id": "just_hr",
		"text": "A person can leave. A department can't. It tested very well.",
	},

	{
		"id": "tour",
		"text": "Let me show you around. Induction is four minutes, and I've "
			+ "already started the clock.",
	},

	# The sign-in workstations, bottom-left of the lobby.
	{"walk": Vector2(180, 228), "escort": true},
	{"text": "Sign-in. Every morning at 8:59. Not 9:00 - 8:59. The system logs "
		+ "the difference and I read the log."},

	# The front desk, where Dominique will one day be standing.
	{"walk": Vector2(196, 122), "escort": true},
	{"text": "Reception. Dominique is lovely, you'll adore her."},
	{"text": "Eleven years now. She came in for a two-week contract."},

	# The water cooler on the far wall.
	{"walk": Vector2(408, 112), "escort": true},
	{"text": "Water! Free, filtered, and metered - for hydration insights. "
		+ "You'll get a monthly summary."},

	# Back to her post, which is where she has to end up: the room is rebuilt
	# on every entry, so wherever she stops is where she starts next time.
	{"walk": Vector2(356, 226), "escort": true},
	{"text": "And that's the tour. You're practically family. Family who "
		+ "badge in."},
	{"text": "Which brings us to the one small formality."},

	{
		"id": "offer",
		"text": "Your employment agreement. Sign at the bottom and you're one "
			+ "of us.",
		"options": [
			{"text": "SIGN IT", "goto": "signed"},
			{"text": "NOT RIGHT NOW", "goto": "refuse_1"},
			{"text": "CAN I READ IT FIRST?", "goto": "read"},
		],
	},
	{
		"id": "refuse_1",
		"text": "Oh, it's so simple. Just sign it.",
		"goto": "offer_2",
	},

	{
		"id": "offer_2",
		"text": "Here's a pen. Here's the line. Here's you, signing it.",
		"options": [
			{"text": "SIGN IT", "goto": "signed"},
			{"text": "STILL NO", "goto": "refuse_2"},
			{"text": "LET ME READ IT", "goto": "read"},
		],
	},
	{
		"id": "refuse_2",
		"text": "It's so simple. Just sign it. Everyone else did, and look at "
			+ "them.",
		"goto": "offer_3",
	},

	# The last offer loops to itself: there is no beat after this one that is
	# not signing, which is the whole of the joke.
	{
		"id": "offer_3",
		"text": "I'm told I have to let you decide. So decide.",
		"options": [
			{"text": "SIGN IT", "goto": "signed"},
			{"text": "NO", "goto": "refuse_3"},
			{"text": "WHAT AM I SIGNING?", "goto": "read"},
		],
	},
	{
		"id": "refuse_3",
		"text": "It's so simple. Just sign it.",
		"goto": "offer_3",
	},

	{"id": "read", "show": "res://ui/contract/contract_panel.tscn"},
	{"name": "YOU", "text": "...this isn't English."},
	{"name": "HR", "text": "It's the standard agreement."},
	{"name": "YOU", "text": "It's letters. It's just letters."},
	{
		"name": "HR",
		"text": "It's legally just letters. Our counsel is very proud of it - "
			+ "nothing in there has ever been successfully disputed.",
	},
	{"name": "YOU", "text": "Because nobody can read it."},
	{"name": "HR", "text": "Because nobody can read it!"},
	{"hide": true, "goto": "offer_2"},

	{"id": "signed", "name": "HR", "text": "Wonderful. Wonderful!"},
	{"text": "Your desk is upstairs. Take the stairs - the elevator is "
		+ "aspirational."},
	{"text": "And if anyone comes past shouting, in a lanyard, holding "
		+ "something heavy: that's normal. Smile at them."},
	{"text": "Welcome to the company."},
]
