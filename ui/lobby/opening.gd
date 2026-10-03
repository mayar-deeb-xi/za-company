extends RefCounted
## Which of the lobby's screens a trip to it opens on: the main menu's JOIN
## ONLINE asks for the list of games, its HOST ONLINE for the host screen, and
## the character select sits between the two either way.
##
## A file of its own rather than a static on lobby.gd, so the main menu can say
## it without loading the lobby - and through it the whole game - at startup.
## Spent on use, like the character select's `next_scene`.

enum View { JOIN, HOST }

static var view := View.JOIN


## The view asked for, and back to the default for whoever comes next.
static func take() -> View:
	var asked := view
	view = View.JOIN
	return asked
