extends Node
## The web build's first scene (project.godot's `run/main_scene.web`): in a
## browser the ADDRESS decides what opens, because a page has no command line.
## `#nettest` and `#join=CODE` open M0's test screen (ui/net_spike/); anything
## else is the main menu, exactly as on desktop. It lasts one frame.
##
## A scene of its own rather than a branch in the main menu, so desktop never
## loads it and the menu never learns the web build has a second front door.

const MAIN_MENU := "res://ui/main_menu/main_menu.tscn"
const NET_SPIKE := "res://ui/net_spike/net_spike.tscn"


func _ready() -> void:
	get_tree().change_scene_to_file.call_deferred(NET_SPIKE if wants_net_spike() else MAIN_MENU)


static func wants_net_spike() -> bool:
	if not OS.has_feature("web"):
		return false
	var hash := String(JavaScriptBridge.eval("window.location.hash", true))
	return hash.begins_with("#nettest") or hash.begins_with("#join=")
