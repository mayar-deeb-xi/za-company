[ ] In-game updater for Windows and macOS (details below)

# In-game updater: Windows and macOS

**For the agent doing this task.** Read this whole file first, then
`CLAUDE.md` (the project's rules) and `RELEASING.md` (how releases work
today). Everything you need is here or in a file this one names. Some
decisions are already made, and they are marked **decided**: do not reopen
them without asking the owner.

**Needs a Mac.** The final test is on a real Mac (section 7). Do not mark
this task done, or release it as a normal (non-pre-release) version, until
that test has passed on a Mac and on Windows.

---

## 1. The goal

Today an installed game tells the player a new version exists, and the player
updates by hand. After this task, the player can update **from inside the
game**:

1. The main menu shows that a new version is out (this already works).
2. The player presses **UPDATE NOW**.
3. The game downloads the new version, showing progress, and checks the file.
4. The game installs it and restarts on the new version. Settings are kept.

If anything goes wrong, or the copy cannot update itself, the player gets
today's behaviour instead: a button that opens the release page in the
browser.

## 2. Decided (do not reopen)

- **Both platforms or neither.** Windows and macOS must behave the same. If
  the macOS half cannot be made to work and pass its test, the Windows half
  does not ship either.
- **No server.** Downloads come straight from the GitHub release. Nothing new
  is hosted anywhere.
- **The browser link never goes away.** Every failure, refusal or
  unsupported case falls back to "open the release page". A broken updater
  must never leave a player stuck on an old version with no way forward.
- **Whole-build updates only.** Download and install the full release file.
  Do NOT build a patch system that ships only the game data (`.pck`): it was
  considered and rejected, because engine and plugin changes still need a full
  install, and loading new code into a running game causes subtle bugs.
- **Only the installed Windows copy updates itself.** The portable zip has no
  installer to upgrade, so it keeps the link.
- **Only from the main menu**, never during a run. That is already where the
  check lives.
- **Builds stay unsigned** for now. Signing is a separate, later task
  (RELEASING.md, "Later: signing").
- **Never change `VERSION` yourself.** A `VERSION` change on `main` publishes
  a public release. Testing needs real releases (section 7), so ask the owner for
  the version numbers to use.

## 3. What exists today

Read these before changing anything.

| File | What it does now |
|---|---|
| `ui/main_menu/release_check.gd` | Reads the version from `res://VERSION` (`current()`), compares versions (`is_newer()`), asks `https://api.github.com/repos/mayar4ki/za-company/releases/latest` once per run, and emits `newer_found(version, url)`. It only asks when the build has the `packaged` feature, so it never runs in the editor, the tests or the web build. `take(json)` handles the answer and is what the tests call. |
| `ui/main_menu/main_menu.gd` / `.tscn` | Shows the version in the footer (`%Version`). On `newer_found` it shows `%UpdateButton` ("v0.3.0 IS OUT - GET IT"), which opens the release page in the browser. |
| `tests/test_release.gd` | Checks all of the above with no network: answers are handed to `take()` directly. It also reads `export_presets.cfg` off disk. |
| `.github/workflows/release.yml` | When `VERSION` changes on `main`: builds Windows (installer and portable zip) and macOS (`.dmg`), then publishes the release with the files attached. On `develop`, a push that touches the presets, the workflow or `tools/release/` is a **dry run**: it builds everything, keeps the files on the run's page for a week, and publishes nothing. |
| `tools/release/installer.iss` | The Inno Setup script. Installs per user by default (`PrivilegesRequired=lowest`), and its fixed `AppId` makes a new version upgrade the old one in place. **Never change the `AppId`.** |
| `tools/release/fetch_godot.sh`, `prepare.sh`, `export.sh` | The build steps the workflow runs. |
| `export_presets.cfg` | The Windows and macOS presets carry the custom feature `packaged`. Packaged builds are named "The New Hire" (`application/config/name.packaged` in `project.godot`, written by `tools/setup_project.gd`). |

**The release file names are a contract.** The updater will find its file by
name, so these must not change without updating the updater in the same
commit:

- `TheNewHire-<version>-windows-setup.exe`
- `TheNewHire-<version>-windows-portable.zip`
- `TheNewHire-<version>-macos.dmg`

## 4. Design

### 4a. The release publishes checksums

In `release.yml`'s `publish` job, before `gh release create`, write
`SHA256SUMS.txt` (`sha256sum` over everything in `dist/`) and attach it to
the release. The updater downloads it and refuses to install a file whose
SHA-256 does not match. Use SHA256SUMS.txt even though GitHub's API may also
report a digest per file: the checksum file is under our control and is the
same on every platform.

### 4b. The game side

Split into small files, one job each (the owner prefers small files; see
CLAUDE.md's placement rules). A suggested layout, which you may refine:

- `ui/update/update_panel.tscn` + `update_panel.gd`: the screen shown while
  updating, with a progress bar, MB done of MB total, **CANCEL**, and an error
  state with **OPEN DOWNLOAD PAGE**. It must fit the 640x360 viewport, work
  from the keyboard, and use the shared theme (`ui/theme/menu_theme.tres`,
  which is generated by `tools/build_ui_theme.gd`: never hand-edit it).
  Buttons get their sounds automatically (`autoload/ui_sound.gd`). Where the
  panel handles Escape, call `UiSound.back()`, as the other screens do.
- `ui/update/update_download.gd`: picks the right file from the release JSON,
  downloads it and `SHA256SUMS.txt`, and verifies the hash. Use `HTTPRequest`
  with `download_file` set (to a file under `OS.get_cache_dir()`), progress
  from `get_downloaded_bytes()` / `get_body_size()`, and hash the file in
  chunks with `HashingContext`.
- `ui/update/update_install_windows.gd` and `update_install_macos.gd`: one per
  platform (see 4c and 4d).
- `ui/update/updater.gd`: the facade the menu calls. It answers "can this copy
  update itself?" (`can_update()`), runs download -> verify -> install, and
  reports progress and failures.

Changes to what exists:

- `release_check.gd`: keep the whole release (including `assets`, each with
  `name`, `browser_download_url` and `size`), not only the tag and URL, so the
  updater can find its file. Keep `take()` testable without a network.
- `release_check.gd`'s `is_newer()`: today, two pre-releases of the same
  version never compare as newer (`0.3.0-beta.2` vs `0.3.0-beta.1` gives
  false), which would make the section 7 test show no update at all. Give it
  semver's pre-release ordering: compare the suffix's dot-separated parts,
  numbers as numbers, so `beta.2 > beta.1` and `beta.10 > beta.9`. Keep
  `1.0.0 > 1.0.0-rc.1`, and add the new cases to `test_release.gd`'s table.
- `main_menu.gd`: when the copy can update itself, the button reads
  **"v0.3.0 IS OUT - UPDATE"** and opens the update panel. Otherwise it keeps
  today's text and opens the browser link.
- **Load all of it by `preload`, never `class_name`.** Global class names live
  in an editor cache that a fresh headless checkout does not have (CLAUDE.md
  repeats this).

### 4c. Windows

1. **Decide whether this copy is installed.** An Inno Setup install has
   `unins000.exe` next to the game's exe
   (`OS.get_executable_path().get_base_dir()`). No uninstaller means a
   portable copy, which gets the link.
2. Download `TheNewHire-<version>-windows-setup.exe` and verify it.
3. Start it with `OS.create_process()` and arguments
   `/SILENT /SUPPRESSMSGBOXES /NORESTART /RELAUNCH=1`, then quit the game
   straight away (`get_tree().quit()`), because the installer cannot replace
   an exe that is still running.
4. In `installer.iss`:
   - Add a second `[Run]` entry that relaunches the game **only** when
     `/RELAUNCH=1` was passed. It needs no `postinstall` or `skipifsilent`
     flags, plus a `Check:` function in a `[Code]` section that reads
     `ExpandConstant('{param:RELAUNCH|0}') = '1'`. Keep the existing
     `postinstall` entry for normal interactive installs.
   - Add `CloseApplications=yes`, so if the game has not quite exited yet,
     Setup waits or closes it instead of failing to overwrite it.
   - `UsePreviousPrivileges` (on by default) makes the update use the same
     install mode as before. A per-user install updates silently. An
     all-users install will show Windows' admin prompt (UAC). That is
     acceptable, but check it in section 7.
5. Expect, but verify in section 7, that **no "Windows protected your PC"
   warning** appears. That warning comes from the mark Windows puts on
   browser downloads, and a file the game writes itself does not carry it.

### 4d. macOS

1. **Decide whether this copy can update itself.** Find the `.app` bundle from
   `OS.get_executable_path()` (three levels up from
   `.../The New Hire.app/Contents/MacOS/<binary>`). Fall back to the link when:
   - the path contains `/AppTranslocation/`. The player ran the game without
     moving it to Applications, so macOS runs it from a hidden read-only copy.
   - the path starts with `/Volumes/`. It is running straight from the disk
     image.
   - the folder holding the `.app` is not writable (a non-admin account in
     `/Applications`). Test this by creating and deleting a temporary file
     there.
2. Download `TheNewHire-<version>-macos.dmg` and verify it.
3. Mount it without showing a window (`OS.execute("hdiutil", ["attach",
   "-nobrowse", "-readonly", "-mountpoint", <temp dir>, <dmg>])`).
4. Replace the app:
   1. Copy the new `.app` out of the image next to the old one, under a
      temporary name (`ditto`).
   2. Rename the old bundle aside, and the new one into its place.
   3. Delete the old one.
   4. Detach the image.

   macOS allows replacing a running app's bundle. The running copy carries on
   from the old files until it quits.
5. Remove the quarantine flag from the new bundle, just in case
   (`xattr -dr com.apple.quarantine <bundle>`). It should not be there,
   because a file the game downloads itself is not flagged the way a browser
   download is. Confirm that in section 7.
6. Relaunch with `OS.create_process("/usr/bin/open", ["-n", <bundle>])` and
   quit.
7. **Check first, do not assume:** the exact name of the `.app` inside the
   `.dmg`. It should be "The New Hire.app", because the bundle is named after
   `application/config/name`, which the `packaged` override sets. Mount a
   dry-run `.dmg` and look before you hardcode anything.

### 4e. A test feed for section 7

`/releases/latest` skips pre-releases, so testing an update would otherwise
require a public, non-test release. Add a developer override instead: a
command-line argument after `--`, for example
`--update-feed=https://api.github.com/repos/mayar4ki/za-company/releases/tags/v0.3.0-beta.2`.
It makes the check read that release instead of `latest`. Players never pass
it, and it changes nothing else.

## 5. Steps, in order

Work on `develop`, and commit and push to `develop`. **Never commit to `main`
directly.**

1. **Release checksums (4a).** Push to `develop` and confirm that the dry run
   passes (section 8 says how to watch it). A dry run builds but does not
   publish, so the checksum code is only exercised by a real release in section 7.
2. **Pure logic first, with tests:** picking the file from the release JSON,
   parsing `SHA256SUMS.txt`, verifying a hash, and the `can_update()`
   decisions. Write the decisions as functions that take paths as arguments,
   so a test can ask about `/Applications/...`, `/Volumes/...` and
   `.../AppTranslocation/...` without a Mac.
3. **The download with progress and cancel**, and the update panel.
4. **Windows install (4c)**, including the `installer.iss` changes.
5. **macOS install (4d).**
6. **Wire it into the main menu, plus the test feed (4e).**
7. **Dry run on `develop`.** Watch it with the GitHub API (section 8).
   Then download both builds from the run page's *Artifacts* section, which
   needs a GitHub login, and check that they start.
8. **Docs:**
   - RELEASING.md: rewrite "If there is a new version" as the in-game update,
     plus the fallback.
   - CLAUDE.md: the test suite list (and its count), and a note under
     Workflow.
   - This file: tick the box at the top when done.
9. **Real-machine test (section 7).** Only then is the task done.

Steps 1-8 stay on `develop`. Section 7 is the one exception: it needs two
real pre-releases, and the workflow only publishes from `main`.

## 6. Tests

All headless, with no network, following `tests/helpers.gd`'s pattern. Read
how `tests/test_release.gd` hands answers in directly.

Extend `tests/test_release.gd`, or start `tests/test_updater.gd` if the world
it needs differs. Then register it in `tests/run_all.gd`'s `SUITES` and list
it in CLAUDE.md's Testing section. Cover:

- the right file is picked for each platform from a fake release's `assets`,
  and nothing is picked when it is missing.
- `SHA256SUMS.txt` parsing; a matching file passes; a file with one byte
  changed is refused, and nothing is installed.
- every `can_update()` case: installed / portable on Windows; Applications /
  translocated / disk image / read-only on macOS.
- **the name contract**: read `.github/workflows/release.yml` off disk and
  check that the file names it produces are exactly the ones the updater
  looks for.
- a failed or cancelled download leaves the menu with the browser link still
  working.
- anything a test writes, it deletes before finishing. A test must leave no
  files behind (CLAUDE.md, Testing).

## 7. The real-machine test (the gate)

Ask the owner for two version numbers, and their go-ahead. They will become
two real, public pre-releases, for example `0.3.0-beta.1` and `0.3.0-beta.2`.
Both must be built by this branch, so the OLD one already contains the
updater. This is the one time unfinished work goes to `main`, and only as a
pre-release: `/releases/latest` skips pre-releases, so no player's game is
offered them.

1. Merge `develop` into `main` with `VERSION` set to the first, and push. Wait
   for its release, then do the same for the second.
2. Install the first. Run it with the test feed pointing at the second:
   - Windows: `"%LOCALAPPDATA%\Programs\The New Hire\TheNewHire.exe" -- --update-feed=<URL>`
   - macOS: `"/Applications/The New Hire.app/Contents/MacOS/<binary>" -- --update-feed=<URL>`
     (check the binary's name inside the bundle)

   The `--` matters on both: Godot passes the game only the arguments after
   it (`OS.get_cmdline_user_args()`).
3. Work through the matrix. Write the results in the pull request, or in a
   message to the owner.

| # | Platform | Situation | Expected |
|---|---|---|---|
| 1 | Windows | installed per user | updates, restarts, footer shows the new version, settings kept, still one entry in *Apps & features* |
| 2 | Windows | installed for all users | admin prompt, then same as 1 |
| 3 | Windows | portable zip | no UPDATE NOW; the link opens the release page |
| 4 | Windows | cancel mid-download | old version keeps working; the link still works |
| 5 | Windows | network off | no notice at all, no error |
| 6 | macOS | in /Applications (after "Open Anyway" once) | updates, restarts, new version, settings kept |
| 7 | macOS | run from the mounted disk image | link only |
| 8 | macOS | run from Downloads without moving it | link only |
| 9 | macOS | non-admin account, app in /Applications | link only |
| 10 | macOS | cancel mid-download | old version keeps working |
| 11 | both | after an update | record whether the "unsigned app" warning appeared again (expected: no) |

Apple Silicon is the priority Mac. Test an Intel Mac too if one is available.

## 8. Rules and know-how from this project

- **CLAUDE.md is the rulebook.** Above all:
  - one file per job;
  - snake_case names;
  - scripts sit next to their scenes;
  - `preload`, not `class_name`;
  - don't pre-create empty folders.
- **The Godot binary** on the owner's machine is
  `~/OneDrive/Desktop/Godot_v4.7.2-stable_win64_console.exe`.
  - One suite: `--headless --path . --fixed-fps 60 --script res://tests/test_<name>.gd`.
  - All suites: `--headless --path . --script res://tests/run_all.gd`.
- **Back up `settings.cfg` before running any suite**
  (`%APPDATA%\Godot\app_userdata\za-company\settings.cfg`). The harness
  blanks it during a suite and only restores it at the end, so a suite that
  is killed or hangs loses the developer's settings. Restore from your
  backup if that happens.
- **Run `--import` only while the Godot editor is closed.** Two editors on
  one project corrupt each other.
- **Never kill a Godot process you did not start.** Other agents and
  teammates run tests on the same machine.
- **CI logs need a GitHub login, but error annotations do not.** The scripts
  in `tools/release/` turn failures into `::error::` lines. To watch a run:
  - `https://api.github.com/repos/mayar4ki/za-company/actions/runs?head_sha=<sha>` finds the run.
  - `.../actions/runs/<id>/jobs` gives each job's steps and result.
  - `.../check-runs/<job id>/annotations` gives the errors.
- **This machine has no `gh` CLI.** Use the GitHub REST API with `curl`, or
  the web page.
- **Two lessons from the first builds:**
  - The universal macOS build needs `import_etc2_astc` on. It is already set,
    in `tools/setup_project.gd`.
  - Godot prints the reason a preset was refused on lines AFTER the `ERROR`
    line, which is why `export.sh` reports the log's last lines.

## 9. Done when

- [ ] Every row of the section 7 matrix passes on Windows and on a real Mac.
- [ ] Any failure path leaves the player with the browser link.
- [ ] The new tests pass, along with `test_release.gd` and `test_menu.gd`.
      Run the full suite too, and note any suite that was already failing
      before your changes.
- [ ] The release publishes `SHA256SUMS.txt`, and the file-name contract is
      tested.
- [ ] RELEASING.md and CLAUDE.md describe the new behaviour.
- [ ] Released as a normal version only after all of the above, and with the
      owner's go-ahead on the `VERSION` number.

Out of scope, so leave it for later: code signing; store distribution (itch.io,
Steam); refusing online co-op between different game versions (that belongs
to the multiplayer plan, DESIGN.md, M2).
