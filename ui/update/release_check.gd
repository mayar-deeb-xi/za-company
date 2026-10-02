extends Node
## Which version this is, and whether a newer one is out.
##
## The version is the repository's `VERSION` file, read at runtime rather than
## copied anywhere: every export preset lists it in `include_filter`, so the
## number on the menu and the number a release was published under are the same
## file and cannot drift. RELEASING.md is how that file becomes a release.
##
## The check asks GitHub for the latest release once per run, and only from a
## build carrying the `packaged` feature - the installed Windows and macOS
## games. Never the editor or a test suite (no network in a headless run), and
## never the web build, which is always the newest by being served.
## `/releases/latest` already skips drafts and pre-releases, so a beta never
## nags anyone. Every failure - offline, rate-limited, a malformed answer - is
## silence: an update notice is a courtesy, never something to wait on.
##
## It lives in ui/update/ rather than with the menu because two features read
## it: the menu shows what it found, and the updater installs it.
##
## A developer can point it at one release instead of the latest by starting
## the game with `-- --update-feed=<release API URL>` - that is how an update
## is tested between two pre-releases, which `latest` never returns. A feed
## also asks from an unpackaged run, so the panel can be tried in the editor.

signal newer_found(version: String, url: String)

const LATEST := "https://api.github.com/repos/mayar4ki/za-company/releases/latest"
const VERSION_PATH := "res://VERSION"
const FEED_ARG := "--update-feed="
const TIMEOUT := 6.0

## One ask per run: the menu is rebuilt after every game over, and asking again
## each time would spend GitHub's sixty-an-hour allowance for nothing.
static var _asked := false
static var _found := {}


static func current() -> String:
	var text := FileAccess.get_file_as_string(VERSION_PATH).strip_edges()
	return text if not text.is_empty() else "dev"


## The release the last answer named as newer - its whole JSON, assets
## included, which is what the updater picks its download from. Empty until
## then.
static func found() -> Dictionary:
	return _found.get("release", {})


## The `--update-feed=` URL this run was started with, or "".
static func feed(args := OS.get_cmdline_user_args()) -> String:
	for arg in args:
		if arg.begins_with(FEED_ARG):
			return arg.trim_prefix(FEED_ARG)
	return ""


## True when `remote` is later than `local`, by semver: MAJOR.MINOR.PATCH
## first; on an equal core a release beats its own pre-release
## (1.0.0 > 1.0.0-rc.1); and two pre-releases compare their suffixes part by
## part, numbers as numbers (beta.10 > beta.9). Anything that does not parse
## is never newer, so a junk answer cannot raise a notice.
static func is_newer(remote: String, local: String) -> bool:
	var a := _parse(remote)
	var b := _parse(local)
	if a.is_empty() or b.is_empty():
		return false
	for i in 3:
		if a[i] != b[i]:
			return a[i] > b[i]
	if a[3] == "" or b[3] == "":
		return a[3] == "" and b[3] != ""
	return _suffix_order(a[3], b[3]) > 0


static func _parse(version: String) -> Array:
	var text := version.strip_edges().trim_prefix("v")
	var cut := text.find("-")
	var suffix := "" if cut < 0 else text.substr(cut + 1)
	var parts := (text if cut < 0 else text.left(cut)).split(".")
	if parts.size() != 3:
		return []
	for part in parts:
		if not part.is_valid_int():
			return []
	return [int(parts[0]), int(parts[1]), int(parts[2]), suffix]


## Semver's pre-release precedence: dot-separated parts left to right, a
## numeric part below a word, numbers by value, words alphabetically, and a
## shorter list below a longer one it is the start of (beta < beta.1).
static func _suffix_order(a: String, b: String) -> int:
	var x := a.split(".")
	var y := b.split(".")
	for i in mini(x.size(), y.size()):
		if x[i] == y[i]:
			continue
		var x_num := x[i].is_valid_int()
		var y_num := y[i].is_valid_int()
		if x_num and y_num:
			return 1 if int(x[i]) > int(y[i]) else -1
		if x_num != y_num:
			return -1 if x_num else 1
		return 1 if x[i] > y[i] else -1
	return signi(x.size() - y.size())


func _ready() -> void:
	if not _found.is_empty():
		newer_found.emit.call_deferred(_found["version"], _found["url"])
		return
	var from := feed()
	if _asked or (from.is_empty() and not OS.has_feature("packaged")):
		return
	_asked = true
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	add_child(http)
	http.request_completed.connect(_on_answer)
	http.request(LATEST if from.is_empty() else from, ["Accept: application/vnd.github+json"])


func _on_answer(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	take(body.get_string_from_utf8())


## The answer, separated from the asking so a test can hand it one.
func take(json: String) -> void:
	# An instance parse, not JSON.parse_string: that one logs an engine error
	# for every bad answer, and a bad answer is nothing worth a line in a log.
	var parser := JSON.new()
	if parser.parse(json) != OK or not parser.data is Dictionary:
		return
	var release: Dictionary = parser.data
	var tag := String(release.get("tag_name", ""))
	var url := String(release.get("html_url", ""))
	if url.begins_with("https://github.com/") and is_newer(tag, current()):
		_found = {"version": tag.trim_prefix("v"), "url": url, "release": release}
		newer_found.emit(_found["version"], url)
