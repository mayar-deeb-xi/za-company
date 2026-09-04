extends SceneTree
## Runs every test file, each in its own Godot process - which is the point of
## the split: one file, one clean world.
##
## Run: <godot> --headless --path . --script res://tests/run_all.gd
## Exits 0 only when every suite passed. Uses its own executable to spawn the
## children, so it needs no knowledge of where the binary lives; --fixed-fps is
## passed here so the individual commands stay copy-pasteable without it only
## when run through this.

const SUITES := ["test_menu", "test_flow", "test_combat"]


func _initialize() -> void:
	var project := ProjectSettings.globalize_path("res://")
	var failed: Array[String] = []
	for suite in SUITES:
		print("\n=== %s ===" % suite)
		var output := []
		var code := OS.execute(OS.get_executable_path(),
			["--headless", "--path", project, "--fixed-fps", "60",
				"--script", "res://tests/%s.gd" % suite],
			output, true)
		for chunk in output:
			print(chunk)
		if code != 0:
			failed.append(suite)
	print("\n=== ALL SUITES: %s ===" % ("PASS" if failed.is_empty()
		else "FAIL -> " + ", ".join(failed)))
	quit(0 if failed.is_empty() else 1)
