# Dev and production: what was decided, and what is left

Written 2026-10-02, at the start of M2. `docs/environments.md` says what
production and dev share and how each shared thing hurts; this page says what
was DECIDED about each one, and the plan for the parts still to build. When an
item here is done, move it up into *Decided and done* and say so in
environments.md.

## How a change reaches production

| What you change | Where it is tried first | How it reaches production |
|---|---|---|
| Game code | Deploy to dev: the dev site and the `dev` pre-release | A release |
| Signaling code (`server/signaling/`) | Deploy to dev: dev's own signaling, rebuilt from `develop` | A release |
| `server/deploy.sh` | Nowhere yet - item B below is the CI test that changes that | A release, finished by `settle` (item A) |
| Caddyfile, coturn, and their parts of the compose file | CI checks only (`caddy validate`, `docker compose config`) | A release, which moves production AND dev at once |
| The `signaling` part of the compose file | Deploy to dev (dev's signaling starts from dev's own copy) | A release |
| The server's `.env` | Nowhere | Edited by hand on the server, and it moves both |

A deploy to dev is always started by hand (Actions -> Release -> Run workflow
on `develop`, *Deploy to dev* ticked) and never touches anything production
reads. RELEASING.md has both flows step by step.

## Decided and done

**1. Dev has its own signaling service.** A second `signaling` container on
the same droplet - compose project `za-dev`, port 8766, `/healthz` answers
`ok dev` - and the dev site's Caddy block points at it. A deploy to dev
rebuilds it from `develop`; a release never touches it after creating it the
first time. (Commit `80643a2`, shipped in v0.1.2.)

**Live and checked, 2026-10-02:** started by the first deploy to dev after
v0.1.2. The server runs two signaling containers from two images -
production's `server-signaling-1` (image `server-signaling`, built by the
release) on 8765, and dev's `za-dev-signaling-1` (image `za-dev-signaling`,
built by the deploy to dev) on 8766 - and the dev site's `/healthz` answers
`ok dev`. A deploy to dev rebuilds only the `za-dev` one, so production's
signaling is not touched by it.

**2. Dev desktop builds talk to dev's signaling.** `Net.signaling_url()`
(`autoload/net.gd`) is the one rule: a web build uses its own page's host, a
release desktop build (`packaged` and not `dev`) the live service, and
everything else - a dev build, the editor - dev's. The M0 test screen that
had its own live-only rule is deleted. (Commit `0b19288`.)

**3. A dev desktop build is a different app from the game.** "The New Hire
(dev)": its own name, its own `user://` folder, its own installer `AppId` and
macOS bundle id, and no update check. A tester can install both, and a dev
build can never overwrite the game or its settings - or, later, its saves.
`tools/release/prepare.sh` renames the build and refuses to build if a field
it renames has moved, and `installer.iss` takes `/DDev`.
`tests/test_release.gd` checks both halves off disk. Item D is the check
on real machines.

## Decided: keep it shared

**4. One deploy key: accepted for now.** The `DEPLOY_SSH_KEY` secret can run
every `deploy.sh` command, and any branch can read it, so one careless edit
to the dev jobs on `develop` could deploy to production without a release.
Accepted while one person pushes to `develop`. **Revisit** the day anyone
else gets push access: the fix is two keys (environments.md #3), about twenty
minutes.

**5. Caddy and coturn stay shared.** One of each, owned by the release. They
almost never change, so a second copy for dev is not worth its ports. The one
change to watch is coturn's flags: nothing tries them before production (a
flag coturn rejects is a restart loop, which is the relay down). After any
release that touches the Caddyfile or coturn, watch the `deploy` job and the
site.

**6. The compose file: nothing to do.** It defines three services. Dev's
signaling is already started from dev's OWN copy of the file (from
`develop`), so the signaling part is already separate; the Caddy and coturn
parts come only from the release's copy and are shared along with them (5).
The one thing to remember: a new REQUIRED variable (`${X:?}`) in the
signaling service stops dev's signaling starting until it is in the server's
`.env` - add it there before the dev deploy that needs it.

**7. The secrets file (`/opt/za-company/server/.env`) stays shared.** Dev's
signaling reads the live `.env` because there is only one coturn, and the
two must agree on its secret. What is in it:

| Key | What it is | Secret? |
|---|---|---|
| `TURN_SECRET` | Signaling makes short-lived relay logins with it; coturn checks them with it | **Yes - the only one.** Whoever has it can use the relay and the server's bandwidth |
| `DOMAIN` | The server's name: the site, signaling, and where TURN is | No |
| `EXTERNAL_IP` | The server's public address, which coturn tells players | No |
| `TURN_PORT`, `TURN_MIN_PORT`, `TURN_MAX_PORT` | The relay's port and the range relayed players use | No |
| `TURN_TOTAL_QUOTA` | How many players can be relayed at once (40) | No |
| `SIGNAL_PORT`, `DEV_SIGNAL_PORT` | Where production's (8765) and dev's (8766) signaling listen, on loopback only | No |
| `PARTY_CEILING` | The most players any room may hold, whatever a client asks | No |

Two consequences. Rotating `TURN_SECRET` means restarting both signaling
services and coturn together. And dev cannot use a different value for any
of these (for example a bigger `PARTY_CEILING`); if it ever needs to, the
place is `up_dev` in `deploy.sh`, which already passes dev its own port.
The only other secret anywhere is `DEPLOY_SSH_KEY` on GitHub.

**8. One droplet.** There is no second server, so dev's signaling runs beside
production's on 458 MiB of RAM. "Be careful" becomes item C, so nobody has
to remember it.

## Decided: not a separate deploy.sh

**9. `deploy.sh` stays one script, and is tested instead of duplicated.**
The problem is real: a change to it cannot be tried anywhere before
production, and it only fully takes effect one release LATE, because a
release's `server` step is run by the copy the PREVIOUS release installed.
v0.1.2 is the proof: the old copy put the new Caddyfile in place, and the
step that would have started dev's signaling was only in the new copy, so
the dev site's signaling answered 502. (It was cleared by the next deploy to
dev: its `server-dev` step was one the old copy already knew.)

A dev copy that dev deploys could update was rejected because of what the
script is: it runs as root on the box that serves production, and its job is
deleting and replacing folders - `mirror` empties a whole directory except
`.env` and `web/`. A half-finished copy of it, one wrong path away from
production's folder, is the thing most able to break production. The two
items below solve the actual problem without that.

## To do

### A. `deploy.sh` finishes its own install (`settle`)

**Status:** built and committed on `develop` (`0b19288`); arrives with the
next release. Dev's signaling no longer waits on it - a deploy to dev already
started it (item 1) - so what it buys now is every FUTURE change to the
script.

At the end of `server`, after installing itself, the script runs the NEW copy
with `settle`, which does whatever the release taught it - today, starting
dev's signaling if it has never been started (on this server it has, so that
part is now a no-op). So a change to the script takes effect in the release
that ships it, not the one after. `settle` only ever makes sure of things, so
it is safe to run alone.

**Done when:** a release ships it and its `deploy` job passes - the new copy
runs `settle`, and the dev site's `/healthz` still answers `ok dev` after it.

### B. An upgrade test for `deploy.sh` in CI

**Status:** not started. About an afternoon. Costs nothing: GitHub's runner
is the throwaway machine.

The test plays a real upgrade on the release's `server` job, where a wrong
`rm -rf` destroys nothing:

1. Let the script's three paths be overridden from the environment -
   `ROOT`, `DEV`, and where it installs itself (`/usr/local/sbin/za-deploy`,
   which `settle` also calls). On the server nothing changes: the forced
   command runs it with sshd's environment, which a client cannot add to
   (`PermitUserEnvironment` is off, and sshd accepts only `LANG` and `LC_*`
   from a client), so the overrides exist only for the test.
   Also let the test leave out the `tls` profile: Caddy cannot get a
   certificate on a runner, and `caddy validate` already checks its config.
2. Install the PREVIOUS release's `deploy.sh` (from its tag) into a temp
   folder, with a `.env` made from `.env.example`, exactly as the server has
   it.
3. Pipe this commit's server bundle to it as `server`. Check: production's
   signaling answers `ok` on 8765, dev's answers `ok dev` on 8766, and the
   installed script is now this commit's.
4. Then `server-dev` with the same bundle (dev's still `ok dev`), `settle`
   alone (changes nothing), and `web` / `web-dev` with a build missing
   `index.wasm` (refused, and the live folder untouched).
5. Fail the job on any of it, so a release cannot ship a script that cannot
   upgrade itself.

**Done when:** the test would fail against v0.1.2's change (old script, new
bundle, no dev signaling) and passes with `settle`.

### C. A memory cap on the signaling containers

**Status:** step 1 done; the cap itself not started. About fifteen minutes.

1. ~~Measure first.~~ Done 2026-10-02, `docker stats --no-stream` on the
   server: production's signaling 11.8 MiB, dev's 17.8 MiB, Caddy 20.9 MiB,
   coturn 2.3 MiB - and every container's limit is the whole server's
   458 MiB, which is to say there is no cap yet.
2. One line on the `signaling` service in `docker-compose.yml`:
   `mem_limit: ${SIGNAL_MEM_LIMIT:-128m}` - about seven times the bigger of
   the two today, so it only ever stops a runaway. Both copies start from that
   file, so it caps production's and dev's alike - a runaway dev build is then
   killed by Docker instead of pushing production into swap.
3. The next deploy to dev gives dev's copy the cap, and the next release
   gives production's.

**Done when:** `docker inspect` shows the limit on both signaling containers.

### D. Check the dev app on real machines

**Status:** waiting for the next deploy to dev after item 3 is pushed. Ten
minutes, by hand.

- **Windows:** install the dev setup on a machine that has the game
  installed. Expect both in the Start Menu and in *Installed apps*, in two
  folders, each with its own uninstaller; the dev window titled "The New Hire
  (dev)"; its settings in `%APPDATA%\Godot\app_userdata\The New Hire (dev)`;
  and no update notice on its menu.
- **macOS:** "The New Hire (dev).app" sits beside "The New Hire.app" in
  Applications, and neither replaces the other.
- **Online:** a dev desktop build and the dev web site can play together
  (both on dev's signaling).

One thing will look like a bug and is not: a dev build installed BEFORE this
change used the game's own `AppId`, so it replaced the game. After it, the
first new dev build starts with fresh settings in its own folder, and the
next release installer upgrades that old copy back into the game.
