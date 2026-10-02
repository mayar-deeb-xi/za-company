extends RefCounted
## The Windows install step: hand the verified installer to Inno Setup and get
## out of its way.
##
## Setup upgrades the existing install in place - its AppId is fixed
## (tools/release/installer.iss) - and keeps the install mode it was first
## given (UsePreviousPrivileges): a per-user install updates with no prompt,
## an all-users one shows Windows' admin prompt. /RELAUNCH=1 is ours, not
## Inno's: the script's [Code] reads it and starts the game again when Setup
## is done. The facade quits the game straight after this returns, because
## Setup cannot overwrite an exe that is still running (and CloseApplications
## covers the moment it takes the game to go).
##
## A file the game downloaded itself carries no browser "from the internet"
## mark, so SmartScreen is not expected to stop Setup - todo.md's Part D
## checks that on a real PC.

const ASSET_SUFFIX := "-windows-setup.exe"
## What Inno Setup leaves beside an installed exe, and a portable copy lacks.
const UNINSTALLER := "unins000.exe"
const SETUP_ARGS := ["/SILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/CLOSEAPPLICATIONS", "/RELAUNCH=1"]


## "" when the running copy at `executable_path` can replace itself, else a
## short reason it cannot (the player gets the browser link instead).
static func refusal(executable_path: String) -> String:
	if not FileAccess.file_exists(executable_path.get_base_dir().path_join(UNINSTALLER)):
		return "a portable copy updates by download"
	return ""


## Installs the verified download at `package_path` over the copy at
## `executable_path` and arranges for the new version to start. Returns ""
## when that is under way - the facade then quits the game - or a reason it
## failed, which falls back to the browser link.
static func install(package_path: String, _executable_path: String) -> String:
	if not FileAccess.file_exists(package_path):
		return "the installer is missing"
	if OS.create_process(package_path, SETUP_ARGS) <= 0:
		return "could not start the installer"
	return ""
