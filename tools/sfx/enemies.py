"""What the bestiary sounds like, enemy by enemy. The recipe, not the engine.

`make.py` is the mechanism; this is the data, the same split every generated
thing in this project uses - `roster.gd` to `build_enemies.gd`, `ahmed.py` to
`cut.py`, `tools/biomes/<level>.gd` to `build_levels.gd`.

## Every enemy owns its sounds, exactly as it owns its sheet

This is the sheet rule from game/enemies/CLAUDE.md applied to the other sense.
The seven characters share one body forever because they play the same game
with the same moves; enemies are each heading somewhere different, so each has
`game/enemies/<id>/src/<id>.png` of its own. Sound is the same bargain: the
archetype's BEHAVIOUR is shared (`wraith_base.gd` runs both drainers), and
nothing about how it sounds is.

So a reskin is not a recolour here either. `office_boy` is mechanically the
regular down to the last frame of its wind-up, and it must not sound like it:
the regular swings a sword, the office boy THRUSTS a wrench (that is drawn
into his sheet, see his section in game/enemies/CLAUDE.md), and a thrust that
rings like a blade is the animation telling the truth while the audio lies.
That is the whole content of this file - seven characters, not four.

## The cues are the base's, and they arrive by existing

`enemy_base.gd` fires `windup`, `hit`, `hurt`, `stagger` and `die`, and
`wraith_base.gd` adds the `drain` loop. Nothing below is wired by hand: an
enemy gets a cue by owning a file of that name, and an enemy that owns none is
silent with no branch anywhere. Which cues a type can actually reach follows
from the fight rather than from a choice made here:

- the wraith and its reskin opt out of the attack cycle entirely
  (`_attacks()` false), so they have no wind-up to telegraph, no blow to land
  and - the thing that surprises - nothing to STAGGER. Three cues each.
- everything else runs the full cycle. Five cues each. `security` is the one
  entry here that is not a reskin of another - the fourth archetype - so its
  five are written from the fight rather than adapted from a sibling's.

## Levels are relative, and the whole room is the reason

There is no audio bus layout and no volume setting, so a file's own level IS
the mix (root CLAUDE.md, Music). The bosses were levelled first and the
enemies are levelled UNDER them, which is not deference - it is arithmetic. A
boss floor holds one boss; hellfire holds four guards, two wraiths and a
warden, and seven bodies mixed at a boss's level is a wall rather than a
fight.

    boss ordinary blow   -19 RMS      (game/bosses/CLAUDE.md, The noise)
    enemy hit            -22 RMS      3 under it, and there are seven of them
    enemy telegraph      -29 RMS      7 under its own impact, the boss's ratio
    the drain loop       -30 RMS      continuous, so it lives near the floor
                                      (Ahmed's idle fire is -34)

The 7 dB between a telegraph and its impact is the one number copied straight
across rather than re-derived: a wind-up as loud as the blow it warns about
has stopped being a warning, and that is true at any absolute level.

## A telegraph is capped, not just levelled

`limit` is the hard ceiling on a clip's LENGTH, and it exists because a
warning still sounding when the blow lands is no warning. Each is set under
the wind-up it plays beneath - 0.45 s for the swing types, 2.0 s for the
warden's charge - with the same margin Ahmed's tightest telegraph got.

The API will not generate under 0.5 s, which is already longer than a guard's
whole wind-up, so the swing telegraphs are asked for long and cut to 0.40 s.
That is the reason `limit` is here at all rather than being a note in a docstring.

## Two clips are frozen the way a take is

`KEEP` names sounds that were listened to and approved. Sound generation is no
more deterministic than text-to-speech, so re-running this must not re-roll
one that is already right. Nothing is frozen yet: these have not been
auditioned. Delete an entry to deliberately re-roll one.

Re-shaping is free and does not touch the performance: `make.py --relevel`
re-trims and re-levels from the untouched exports in `src/sfx/`, which is what
that folder is kept for.
"""

## Where they land. `sfx/` is what the game loads, `src/sfx/` keeps the
## untouched export beside it - the same split the bosses' sounds and the
## music are on. It is `src/sfx/` rather than `src/` because an enemy's `src/`
## already means one documented thing, its hand-owned sheet, and six WAVs
## dropped in beside the PNG would blur a rule someone has to trust.
OUT = "game/enemies/%s/sfx"
RAW = "game/enemies/%s/src/sfx"

MODEL = "eleven_text_to_sound_v2"

## Ahmed's ceiling. Two subsystems, one headroom.
PEAK_CEILING_DB = -3.0

## How literally the model takes the prompt. High enough that "dry, close, no
## music" is obeyed - the default wanders into cinematic beds with reverb
## tails, and a 640x360 room has no space for a tail.
PROMPT_INFLUENCE = 0.55

## cue -> RMS target. See the header for why these numbers and not others.
LEVELS = {
	"windup": -29.0,
	"hit": -22.0,
	"hurt": -24.0,
	"stagger": -23.0,
	"die": -22.0,
	"drain": -30.0,
}

## The tail of every prompt. Said once here rather than six times each: a game
## sound is dry and close, because the room it plays in is 640 px wide and any
## reverb in the file is reverb the game cannot take back out.
STYLE = "dry, close, mono, no music, no reverb tail, game sound effect"

## enemy id -> cue -> spec. Named CAST rather than ENEMIES because make.py is
## the engine for any cast: `player.py` beside this file is a second one.
##   prompt   what to generate, minus STYLE
##   seconds  what to ask the API for; it is padded and then trimmed
##   limit    hard cap on the finished clip, where one is load-bearing
##   loop     seam-crossfaded so the game can loop it
CAST = {
	# The guard, and the sword the interrupt rules were tuned against. He is
	# one of the ORIGINALS, which appear from hellfire up, where the building
	# stops pretending to be an office - so there is an ember under the steel.
	"regular": {
		"windup": {
			"prompt": "a heavy iron sword hauled back for a swing, a short "
				"rising metallic scrape with a low ember hiss under it",
			"seconds": 0.8, "limit": 0.40,
		},
		"hit": {
			"prompt": "a heavy iron blade chopping into a body, one solid "
				"meaty impact with a metal ring on it, single hit",
			"seconds": 1.0,
		},
		"hurt": {
			"prompt": "a short deep male grunt of pain, guttural, one syllable",
			"seconds": 0.8,
		},
		"stagger": {
			"prompt": "a sword swing knocked off line mid-air, a sharp bright "
				"clang of steel struck by steel and a startled breath",
			"seconds": 0.9,
		},
		"die": {
			"prompt": "a heavy armoured body dropping to a stone floor, dead "
				"weight and loose metal, one dull crash",
			"seconds": 1.4,
		},
	},
	# Maintenance. Mechanically the regular to the frame, and it must not
	# sound like it: a WRENCH, thrust along the facing, over a tool belt.
	"office_boy": {
		"windup": {
			"prompt": "a heavy steel wrench cocked back to thrust, tool belt "
				"clinking, one scuff of a work boot on tile",
			"seconds": 0.8, "limit": 0.40,
		},
		"hit": {
			"prompt": "a heavy steel wrench driven hard into a body, one "
				"thick low metal thud on flesh landing on the very first "
				"instant, a loose bolt rattling off it",
			"seconds": 0.7,
		},
		"hurt": {
			"prompt": "a short winded male grunt, tools rattling on a belt",
			"seconds": 0.8,
		},
		"stagger": {
			"prompt": "a steel wrench batted aside, one hard bright clang of "
				"metal on metal on the very first instant, ringing off fast",
			"seconds": 0.7,
		},
		"die": {
			"prompt": "a man going down on a tiled floor with a toolbox, "
				"wrenches and bolts scattering and rolling away, one crash "
				"then clatter",
			"seconds": 1.6,
		},
	},
	# Drained of colour, no attack at all, and the only harm in the game that
	# is simply standing near something. Nothing here is struck.
	"wraith": {
		"drain": {
			"prompt": "a steady unchanging drone of cold air being siphoned "
				"away, a thin hollow whine holding one constant note, an "
				"ambient bed with no beginning and no end, completely even "
				"from start to finish",
			"seconds": 8.0, "steady": 2.5, "loop": True,
		},
		"hurt": {
			"prompt": "one short hollow breathy gasp, a single voice with "
				"almost no tone left in it and nothing else",
			"seconds": 0.7,
		},
		"die": {
			"prompt": "a long cold exhale falling away into nothing, a thin "
				"whine descending and gone",
			"seconds": 1.6,
		},
	},
	# The Content Studio's people. The same drain wearing the floor's neon -
	# the violet moves less than a warm colour under the cold feed tint (see
	# game/enemies/CLAUDE.md), which is one more reason this one is heard.
	"social_media": {
		"drain": {
			"prompt": "one unbroken electronic drone of phone vibration buzz "
				"and static hiss blurred together, a dense continuous texture "
				"with no gaps and no separate events in it, an ambient bed "
				"with no beginning and no end, completely even throughout",
			"seconds": 8.0, "steady": 2.5, "loop": True,
		},
		"hurt": {
			"prompt": "one short female gasp with a brief digital glitch on "
				"it, a single voice and nothing else",
			"seconds": 0.6,
		},
		"die": {
			"prompt": "a phone powering down, a descending digital chime "
				"falling away into a short hiss of static, continuous with "
				"no gaps",
			"seconds": 1.2,
		},
	},
	# Area denial. It deals no damage of any kind, so its impact is not a blow
	# landing - it is 48 px of floor freezing over.
	"warden": {
		"windup": {
			"prompt": "a crystalline frost charge building and rising, ice "
				"crackling outward across a floor, air tightening, ascending "
				"the whole way with no impact at the end",
			"seconds": 2.5, "limit": 1.90,
		},
		"hit": {
			"prompt": "a floor flash-freezing, one sharp ice snap on the very "
				"first instant then frost cracking outward and settling",
			"seconds": 0.9,
		},
		"hurt": {
			"prompt": "one short single grunt of pain through clenched "
				"teeth, a single male voice and nothing else, a thin ice "
				"crackle on it",
			"seconds": 0.6,
		},
		"stagger": {
			"prompt": "a building freeze shattering apart, ice cracking and "
				"collapsing to nothing, one gasp, single hit",
			"seconds": 1.0,
		},
		"die": {
			"prompt": "a frozen body cracking apart, one heavy crack at the "
				"start then sheets of ice falling and breaking on stone, "
				"continuous with no gaps",
			"seconds": 1.2,
		},
	},
	# The phone team's supervisors. Deliberately the most ORDINARY person in
	# the building, because everything frightening about him is the field on
	# the floor - so his sounds are office objects, not a monster.
	"call_center": {
		"windup": {
			"prompt": "a desk phone ringing and swelling louder and louder, "
				"headset static rising with it, tension building the whole "
				"way, never answered",
			"seconds": 2.5, "limit": 1.90,
		},
		"hit": {
			"prompt": "a phone handset slammed down into its cradle and a "
				"flat cheerful hold-music chime landing on top, single hit",
			"seconds": 1.2,
		},
		"hurt": {
			"prompt": "a short startled male grunt with a headset crackle and "
				"a click",
			"seconds": 0.8,
		},
		"stagger": {
			"prompt": "a ringing phone cut off instantly, one sharp click on "
				"the very first instant falling into a flat dead line tone",
			"seconds": 0.9,
		},
		"die": {
			"prompt": "a desk phone dragged off a desk, handset clattering "
				"across the floor and the line going to a flat dead tone",
			"seconds": 1.6,
		},
	},
	# The night shift, and the only enemy in the bestiary that is not a reskin
	# of something. He is twice everyone else's height and his blow lands on a
	# ring of floor rather than in front of him, so the one thing every cue
	# here has to carry is WEIGHT.
	#
	# **Weight is spectrum, not level.** He stays on the shared per-cue levels
	# in LEVELS above - a bigger enemy mixed louder than the rest is how a
	# crowd turns into a wall, which is the whole argument of this file's
	# header, and he debuts standing in the middle of four office boys. So
	# every prompt below asks for LOW content and long decay instead: a deep
	# body under the impact, boots rather than shoes, a chest rather than a
	# throat. At the same -22 RMS that reads as bigger, which is what was
	# wanted, and it costs the room nothing.
	#
	# He is also the one who carries a radio, and it is doing a job rather than
	# being set dressing: his wind-up and his death are the two moments the
	# player needs to tell him apart from the crowd he is standing in, and a
	# squelch is the one sound in the room that belongs to nobody else.
	"security": {
		"windup": {
			# Under the 0.9 s wind-up with the same margin the other two
			# telegraphs take (0.45 -> 0.40, 2.0 -> 1.90). It rises the whole
			# way and must not resolve: the impact is the NEXT cue, and a
			# telegraph that lands its own punch has warned about nothing.
			"prompt": "a very large man hauling both arms up to slam the "
				"floor, heavy boots planting wide on tile, a deep chest "
				"inhale and a low leather creak rising the whole way, one "
				"short radio squelch, no impact at the end",
			"seconds": 1.4, "limit": 0.80,
		},
		"hit": {
			# The slam, and the biggest single impact in the bestiary. "On the
			# very first instant" is the house rule and matters most here: it
			# fires on the frame the ring lands, and a slow transient on a
			# sound this long reads as the blow arriving late.
			"prompt": "an enormous body slamming both fists down onto a hard "
				"floor, one huge deep concussive boom landing on the very "
				"first instant with a sharp crack on top of it, a long low "
				"rumble rolling outward and away, single hit",
			"seconds": 1.4,
		},
		"hurt": {
			# Chestier and lower than the guard's. Same cue, a bigger man.
			"prompt": "one short deep winded grunt from a very large man, "
				"low in the chest, a heavy vest and belt shifting with it, "
				"one syllable",
			"seconds": 0.8,
		},
		"stagger": {
			# His slam broken before it lands, which is the counterplay the
			# interrupt rules exist for - so it has to sound like something
			# STOPPING, not like something hitting.
			"prompt": "a huge wind-up broken off, heavy boots skidding and "
				"scuffing on tile as a big man is knocked off balance, one "
				"grunt, everything cut short on the very first instant",
			"seconds": 1.0,
		},
		"die": {
			# The heaviest fall in the game, and the one that should be
			# audible across the room he was anchoring.
			"prompt": "a very heavy man going down onto a hard floor, one "
				"enormous dead-weight thud with a deep low body under it, a "
				"belt and radio clattering away and a last burst of radio "
				"static cutting out",
			"seconds": 1.8,
		},
	},
}

## (enemy, cue) -> why it was kept. See the header.
KEEP = {}
