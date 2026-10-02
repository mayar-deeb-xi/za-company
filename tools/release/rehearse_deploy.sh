#!/usr/bin/env bash
# Rehearses a release's deploy on THIS machine before the real server ever
# sees it (docs/dev_prod_plan.md, item B):
#
#   tools/release/rehearse_deploy.sh <server bundle .tar> [previous release tag]
#
# It plays what the server will see, at the server's own paths: the box as the
# previous release left it - that release's deploy.sh installed as
# /usr/local/sbin/za-deploy, its stack up - and then
#
#   1. this bundle deployed by THAT script: the upgrade the next release will
#      really do, run by a script that knows nothing this commit taught it;
#   2. this bundle again, by the copy step 1 installed: what every release
#      after it does, and the only path that runs the hand-off (`apply`);
#   3. a deploy to dev, `settle` alone, and the web builds, a broken one
#      included.
#
# Every step is checked the way a player reaches it - through Caddy, by name -
# which is what would have caught v0.1.2: a dev route answering 502.
#
# It REPLACES /opt/za-company and /usr/local/sbin/za-deploy and runs the whole
# stack on ports 80, 443 and 3478, so it refuses to run anywhere but a
# throwaway machine (a GitHub runner, GITHUB_ACTIONS=true). DOMAIN is
# `localhost`, so Caddy signs for localhost and dev.localhost itself and
# nothing asks the internet for a certificate.

set -euo pipefail

if [ "${GITHUB_ACTIONS:-}" != "true" ]; then
  echo "rehearse_deploy: this replaces /opt/za-company and /usr/local/sbin/za-deploy;" \
    "run it on a throwaway machine (GITHUB_ACTIONS=true), never a server" >&2
  exit 2
fi

bundle="$(realpath "$1")"
previous="${2:-}"
repo="$(cd "$(dirname "$0")/../.." && pwd)"
SELF=/usr/local/sbin/za-deploy
ROOT=/opt/za-company/server
DEV=/opt/za-company/dev-server
work="$(mktemp -d)"

as_root() {
  if [ "$(id -u)" = 0 ]; then "$@"; else sudo "$@"; fi
}

# What the deploy key would do: the installed script, the command in
# SSH_ORIGINAL_COMMAND, the tar on stdin.
deploy() {
  as_root env SSH_ORIGINAL_COMMAND="$1" "$SELF" < "${2:-/dev/null}"
}

# Wait up to a minute for https://<host><path>, through Caddy, to be exactly
# <body> - Caddy signs a new name on its first request, and signaling takes a
# moment to come up.
expect() {
  local what="$1" host="$2" path="$3" body="$4" got=""
  for _ in $(seq 60); do
    got="$(curl -fsSk --max-time 5 --resolve "$host:443:127.0.0.1" "https://$host$path" 2>&1 || true)"
    if [ "$got" = "$body" ]; then
      echo "  ok    $what"
      return 0
    fi
    sleep 1
  done
  echo "::error::rehearsal: $what - https://$host$path said '${got:0:200}', not '$body'"
  return 1
}

check() {
  if eval "$2"; then
    echo "  ok    $1"
  else
    echo "::error::rehearsal: $1"
    return 1
  fi
}

installed_is_this_commits() {
  tar -xOf "$bundle" ./deploy.sh | as_root cmp -s - "$SELF"
}

signaling_id() {
  as_root docker inspect -f '{{.Id}}' "$1" 2>/dev/null || echo none
}

both_sites_answer() {
  expect "$1: the live site reaches the live signaling" localhost /healthz "ok"
  expect "$1: the dev site reaches dev's own signaling" dev.localhost /healthz "ok dev"
}

# coturn still running, never restarted, for five seconds on end. A flag it
# rejects is not a failed start but a restart LOOP (4.18 and `--no-dtls`), and
# nothing else here would notice: no check goes through the relay.
coturn_stays_up() {
  for _ in $(seq 5); do
    [ "$(as_root docker inspect -f '{{.State.Status}} {{.RestartCount}}' server-coturn-1 2>/dev/null)" \
      = "running 0" ] || return 1
    sleep 1
  done
}

# On any failure, what the box looked like, in the log rather than lost.
finish() {
  local status=$?
  if [ "$status" -ne 0 ]; then
    echo "::group::rehearsal failed - the box at that moment"
    as_root docker ps -a || true
    (cd "$ROOT" && as_root docker compose --profile tls logs --tail 40) || true
    (cd "$DEV" && as_root docker compose -p za-dev --env-file "$ROOT/.env" logs --tail 40) || true
    echo "::endgroup::"
  fi
  rm -rf "$work"
}
trap finish EXIT

echo "== the box as ${previous:-a fresh server} left it"
as_root mkdir -p "$ROOT"
sed -e 's/^DOMAIN=.*/DOMAIN=localhost/' -e 's/^TURN_SECRET=.*/TURN_SECRET=rehearsal-only/' \
  "$repo/server/.env.example" | as_root tee "$ROOT/.env" >/dev/null
if [ -n "$previous" ] && git -C "$repo" cat-file -e "$previous:server/deploy.sh" 2>/dev/null; then
  git -C "$repo" show "$previous:server/deploy.sh" > "$work/previous_deploy.sh"
  as_root install -m 0755 "$work/previous_deploy.sh" "$SELF"
  git -C "$repo" archive --format=tar "$previous:server" > "$work/previous.tar"
  deploy server "$work/previous.tar"
  expect "$previous's live site is up" localhost /healthz "ok"
else
  echo "  (no previous release with a deploy.sh: this commit's script on a fresh server)"
  tar -xOf "$bundle" ./deploy.sh > "$work/deploy.sh"
  as_root install -m 0755 "$work/deploy.sh" "$SELF"
fi

echo "== 1. this bundle, deployed by the script already installed"
deploy server "$bundle"
check "1: the installed script is now this commit's" installed_is_this_commits
both_sites_answer 1
check "1: coturn stays up on this commit's flags" coturn_stays_up

echo "== 2. this bundle again, deployed by this commit's own script"
deploy server "$bundle" | tee "$work/second.log"
check "2: the new copy took over (the hand-off ran)" \
  'grep -q "za-deploy: the new copy takes over" "$work/second.log"'
check "2: the installed script is still this commit's" installed_is_this_commits
both_sites_answer 2
check "2: coturn stays up" coturn_stays_up

echo "== 3. a deploy to dev, settle alone, and the web builds"
live_before="$(signaling_id server-signaling-1)"
deploy server-dev "$bundle"
both_sites_answer "3, a deploy to dev"
check "3: a deploy to dev left the live signaling container alone" \
  '[ "$(signaling_id server-signaling-1)" = "$live_before" ]'
deploy settle
both_sites_answer "3, settle alone"

mkdir "$work/web"
for f in index.html index.js index.wasm index.pck; do
  echo "rehearsal $f" > "$work/web/$f"
done
tar -C "$work/web" -cf "$work/web.tar" .
deploy web "$work/web.tar"
expect "3: the live site serves a web build" localhost /index.html "rehearsal index.html"
deploy web-dev "$work/web.tar"
expect "3: the dev site serves a web build" dev.localhost /index.html "rehearsal index.html"
rm "$work/web/index.wasm"
echo "rehearsal broken" > "$work/web/index.html"
tar -C "$work/web" -cf "$work/broken.tar" .
check "3: a web build with no index.wasm is refused" '! deploy web "$work/broken.tar" 2>/dev/null'
expect "3: and the live build is untouched" localhost /index.html "rehearsal index.html"

echo "rehearsal passed: ${previous:-a fresh server} -> this commit, and this commit -> itself"
