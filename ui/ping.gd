extends RefCounted
## DESIGN.md's ping colours, for every screen that shows a ping: the lobby's
## seats, the run's corner and the scoreboard (DESIGN.md's *Ping, the
## Counter-Strike way*). Green under 60 ms, amber under 120, red above, and
## the menu's dim for a ping not measured yet. Here, one level above the three
## features that read it, by the placement rule.

const GOOD := Color("6fdc6f")
const MID := Color("e8b84a")
const BAD := Color("e85a4a")
## The menu theme's dim (tools/build_ui_theme.gd's TEXT_DIM).
const UNKNOWN := Color("987a68")


static func colour(ms: int) -> Color:
	if ms < 0:
		return UNKNOWN
	if ms < 60:
		return GOOD
	if ms < 120:
		return MID
	return BAD
