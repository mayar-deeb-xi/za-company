extends "res://tests/helpers.gd"
## The in-game updater's shared core and its Windows step (todo.md Parts A
## and B), with no network: releases, checksum lists and installs are handed
## in, and the one real file it hashes is written and deleted here.
##
## The headline checks are the two that protect players rather than code:
## the switch (off means every copy keeps the browser link - "both platforms
## or neither") and the name contract (a release file renamed in the workflow
## without the updater knowing would strand every installed copy on its old
## version, silently). Everything that would really install is left to
## todo.md's Part D, on real machines.

const Updater := preload("res://ui/update/updater.gd")
const Download := preload("res://ui/update/update_download.gd")
const Windows := preload("res://ui/update/update_install_windows.gd")
const MacOS := preload("res://ui/update/update_install_macos.gd")
## Loaded when first used rather than preloaded: the panel's script names the
## UiSound autoload, and this file is compiled before autoloads exist.
var UpdatePanel: PackedScene

const SCRATCH := "user://test_updater"
const FEED := "https://api.github.com/repos/mayar4ki/za-company/releases/tags/v9.9.9-beta.1"
const HELLO_SHA256 := "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"

var _failures: Array[String] = []
var _opened: Control
var _sticky: Control


func _tick(frame: int) -> void:
	match frame:
		4:
			_switch()
			_windows_refusal()
			_picking()
			_checksums()
			_contract()
			_start_without_files()
			_panel_states()
		8:
			_check("start: a release with nothing for this OS fails, and says so (%s)" % [_failures],
				_failures.size() == 1 and _failures[0].begins_with("this release has nothing to install"))
			_check("panel: and it is gone", not is_instance_valid(_opened))
			_check("panel: while installing it cannot be closed",
				is_instance_valid(_sticky) and _sticky.get("state") == 1)
			_sticky.free()
			_cleanup()
			_finish()


func _switch() -> void:
	_check("switch: off until todo.md Part D", not Updater.ENABLED)
	_check("switch: a normal run is off", not Updater.switched_on(""))
	_check("switch: a feed turns it on for that run", Updater.switched_on(FEED))
	_check("switch: off means the link, on any OS (%s)" % Updater.refusal("Windows", "C:/x/TheNewHire.exe", ""),
		Updater.refusal("Windows", "C:/x/TheNewHire.exe", "") == "the in-game updater is switched off"
		and Updater.refusal("macOS", "/Applications/x", "") == "the in-game updater is switched off")
	_check("platform: Windows and macOS have a step, nothing else does",
		Updater.platform("Windows") == Windows and Updater.platform("macOS") == MacOS
		and Updater.platform("Web") == null and Updater.platform("Linux") == null)
	_check("platform: no step means the link (%s)" % Updater.refusal("Linux", "/x", FEED),
		Updater.refusal("Linux", "/x", FEED).begins_with("there is no in-game updater"))
	_check("macOS: the stub refuses until Part C (%s)" % Updater.refusal("macOS", "/Applications/x", FEED),
		Updater.refusal("macOS", "/Applications/x", FEED) == MacOS.NOT_YET
		and MacOS.install("/x.dmg", "/x") == MacOS.NOT_YET)
	_check("feed: read from the command line's user args",
		ReleaseCheck_feed(["--other", "--update-feed=" + FEED]) == FEED
		and ReleaseCheck_feed(["--update-feed"]) == "" and ReleaseCheck_feed([]) == "")


static func ReleaseCheck_feed(args: Array) -> String:
	return Updater.ReleaseCheck.feed(PackedStringArray(args))


func _windows_refusal() -> void:
	var installed := _scratch_dir("installed")
	_touch(installed.path_join("TheNewHire.exe"))
	_touch(installed.path_join(Windows.UNINSTALLER))
	var portable := _scratch_dir("portable")
	_touch(portable.path_join("TheNewHire.exe"))
	_check("windows: an installed copy may update itself",
		Windows.refusal(installed.path_join("TheNewHire.exe")) == "")
	_check("windows: so the facade agrees, with the feed on",
		Updater.refusal("Windows", installed.path_join("TheNewHire.exe"), FEED) == "")
	_check("windows: a portable copy keeps the link (%s)" % Windows.refusal(portable.path_join("TheNewHire.exe")),
		Windows.refusal(portable.path_join("TheNewHire.exe")) != "")
	_check("windows: a missing installer is a reason, not a crash",
		Windows.install(installed.path_join("nope-setup.exe"), "") == "the installer is missing")
	_check("windows: Setup is told to stay quiet and start the game again (%s)" % [Windows.SETUP_ARGS],
		"/SILENT" in Windows.SETUP_ARGS and "/RELAUNCH=1" in Windows.SETUP_ARGS
		and "/CLOSEAPPLICATIONS" in Windows.SETUP_ARGS)


func _picking() -> void:
	var assets := _assets("9.9.9")
	_check("pick: Windows takes the installer, not the portable zip",
		Download.pick(assets, Windows.ASSET_SUFFIX).get("name") == "TheNewHire-9.9.9-windows-setup.exe")
	_check("pick: macOS takes the disk image",
		Download.pick(assets, MacOS.ASSET_SUFFIX).get("name") == "TheNewHire-9.9.9-macos.dmg")
	_check("pick: the checksum list by name",
		Download.named(assets, Download.SUMS).get("name") == "SHA256SUMS.txt")
	_check("pick: nothing to pick is {}, not a guess",
		Download.pick([], Windows.ASSET_SUFFIX).is_empty()
		and Download.pick([{"name": "notes.txt"}, "junk"], MacOS.ASSET_SUFFIX).is_empty())


func _checksums() -> void:
	var lines := "\n".join([
		"%s  TheNewHire-9.9.9-windows-setup.exe" % HELLO_SHA256,
		"%s *TheNewHire-9.9.9-macos.dmg" % HELLO_SHA256.to_upper(),
		"not a checksum line",
		"abc  short-hash.zip",
	])
	var sums := Download.parse_sums(lines)
	_check("sums: both sha256sum modes, junk skipped (%s)" % [sums.keys()],
		sums.size() == 2 and sums.get("TheNewHire-9.9.9-windows-setup.exe") == HELLO_SHA256
		and sums.get("TheNewHire-9.9.9-macos.dmg") == HELLO_SHA256)
	var path := _scratch_dir("hash").path_join("hello.bin")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("hello")
	f.close()
	_check("hash: SHA-256 of a known file (%s)" % Download.sha256_file(path),
		Download.sha256_file(path) == HELLO_SHA256)
	_check("hash: it matches its line, in either case",
		Download.matches(path, HELLO_SHA256) and Download.matches(path, HELLO_SHA256.to_upper()))
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("hellp")
	f.close()
	_check("hash: one byte different is refused", not Download.matches(path, HELLO_SHA256))
	_check("hash: no line to match is refused", not Download.matches(path, ""))
	_check("hash: an unreadable file is refused", not Download.matches(path + ".missing", HELLO_SHA256))


## The release file names are written in two places - the workflow and the
## installer script - and read in one: each platform's ASSET_SUFFIX.
func _contract() -> void:
	var workflow := FileAccess.get_file_as_string("res://.github/workflows/release.yml")
	var installer := FileAccess.get_file_as_string("res://tools/release/installer.iss")
	_check("contract: the workflow and the installer script read",
		workflow.length() > 0 and installer.length() > 0)
	_check("contract: Inno writes the name Windows looks for",
		installer.contains("OutputBaseFilename=TheNewHire-{#AppVersion}" + Windows.ASSET_SUFFIX.trim_suffix(".exe")))
	_check("contract: the workflow names the dmg as macOS looks for it",
		workflow.contains("TheNewHire-${VERSION}" + MacOS.ASSET_SUFFIX))
	_check("contract: the workflow publishes the checksum list",
		workflow.contains("> " + Download.SUMS))


func _start_without_files() -> void:
	var updater := Updater.new()
	current_scene.add_child(updater)
	updater.failed.connect(func(reason: String) -> void: _failures.append(reason))
	updater.start({"assets": [{"name": "notes.txt", "browser_download_url": "https://example.com/x"}]})


func _panel_states() -> void:
	var play := current_scene.get_node("%PlayButton") as Button
	if UpdatePanel == null:
		UpdatePanel = load("res://ui/update/update_panel.tscn")
	_opened = UpdatePanel.instantiate()
	current_scene.add_child(_opened)
	_opened.call("open", {}, "9.9.9", "https://github.com/x", play, false)
	_check("panel: opens downloading, with CANCEL focused (%s)" % _opened.get_node("%Status").text,
		_opened.get_node("%Status").text == "DOWNLOADING v9.9.9"
		and (_opened.get_node("%CancelButton") as Button).has_focus())
	_opened.call("_on_progressed", 512 * 1024, 1024 * 1024)
	_check("panel: progress in MB (%s, %.2f)" % [_opened.get_node("%Detail").text, _opened.get_node("%Progress").value],
		_opened.get_node("%Detail").text == "0.5 OF 1.0 MB" and is_equal_approx(_opened.get_node("%Progress").value, 0.5))
	_opened.call("_on_failed", "the download failed")
	_check("panel: a failure offers the link, focused, and CLOSE",
		(_opened.get_node("%LinkButton") as Button).visible and (_opened.get_node("%LinkButton") as Button).has_focus()
		and (_opened.get_node("%CloseButton") as Button).visible and not (_opened.get_node("%CancelButton") as Button).visible)
	var box := _opened.get_node("CenterContainer/Panel") as Control
	_check("panel: fits the 640x360 screen (%s)" % box.get_combined_minimum_size(),
		box.get_combined_minimum_size().x <= 640 and box.get_combined_minimum_size().y <= 360)
	_opened.call("close")
	# Checked now, before the second panel below takes focus for itself.
	_check("panel: closing it hands focus back (%s)" % play.get_viewport().gui_get_focus_owner(),
		play.has_focus())

	_sticky = UpdatePanel.instantiate()
	current_scene.add_child(_sticky)
	_sticky.call("open", {}, "9.9.9", "https://github.com/x", null, false)
	_sticky.call("_on_installing")
	_sticky.call("close")


func _assets(version: String) -> Array:
	var out := []
	for file_name in ["TheNewHire-%s-windows-setup.exe", "TheNewHire-%s-windows-portable.zip",
			"TheNewHire-%s-macos.dmg"]:
		var name_now: String = file_name % version
		out.append({"name": name_now, "browser_download_url": "https://github.com/x/" + name_now})
	out.append({"name": "SHA256SUMS.txt", "browser_download_url": "https://github.com/x/SHA256SUMS.txt"})
	return out


func _scratch_dir(sub: String) -> String:
	var path := ProjectSettings.globalize_path(SCRATCH.path_join(sub))
	DirAccess.make_dir_recursive_absolute(path)
	return path


static func _touch(path: String) -> void:
	FileAccess.open(path, FileAccess.WRITE).close()


## Everything this suite wrote, and nothing else: user:// belongs to the
## developer (CLAUDE.md, Testing).
func _cleanup() -> void:
	var root := ProjectSettings.globalize_path(SCRATCH)
	for sub in ["installed", "portable", "hash"]:
		var dir := DirAccess.open(root.path_join(sub))
		if dir != null:
			for file_name in dir.get_files():
				dir.remove(file_name)
			DirAccess.remove_absolute(root.path_join(sub))
	DirAccess.remove_absolute(root)
	_check("cleanup: nothing left in user:// (%s)" % SCRATCH, not DirAccess.dir_exists_absolute(root))
