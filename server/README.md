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

Putting a build there is the release pipeline's job. Whatever runs it, a
deploy is four steps, and the server is built around each of them:

1. **Export** the "Web" preset (`export_presets.cfg`) with Godot 4.7.2 and its
   `web_nothreads_release.zip` template: `--headless --import --path .`, then
   `--headless --path . --export-release Web <out>/index.html`. Never from the
   developer's project while the editor is open - a headless export is a
   second editor writing `.godot/`.
2. **Gzip** every `.html`, `.js`, `.wasm` and `.pck` to a `.gz` beside it,
   keeping the originals (39 MB of engine becomes 10; the whole download is
   about 23 MB). Caddy serves these as they are (`precompressed gzip`) and
   compresses nothing itself: on one core that is a second of CPU for every
   player who opens the page. A deploy that skips this still works, at 54 MB.
3. **Upload** into `/opt/za-company/server/web/game.new`, never into `game/`.
4. **Swap** it in by rename: `mv game game.old && mv game.new game && rm -rf
   game.old`, in `web/`. A page loaded mid-deploy gets one whole build or the
   other, and nothing restarts.

Three rules on this side hold that up:

- **`web/` is mounted, not `web/game`.** A bind mount follows the directory it
  was given, so a mounted `game/` swapped by rename would go on serving the old
  build forever.
- **Every file is `Cache-Control: no-cache`.** Godot's files keep their names
  from build to build, so without it a browser can pair a fresh `index.pck`
  with yesterday's `index.wasm`. `no-cache` revalidates by ETag; a returning
  player downloads nothing that did not change.
- **A pipeline logs in as root with a key of its own**, added to
  `/root/.ssh/authorized_keys` - never the developer's key - so it can be
  revoked without locking anybody out.

Both headers that mark a WebSocket are matched by case-insensitive regex, and
that is not tidiness: clients disagree on `Upgrade` against `upgrade`, and
Caddy's plain `header` wildcard sent the lowercase one the game's
`index.html` with a 200 instead of a 101.

## Proving it from the game (M0)

The test screen is `tools/net_spike/net_spike.tscn`. Open it in the editor
and press F6 (Run Current Scene). Run it on two machines, each with the project
checked out and Godot 4.7.2:

1. Both: set SERVER to `wss://DOMAIN` and type a NAME.
2. Machine A: press **HOST** and read out the code.
3. Machine B: type the code and press **JOIN**.

The screen shows each player's ping and ROUTE. M0 is signed off when all four
of these have been seen:

- [ ] **Same network** (both machines on one Wi-Fi): connects DIRECT, ping in
      single digits.
- [ ] **Different networks** (put one machine on a phone hotspot): connects
      DIRECT, ping in the tens.
- [ ] **Relay, forced**: tick FORCE RELAY on B before JOIN. It connects RELAY,
      B shows "Connected through relay", A shows the warning against B's name,
      and coturn's log shows the allocation.
- [ ] **Leaving**: closing A's window shows THE HOST LEFT on B, and closing B
      shows B leaving on A.

## Changing things later

- **The protocol** is documented at the top of `signaling/main.py`. Bump
  `PROTOCOL` there and in the game together. An old client is refused with
  `version` rather than misunderstood.
- **The party size** is the game's `MAX_PARTY`, sent by the host when it opens
  a room. `PARTY_CEILING` here is only a safety cap. Raise it if the game ever
  goes past 8.
- **Tests**: `cd signaling && pip install websockets==17.1 && python -m unittest test_signaling`.
- **Updating**: copy this folder up again, then the same `docker compose ...
  up -d --build` from step 4. Ours is not a git checkout, so from the repo
  root (the excludes keep the server's own `.env` and the published game):

  ```sh
  tar -C server --exclude=.env --exclude=web --exclude=__pycache__ -cf - . \
    | ssh root@za-company.mayar-deeb.dev 'tar -C /opt/za-company/server -xf - --no-same-owner'
  ```

  A change to the `Caddyfile` alone needs no restart: `docker compose
  --profile tls exec caddy caddy reload --config /etc/caddy/Caddyfile`.
  Rooms in progress are closed by a signaling restart. Players who are
  already connected keep playing, because their game traffic never passes
  through the signaling service.
- **coturn 4.18** turned the admin CLI and DTLS off by default and stopped
  accepting `--no-dtls`: passing it is "unrecognized option" and a restart
  loop. The one `ERROR CONFIG: Unknown argument:` (with nothing after it) left
  in its log is not one of ours: it appears with nothing but
  `-n --log-file=stdout --no-tls`, and is harmless.
