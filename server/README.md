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
  a free automatic Let's Encrypt certificate.

The plan this serves is DESIGN.md, *Multiplayer*. Godot never sees this folder
(`.gdignore`), so none of it is ever exported with the game.

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
- **Updating**: `git pull`, then the same `docker compose ... up -d --build`
  from step 4. Rooms in progress are closed by the restart. Players who are
  already connected keep playing, because their game traffic never passes
  through the signaling service.
