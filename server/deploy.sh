#!/bin/sh
# The release pipeline's ONLY way into this server. Its SSH key is installed
# in /root/.ssh/authorized_keys as
#
#   restrict,command="/usr/local/sbin/za-deploy" ssh-ed25519 AAAA... za-company release
#
# so whatever that key asks to run, THIS runs instead, with the asked-for
# command in SSH_ORIGINAL_COMMAND and a tar of what to deploy on stdin:
#
#   web         a release's web build, swapped into web/game by rename
#   web-dev     a dev deploy's web build, the same way into web/dev-game - the
#               dev site, https://dev.DOMAIN, and nothing the live site reads
#   server      this folder, minus .env and web/, then the stack brought up to it
#   settle      the end of `server`, run by the copy it just installed: makes
#               sure dev's signaling exists. Takes no tar, and is safe alone
#   server-dev  a dev deploy's copy of this folder, into DEV, and ONLY its
#               signaling service started from it: dev's own signaling, which
#               the dev site talks to (README.md, Dev's signaling). Caddy and
#               coturn are never started from it - there is one of each, and
#               they are the release's
#
# Nothing else is accepted: a leaked deploy key can replace the game or the
# stack with what the repository would have shipped anyway, and cannot open a
# shell. The `server` step installs this file over its own installed copy, so
# the repository stays the one place it is written.

set -eu

ROOT=/opt/za-company/server
DEV=/opt/za-company/dev-server
COMPOSE="docker compose --profile tls"

# Unpack a web build beside the live one in web/<folder>, refuse it if a file
# is missing, then swap it in by two renames in the folder Caddy mounts (web/,
# never the build's own - README), so a page loaded mid-deploy gets one whole
# build or the other.
deploy_web() {
	folder="$1"
	mkdir -p "$ROOT/web"
	cd "$ROOT/web"
	rm -rf "$folder.new" "$folder.old"
	mkdir "$folder.new"
	tar -x -C "$folder.new" --no-same-owner
	for f in index.html index.js index.wasm index.pck; do
		if [ ! -s "$folder.new/$f" ]; then
			echo "za-deploy: refusing a web build with no $f" >&2
			rm -rf "$folder.new"
			exit 1
		fi
	done
	if [ -d "$folder" ]; then mv "$folder" "$folder.old"; fi
	mv "$folder.new" "$folder"
	rm -rf "$folder.old"
	echo "za-deploy: $folder live ($(du -sh "$folder" | cut -f1))"
}

# Unpack a copy of this folder from stdin into a fresh staging directory,
# refuse it if it is not one, and print where it is. The caller cleans up.
stage_server() {
	staging=$(mktemp -d)
	tar -x -C "$staging" --no-same-owner
	if [ ! -f "$staging/docker-compose.yml" ] || [ ! -f "$staging/Caddyfile" ]; then
		echo "za-deploy: refusing a server folder with no docker-compose.yml or Caddyfile" >&2
		rm -rf "$staging"
		exit 1
	fi
	rm -rf "$staging/.env" "$staging/web"
	echo "$staging"
}

# Make <dest> exactly <source> - a mirror, so a file deleted from the
# repository goes here too - except the two things that only ever live on
# this server, which are neither removed from <dest> nor copied from <source>.
mirror() {
	mkdir -p "$2"
	find "$2" -mindepth 1 -maxdepth 1 ! -name .env ! -name web -exec rm -rf {} +
	find "$1" -mindepth 1 -maxdepth 1 ! -name .env ! -name web -exec cp -a {} "$2/" \;
}

# Dev's own signaling, from whatever is in DEV: a second compose project
# (`za-dev`) running only the `signaling` service, on its own loopback port,
# with the live .env for its secrets - coturn is shared, so the TURN secret
# must be the same one - and STAGE=dev, which /healthz says out loud. It is
# asked for its health before this returns, so a dev signaling that does not
# start fails the deploy instead of leaving the dev site talking to nothing.
up_dev() {
	port=$(sed -n 's/^DEV_SIGNAL_PORT=//p' "$ROOT/.env" | tail -n 1)
	port=${port:-8766}
	cd "$DEV"
	SIGNAL_PORT=$port STAGE=dev docker compose -p za-dev --env-file "$ROOT/.env" \
		up -d --build --remove-orphans signaling
	tries=0
	until curl -fsS "http://127.0.0.1:$port/healthz" 2>/dev/null | grep -q '^ok dev$'; do
		tries=$((tries + 1))
		if [ "$tries" -ge 30 ]; then
			echo "za-deploy: dev signaling did not answer on 127.0.0.1:$port" >&2
			exit 1
		fi
		sleep 1
	done
	echo "za-deploy: dev signaling up on 127.0.0.1:$port"
}

case "${SSH_ORIGINAL_COMMAND:-}" in
web)
	deploy_web game
	;;
web-dev)
	deploy_web dev-game
	;;
server)
	staging=$(stage_server)
	trap 'rm -rf "$staging"' EXIT
	before=$(sha256sum "$ROOT/Caddyfile" 2>/dev/null | cut -d' ' -f1 || true)
	mirror "$staging" "$ROOT"
	cd "$ROOT"
	$COMPOSE up -d --build --remove-orphans
	# The Caddyfile is a FILE bind mount, and a replaced file is a new inode
	# the running container never sees: a reload would re-read the old one.
	# So a changed Caddyfile recreates Caddy (a second's blip, certificates
	# kept in their volume) rather than reloading it.
	if [ "$before" != "$(sha256sum Caddyfile | cut -d' ' -f1)" ]; then
		$COMPOSE up -d --force-recreate caddy
	fi
	install -m 0755 deploy.sh /usr/local/sbin/za-deploy
	# The rest is the NEW copy's to do, not this one's. The script running
	# now is whatever the last release installed, so anything this release
	# taught it would otherwise wait a whole release to happen - which is how
	# v0.1.2 put the dev route in the Caddyfile and left nothing behind it.
	SSH_ORIGINAL_COMMAND=settle /usr/local/sbin/za-deploy
	docker image prune -f >/dev/null
	cd "$ROOT"
	$COMPOSE ps --format '{{.Service}}: {{.Status}}'
	;;
settle)
	# The end of a `server`, run by the copy that step just installed. Safe to
	# ask for on its own, since all it does is make sure of things: dev's
	# signaling exists, seeded from the live folder the first time, so the
	# dev site's route never points at nothing. After that it is a dev
	# deploy's to move, and a release leaves it alone.
	if [ ! -f "$DEV/docker-compose.yml" ]; then
		mirror "$ROOT" "$DEV"
		up_dev
	fi
	;;
server-dev)
	staging=$(stage_server)
	trap 'rm -rf "$staging"' EXIT
	mirror "$staging" "$DEV"
	up_dev
	docker image prune -f >/dev/null
	;;
*)
	echo "za-deploy: expected 'web', 'web-dev', 'server', 'server-dev' (each with a tar on stdin) or 'settle', got '${SSH_ORIGINAL_COMMAND:-}'" >&2
	exit 2
	;;
esac
