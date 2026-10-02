# Branches, versions and releases

## The two branches

- **`develop`** is where work happens. Commit and push here day to day.
- **`main`** gets a feature when it is finished: merge `develop` into it.

```sh
git switch main
git pull
git merge develop
git push
git switch develop
```

You can merge into `main` as often as you like. A merge is not a release.

## What a release is

A release is **the `VERSION` file changing on `main`**, and nothing else.
When a push to `main` changes `VERSION`, `.github/workflows/release.yml`:

1. checks the number,
2. builds the game for Windows and macOS (see below),
3. tags that commit `v<number>` (for example `v0.2.0`),
4. publishes it on the repository's **Releases** page with the builds
   attached, and every commit since the previous release as the notes.

Nothing is published unless every build succeeds, so a release is never
missing a platform. Pushes that leave `VERSION` alone never trigger it.

## What a release contains

| File | For |
|---|---|
| `TheNewHire-0.2.0-windows-setup.exe` | Windows installer: Start Menu entry, optional desktop icon, uninstaller. Installs for the current user with no administrator prompt. A new version upgrades the old one in place. |
| `TheNewHire-0.2.0-windows-portable.zip` | The same game with nothing to install: unzip and run `TheNewHire.exe`. |
| `TheNewHire-0.2.0-macos.dmg` | macOS disk image: open it and drag the game to Applications. One build for Intel and Apple Silicon. |

The web build is not attached. It is published to the server instead
(`tools/web/publish.py`).

**The builds are not signed yet**, so both systems warn the first time the
game is opened. The release notes tell players what to click:

- **Windows** shows *Windows protected your PC*: **More info**, then
  **Run anyway**.
- **macOS** refuses to open it: **System Settings -> Privacy & Security**,
  then **Open Anyway**.

An installed game also checks GitHub for a newer release when its main menu
opens, and if there is one, shows *v0.3.0 IS OUT - GET IT* in the corner. That
button opens the release page. The check never runs in the editor, in the
test suites or in the web build (`ui/main_menu/release_check.gd`).

## Making a release

1. Change the number in `VERSION`. You can do this on `develop` and merge it,
   or commit it straight on `main`.
2. Push `main`.
3. The **Actions** tab shows the run. The builds take several minutes (the
   first run longer, while it downloads Godot), and then the release appears
   under **Releases**.

The number is `MAJOR.MINOR.PATCH`, written without a `v`:

| Change | Example |
|---|---|
| a fix, nothing new | `0.1.0` -> `0.1.1` |
| a new feature or floor | `0.1.1` -> `0.2.0` |
| the finished game, or anything that breaks old saves | `0.9.0` -> `1.0.0` |
| a test build ahead of a release | `1.0.0-beta.1` (marked *pre-release*) |

The workflow refuses a number lower than the latest release, because that is
a typo rather than a release. Re-using a number that is already released does
nothing.

## Trying a build without releasing

A push to `develop` that changes what the builds are made of
(`export_presets.cfg`, the workflow, or anything in `tools/release/`) runs
the whole build as a **dry run**. It publishes nothing and keeps the files on
the run's page in the Actions tab for a week. **Actions -> Release -> Run
workflow** on `develop` does the same on demand.

## If something goes wrong

- **The run failed**: open it in the Actions tab. The error at the top of the
  run names the problem (the format of `VERSION`, or the Godot error that
  stopped an export). Fix it and push again.
- **Run it again by hand**: Actions -> Release -> *Run workflow* on `main`.
  If the version is already released, it stops without doing anything.
- **Undo a release**: delete it on the Releases page, then delete its tag
  (`git push origin :refs/tags/v0.2.0`).

## Later: signing

Signing removes both warnings above. It is a later change to the presets and
the workflow, and each platform needs its own certificate, kept as a
repository secret:

- **macOS**: an Apple Developer Program membership ($99 a year) gives a
  *Developer ID Application* certificate. With it, the export signs and
  notarizes the app, and macOS opens it without asking.
- **Windows**: a code-signing certificate from a certificate authority, or
  Microsoft's Azure Trusted Signing. Both are paid subscriptions.

Until then the warnings are a click, not a wall. Testers can live with that;
a public launch should not.
