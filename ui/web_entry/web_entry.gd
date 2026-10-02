extends Node
## The web build's first scene (project.godot's `run/main_scene.web`): in a
## browser the ADDRESS decides what opens, because a page has no command line.
## `#join=CODE` - the link a host's lobby hands out - opens the lobby
## (ui/lobby/), which joins that room on arrival; anything else is the main
## menu, exactly as on desktop. It lasts one frame.
##
## A scene of its own rather than a branch in the main menu, so desktop never
## loads it and the menu never learns the web build has a second front door.

const MAIN_MENU := "res://ui/main_menu/main_menu.tscn"
const LOBBY := "res://ui/lobby/lobby.tscn"


func _ready() -> void:
	get_tree().change_scene_to_file.call_deferred(LOBBY if wants_lobby() else MAIN_MENU)


static func wants_lobby() -> bool:
	if not OS.has_feature("web"):
		return false
	var hash := String(JavaScriptBridge.eval("window.location.hash", true))
	return hash.begins_with("#join=")
