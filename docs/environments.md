# Production and dev

There are two places the game runs, and they are not two copies of the same
setup. This page says what is separate, what is shared, and which of the
shared parts will cause trouble later, when, and what fixes it. How each one
is deployed is RELEASING.md (*Deploying* and *Deploying to dev*).

| | Production | Dev |
|---|---|---|
| Web game | https://za-company.mayar-deeb.dev | https://dev.za-company.mayar-deeb.dev |
| Windows and macOS files | a versioned GitHub Release (`v0.1.1`) | the rolling `dev` pre-release |
| Started by | `VERSION` changing on `main` | Run workflow on `develop`, *Deploy to dev* ticked |
| Server folder | `web/game/` | `web/dev-game/` |

Separate: the web builds, the desktop builds, and what starts each deploy.

Shared: the droplet, its Caddy, the signaling service, coturn, the deploy key,
and the workflow (`release.yml` builds both with the same jobs). The server's
own files - Caddyfile, compose file, signaling, `deploy.sh` - only ever reach
the server with a **release**, so dev can never get a server change first.

## When sharing bites

Four things, in the order they will hurt. None of them is fixed yet.

### 1. One signaling service - bites at M2

**When:** the first time the signaling protocol changes, which M2 (the `Net`
autoload and the lobby) will do several times.

**What happens:** a dev build speaking the new protocol is refused by the
production service with `version`, and the production service can only be
changed by a release - so dev cannot test multiplayer work before it ships.
The other way round is no better: release the new service, and the dev site
breaks until dev catches up.

**Fix:** a second `signaling` container for dev on the same droplet, on its
own port, and one line in the dev site's Caddy block pointing at it. coturn
stays shared (see below). About 40 MB of memory.

**Do it:** at the start of M2.

### 2. Server changes cannot be tried anywhere first - bites at any release

**When:** any release that changes Caddy, coturn or signaling.

**What happens:** the change goes straight to production, and dev with it.
The release's `server` job checks the compose file and runs the signaling
tests, but it cannot see how a program reacts to its configuration. The real
case: coturn 4.18 rejects `--no-dtls`, which a config check passes and coturn
answers with a restart loop. Shipped in a release, that is production's relay
down.

**Fix:** the dev stack from #1, deployed by a deploy to dev - so a server
change runs on dev before a release takes it to production. Same work as #1;
do them together.

**Until then:** keep server changes small, and watch the `deploy` job and the
site after a release that touches `server/`.

### 3. One deploy key for both - unlikely, high impact, cheap to fix

**When:** any time, by accident.

**What happens:** the `DEPLOY_SSH_KEY` secret can run all three of
`deploy.sh`'s commands - `web`, `web-dev` and `server` - and a workflow on any
branch can read it. One careless edit to the dev jobs on `develop` could
deploy to production with no release.

**Fix:** two keys.

- A **dev key** whose `authorized_keys` line gives `deploy.sh` an argument
  that only allows `web-dev`, stored in the `dev` GitHub environment.
- The **production key** as now, moved into the `production` environment,
  with that environment's *Deployment branches* set to `main` only.

About twenty minutes: the server and workflow side, plus a few clicks in
**Settings -> Environments**.

**Do it:** soon - it is the only one of the four with no warning before it
happens.

### 4. Dev and release desktop builds are the same app - bites once there are saves

**When:** as soon as the game writes save data.

**What happens:** to Windows and macOS a dev build IS the game. The dev
installer replaces an installed release instead of sitting beside it, and
both read and write the same `user://` folder - today only `settings.cfg`,
tomorrow a save a dev build may have written in a format the release cannot
read.

**Fix:** dev builds get their own name and identity - "The New Hire (dev)",
their own installer `AppId` and their own `user://` folder - set by a feature
tag only dev builds carry.

**Do it:** before saves exist.

## What will not bite

- **One coturn.** TURN relays bytes and never reads them, so it does not care
  which build it carries. Dev testers share its 40 relay slots, which at this
  scale is nothing.
- **One droplet.** The dev site is static files; even a dev signaling
  container is about 40 MB.
- **One workflow file.** That one is a strength: a dev build is exactly what a
  release would build from the same commit, and every dry run checks both
  paths.
- **Browser data.** `dev.` is a different origin, so the browser already keeps
  the dev site's settings and storage apart from the live game's.
