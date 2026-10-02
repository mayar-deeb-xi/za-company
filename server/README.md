# Online back end

Two small services for online co-op. Neither one runs the game: one player's
machine hosts the game, and this server only helps the players find each
other.

- **signaling** (`signaling/`, Python): a WebSocket service. A host opens a
  room and gets a six-letter code, a guest joins with that code, and the two
  pass their connection details through here until WebRTC connects them. It
  also issues each player a TURN login that expires after 24 hours.
- **coturn**: STUN, which helps two players find a direct route to each other,
  and TURN, the relay that carries the game's traffic only when no direct
  route exists.
- **caddy** (optional): serves the signaling service over secure `wss://` with
  a free automatic Let's Encrypt certificate, and serves the **web build of
  the game** on the same domain (see *The web build* below).

The plan this serves is DESIGN.md, *Multiplayer*. Godot never sees this folder
(`.gdignore`), so none of it is ever exported with the game.

## Our server

`za-company.mayar-deeb.dev` (A record on Vercel DNS, no AAAA) is a DigitalOcean
droplet, `104.248.45.148`: Frankfurt, Ubuntu 24.04, one vCPU, 512 MB. Log in
with `ssh root@za-company.mayar-deeb.dev` (key only; passwords are refused).
This folder lives at `/opt/za-company/server`, with its `.env` beside it.

What the droplet was given before anything ran on it: a 1 GB swapfile (512 MB
with no swap cannot reliably build an image), Docker and Compose from Docker's
own apt repository, container logs capped at 3 x 10 MB in
`/etc/docker/daemon.json` (coturn logs every relay, and the disk is 8.7 GB),
ufw with exactly the ports below, and root SSH by key only
(`/etc/ssh/sshd_config.d/10-za-hardening.conf`). Its public IP sits directly
on eth0, so `EXTERNAL_IP` is the plain address, not the `PUBLIC/PRIVATE` form.
Since then it has one more key: the release pipeline's, which can run
`deploy.sh` and nothing else (*The web build* below, and RELEASING.md).

## Deploying

You need a Linux server with Docker (including the Compose plugin), a domain
you control, and a public IP.

**1. DNS.** Point a subdomain at the server with an A record, for example
`play.yourdomain.com`. The rest of this guide calls it `DOMAIN`.

**2. Firewall.** Open these ports:

| Port | Protocol | For |
|---|---|---|
| 3478 | UDP + TCP | STUN and TURN |
| 49160-49200 | UDP | relayed traffic: one port per relayed player |
| 80, 443 | TCP | only if Caddy handles TLS (step 4) |
| 443 | UDP | HTTP/3, with Caddy; browsers fall back to TCP without it |

If you change the relay range in `.env`, open the same range here.

**3. Configure.** Copy this `server/` folder to the server, then:

```sh
cp .env.example .env
openssl rand -hex 32        # paste the result in as TURN_SECRET
nano .env                   # set DOMAIN, EXTERNAL_IP and TURN_SECRET
```

`EXTERNAL_IP` is the server's public IPv4. On a cloud VM whose network
interface only has a private address (AWS, GCP, Azure), write it as
`PUBLIC/PRIVATE`, for example `203.0.113.10/10.0.0.5`. Never commit `.env`:
it is gitignored because it holds the TURN secret.

**4. Start.** Pick the line that matches your server.

Nothing else on the server uses ports 80 and 443, so Caddy can take them:

```sh
docker compose --profile tls up -d --build
```

Something already serves 80/443 (nginx, Traefik, another Caddy): start only
the two services, then point your proxy at the signaling service on loopback:

```sh
docker compose up -d --build
```

```nginx
server {
    server_name play.yourdomain.com;
    # ...your existing listen 443 ssl / certificate lines...
    location / {
        proxy_pass http://127.0.0.1:8765;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 3600s;   # a lobby can sit idle for a long time
    }
}
```

**5. Check it.**

```sh
curl https://DOMAIN/healthz                     # prints: ok
docker compose logs -f signaling coturn         # watch players arrive
```

To test the relay without the game, get a temporary login:

```sh
docker compose exec signaling python -c \
  "import os, turn; print(turn.credentials(os.environ['TURN_SECRET'], 'test', 3600))"
```

Then open
<https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/>, add
`turn:DOMAIN:3478` with that username and password, and press *Gather
candidates*. A line of type `relay` means TURN works.

## The web build

The same Caddy serves the game itself, so `https://DOMAIN` opens it in a
browser and `wss://DOMAIN` is still the signaling service. One domain, split by
the REQUEST rather than by the path (see `Caddyfile`): a WebSocket upgrade, on
any path, and `/healthz` go to signaling, and everything else is a file out of
`web/game/`.

A release puts a build there (RELEASING.md, *Deploying*): the workflow's `web`
job exports the "Web" preset on Linux and gzips every `.html`, `.js`, `.wasm`
and `.pck` beside itself, and its `deploy` job streams the result to
`deploy.sh web`, which unpacks it into `web/game.new`, refuses it if a file
is missing, and swaps it in by two renames. A page loaded mid-deploy gets one
whole build or the other, and nothing restarts. The `.gz` files are made
there and not here: Caddy serves them as they are (`precompressed gzip`) and
compresses nothing itself, because on one core that is a second of CPU for
every player who opens the page (39 MB of engine becomes 10; the whole
download is about 23 MB).

**The dev site is the same thing in a folder of its own.**
`https://dev.DOMAIN` (an A record beside the first) serves `web/dev-game/`,
which a deploy to dev (RELEASING.md, *Deploying to dev*) fills through
`deploy.sh web-dev` by the same two renames. Both sites are one Caddyfile
importing the same two snippets - the signaling routes and the game - so the
dev site cannot drift from the live one, and the differences are its folder,
a `X-Robots-Tag: noindex` header and the port its signaling routes go to:
dev's own (below).

## Dev's signaling

The dev site talks to a signaling service of its OWN: a second copy of
`signaling/`, built from `develop`, so a protocol change can be played on dev
before production's service has to move (docs/environments.md, #1 and #2).

- **One more container, nothing else.** `deploy.sh server-dev` mirrors a
  deploy to dev's copy of this folder into `/opt/za-company/dev-server` and
  starts ONLY its `signaling` service from it, as a compose project of its own
  (`za-dev`), on `127.0.0.1:${DEV_SIGNAL_PORT}` (8766), with the live `.env`
  for its secrets and `STAGE=dev`. About 40 MB.
- **coturn and Caddy are shared, and stay the release's.** TURN relays bytes it
  never reads, so dev's logins use the same secret against the same coturn;
  there is one Caddy because there is one pair of 80/443. So a dev deploy can
  try a SIGNALING change first, and a change to the Caddyfile, the compose file
  or coturn's flags still reaches the server only with a release. The
  release's `server` job validates the Caddyfile with Caddy itself before then.
- **`/healthz` says which one answered**: `ok` for the live service, `ok dev`
  for dev's, and the dev deploy checks `https://dev.DOMAIN/healthz` says the
  second - the only proof the dev site's route reaches dev's copy.
- **The first release that carries it starts it**, from its own copy, so the
  dev site's route never points at nothing; from then on it moves only with a
  deploy to dev. By hand: `docker compose -p za-dev ps` in
  `/opt/za-company/dev-server`, and `docker compose -p za-dev logs -f
  signaling`.
- **A dev desktop build finds it too**: a deploy to dev stamps the custom
  feature `dev` into every export preset (tools/release/prepare.sh), so the
  game can ask `OS.has_feature("dev")`. A web build needs nothing - it talks to
  the signaling beside the page it was served from.

Three rules on this side hold that up:

- **`web/` is mounted, not `web/game`.** A bind mount follows the directory it
  was given, so a mounted `game/` swapped by rename would go on serving the old
  build forever.
- **Every file is `Cache-Control: no-cache`.** Godot's files keep their names
  from build to build, so without it a browser can pair a fresh `index.pck`
  with yesterday's `index.wasm`. `no-cache` revalidates by ETag; a returning
  player downloads nothing that did not change.
- **The pipeline's key can only run `deploy.sh`.** It is root's, but its
  line in `/root/.ssh/authorized_keys` is
  `restrict,command="/usr/local/sbin/za-deploy" ssh-ed25519 ... za-company release pipeline`,
  so whatever it asks for, the script runs instead, with the request in
  `SSH_ORIGINAL_COMMAND`: `web`, `web-dev`, `server` or `server-dev` and a
  tar on stdin, and nothing else - no shell, no other command, no tunnels. It is never the developer's
  key, so it is revoked without locking anybody out. `deploy.sh server`
  installs the newest copy of itself, so this folder is the one place it is
  written.

Both headers that mark a WebSocket are matched by case-insensitive regex, and
that is not tidiness: clients disagree on `Upgrade` against `upgrade`, and
Caddy's plain `header` wildcard sent the lowercase one the game's
`index.html` with a 200 instead of a 101.

## Proving it from the game (M0)

The test screen is `ui/net_spike/net_spike.tscn`, and it is in two places:
the editor (open it and press F6, Run Current Scene) and the web build, behind
two addresses nobody is sent to - `https://DOMAIN/#nettest` opens it, and
`https://DOMAIN/#join=CODE` opens it and joins that room (`&relay` after the
code forces the relay). The second is how a phone joins, since a phone cannot
type into the web build. Neither address is in a release until a release
carries this screen.

The way to run the checks is one of each, because it needs nothing installed
on the second machine and keeps the desktop plugin on the line:

1. Machine A, in the editor: run the screen (SERVER is already ours), type a
   NAME, press **HOST**. It shows a JOIN LINK; **COPY LINK** and send it to
   the other device.
2. Machine B, a second computer or a phone: open that link. It joins on its
   own, as Guest.

Two desktops work too: both run the screen in the editor, A presses HOST, B
types the code and presses JOIN. The screen shows each player's ping and
ROUTE. M0 is signed off when all four of these have been seen:

- [x] **Same network** (both machines on one Wi-Fi): connects DIRECT, ping in
      single digits. *Seen 2026-10-02: an editor host and a phone on the same
      Wi-Fi, by the join link.*
- [x] **Different networks** (a phone on mobile data, or one machine on a
      phone hotspot): connects DIRECT, ping in the tens. *Seen 2026-10-02: the
      same host and the phone on mobile data, rejoining the same room; coturn
      held no relay allocation afterwards.*
- [x] **Relay, forced**: tick FORCE RELAY on B before JOIN. It connects RELAY,
      B shows "Connected through relay", A shows the warning against B's name,
      and coturn holds the allocation. coturn 4.18 logs nothing per session at
      its default level, so look at its relay ports instead, while B is on:
      `ss -uanp | grep turnserver` shows one port in 49160-49200 per side.
      *Seen 2026-10-02 on the live server, both copies on one machine: RELAY
      at 247-269 ms, both warnings, two new relay ports.*
- [x] **Leaving**: closing A's window shows THE HOST LEFT on B, and closing B
      shows B leaving on A. *Seen 2026-10-02 on the live server, both ways.*

**M0 is signed off (2026-10-02)**: all four seen through the live server. On
one machine, DIRECT measured 7-12 ms, which is the loopback rather than a
Wi-Fi; the two real-network checks were an editor host and a phone. The mixed pair is proved on one machine too: an
editor host with the desktop plugin and a browser joining by the link connect
DIRECT, and RELAY with `&relay`, so a browser and a desktop speak the same
WebRTC through this server.

## Changing things later

- **The protocol** is documented at the top of `signaling/main.py`. Bump
  `PROTOCOL` there and in the game together. An old client is refused with
  `version` rather than misunderstood.
- **The party size** is the game's `MAX_PARTY`, sent by the host when it opens
  a room. `PARTY_CEILING` here is only a safety cap. Raise it if the game ever
  goes past 8.
- **Tests**: `cd signaling && pip install websockets==17.1 && python -m unittest test_signaling`.
  The release workflow runs them too, so a failing test stops a release.
- **Updating** is a release: the `deploy` job sends this folder to
  `deploy.sh server`, which mirrors it into `/opt/za-company/server` (keeping
  `.env` and `web/`) and runs `docker compose --profile tls up -d --build`, so
  only what changed restarts. Rooms in progress are closed by a signaling
  restart. Players who are already connected keep playing, because their game
  traffic never passes through the signaling service. A deploy to dev moves
  dev's signaling and nothing else (*Dev's signaling* above).
- **A changed `Caddyfile` recreates Caddy** rather than reloading it. It is a
  FILE bind mount, and a file replaced on disk is a new inode the running
  container never sees, so `caddy reload` would re-read the old one.
  `deploy.sh` compares the file's hash before and after and recreates the
  container only when it moved: a second's blip, certificates kept.
- **By hand**, with your own key and outside a release, the same script does
  the same thing from the repo root:

  ```sh
  tar -C server --exclude=./.env --exclude=./web --exclude=__pycache__ -cf - . \
    | ssh root@za-company.mayar-deeb.dev 'SSH_ORIGINAL_COMMAND=server za-deploy'
  ```
- **coturn 4.18** turned the admin CLI and DTLS off by default and stopped
  accepting `--no-dtls`: passing it is "unrecognized option" and a restart
  loop. The one `ERROR CONFIG: Unknown argument:` (with nothing after it) left
  in its log is not one of ours: it appears with nothing but
  `-n --log-file=stdout --no-tls`, and is harmless.
