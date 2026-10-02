extends RefCounted
## The macOS install step - NOT BUILT YET. This stub refuses, so a Mac player
## gets the browser link, exactly as before the updater existed. Replacing it
## is todo.md's Part C, and it is the only file that part changes.
##
## The three members below are the whole contract with ui/update/updater.gd
## (todo.md, section 4). Keep their names and signatures; fill in the bodies.

## The end of the release file this platform downloads (release.yml writes it).
const ASSET_SUFFIX := "-macos.dmg"

const NOT_YET := "the macOS updater is not built yet (todo.md Part C)"


## "" when the running copy at `executable_path` can replace itself, else a
## short reason it cannot (the player gets the browser link instead).
static func refusal(_executable_path: String) -> String:
	return NOT_YET


## Installs the verified download at `package_path` over the copy at
## `executable_path` and arranges for the new version to start. Returns ""
## when that is under way - the facade then quits the game - or a reason it
## failed, which falls back to the browser link.
static func install(_package_path: String, _executable_path: String) -> String:
	return NOT_YET
