#!/bin/sh
# The release pipeline's ONLY way into this server. Its SSH key is installed
# in /root/.ssh/authorized_keys as
#
#   restrict,command="/usr/local/sbin/za-deploy" ssh-ed25519 AAAA... za-company release
#
# so whatever that key asks to run, THIS runs instead, with the asked-for
# command in SSH_ORIGINAL_COMMAND and a tar of what to deploy on stdin:
#
#   web      the exported web build, swapped into web/game by rename
#   server   this folder, minus .env and web/, then the stack brought up to it
#
# Nothing else is accepted: a leaked deploy key can replace the game or the
# stack with what the repository would have shipped anyway, and cannot open a
# shell. The `server` step installs this file over its own installed copy, so
# the repository stays the one place it is written.

set -eu

ROOT=/opt/za-company/server
COMPOSE="docker compose --profile tls"

case "${SSH_ORIGINAL_COMMAND:-}" in
web)
	mkdir -p "$ROOT/web"
	cd "$ROOT/web"
	rm -rf game.new game.old
	mkdir game.new
	tar -x -C game.new --no-same-owner
	for f in index.html index.js index.wasm index.pck; do
		if [ ! -s "game.new/$f" ]; then
			echo "za-deploy: refusing a web build with no $f" >&2
			rm -rf game.new
			exit 1
		fi
	done
	# Two renames in the folder Caddy mounts (web/, never game/ - README), so
	# a page loaded mid-deploy gets one whole build or the other.
	if [ -d game ]; then mv game game.old; fi
	mv game.new game
	rm -rf game.old
	echo "za-deploy: web build live ($(du -sh game | cut -f1))"
	;;
server)
	staging=$(mktemp -d)
	trap 'rm -rf "$staging"' EXIT
	tar -x -C "$staging" --no-same-owner
	if [ ! -f "$staging/docker-compose.yml" ] || [ ! -f "$staging/Caddyfile" ]; then
		echo "za-deploy: refusing a server folder with no docker-compose.yml or Caddyfile" >&2
		exit 1
	fi
	rm -rf "$staging/.env" "$staging/web"
	before=$(sha256sum "$ROOT/Caddyfile" 2>/dev/null | cut -d' ' -f1 || true)
	# A mirror, so a file deleted from the repository goes here too - except
	# the two things that only ever live on this server.
	find "$ROOT" -mindepth 1 -maxdepth 1 ! -name .env ! -name web -exec rm -rf {} +
	cp -a "$staging/." "$ROOT/"
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
	docker image prune -f >/dev/null
	$COMPOSE ps --format '{{.Service}}: {{.Status}}'
	;;
*)
	echo "za-deploy: expected 'web' or 'server' with a tar on stdin, got '${SSH_ORIGINAL_COMMAND:-}'" >&2
	exit 2
	;;
esac
