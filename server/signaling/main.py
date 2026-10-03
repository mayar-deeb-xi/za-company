"""The signaling service: introduces a guest to a host, then gets out of the way.

It never carries a frame of the game. A host opens a room and gets a code; a
guest joins by that code; the two then trade WebRTC offers, answers and
candidates THROUGH here until they can reach each other directly (or through
coturn), after which this socket is idle for the rest of the session. It stays
open only so a leaving host can close the room and a leaving guest can be
reported gone.

The protocol is JSON text frames, each with an `op`. Client to server:

    {"op": "host", "v": 3, "name": "Mayar", "max": 4,
     "public": true, "wire": 2, "zone": 180, "character": "mayar"}
    {"op": "join", "v": 3, "name": "Ivo", "code": "K7Q2PX"}
    {"op": "join", "v": 3, "name": "Ivo", "room": "3fa9c0d2b1e4", "code": ""}  # from the list
    {"op": "list", "v": 3, "wire": 2}              # every game, from anywhere
    {"op": "signal", "to": 1, "data": {...}}       # opaque to this service
    {"op": "public", "on": false}                  # the host only: code needed
    {"op": "kick", "id": 2}                        # the host only
    {"op": "start"}                                # the host only: no more joins
    {"op": "leave"}

Server to client:

    {"op": "hosted", "code": "K7Q2PX", "id": 1, "ice": {...}}
    {"op": "joined", "code": "K7Q2PX", "id": 2, "host": "Mayar", "ice": {...}}
    {"op": "rooms", "rooms": [{"id", "host", "character", "players", "max",
                               "zone", "status"}, ...]}
    {"op": "peer", "id": 2, "name": "Ivo"}         # to the host
    {"op": "gone", "id": 2}                        # to the host
    {"op": "signal", "from": 2, "data": {...}}
    {"op": "closed", "reason": "host_left"}        # to every guest; "kicked" to one
    {"op": "error", "reason": "room_full"}

`max` is the game's own MAX_PARTY, sent by the host, so the party size stays
ONE number in the game rather than a second one here; PARTY_CEILING only
stops a modified client asking this box to carry a hundred.

Version 2 added `start`: a party is joined in the lobby and never mid-run, so
once the host starts the run a `join` for that room is refused with
`started`. Everyone already in it stays, so their leaving is still reported.

Version 3 added the list of games (rooms.py's header): every room is in it
with a status and without its code, a host may make its room `public` -
joinable from the list by its `id` alone - and says which game `wire` it
speaks so only a build that can join it is shown it. A private room joined
from the list wants its code as well, or it is refused with `wrong_code`.
`zone` is the host's own clock's minutes from UTC, the list's only hint of
where a room is. `kick` takes a guest out and refuses their address that room
for good. Version 2 is still spoken, so a copy of the game from before the
list keeps playing by code: its rooms name no wire, so they are never listed,
and it never asks for the list. Any other version is refused with `version`,
which is why dev runs a copy of this service of its own (server/README.md).

An address is the far end's IP as Caddy saw it: the service listens on the
loopback only, so every connection in production came through Caddy, which
sets X-Forwarded-For itself. Without the header - a local run, the tests - it
is the socket's own peer.
"""

import asyncio
import json
import logging
import os
import signal as signals
import time
from http import HTTPStatus

from websockets.asyncio.server import serve
from websockets.exceptions import ConnectionClosed

import turn
from rooms import Refused, Rooms

PROTOCOL = 3
# Every version a client may still speak: the newest, and the one before the
# list of open games, which installed copies of the game still speak.
SPOKEN = (2, 3)
MAX_MESSAGE = 64 * 1024
MAX_NAME = 24
# A time zone is minutes from UTC, and every real one sits inside this.
ZONE_RANGE = (-12 * 60, 14 * 60)
# Per connection: a burst of candidates is ~20 messages, so this is generous
# for a real client and still stops one socket flooding a host.
RATE_MESSAGES = 200
RATE_WINDOW = 10.0

PORT = int(os.environ.get("PORT", "8765"))
PUBLIC_HOST = os.environ.get("PUBLIC_HOST", "localhost")
TURN_PORT = int(os.environ.get("TURN_PORT", "3478"))
TURN_SECRET = os.environ.get("TURN_SECRET", "")
TURN_TTL = int(os.environ.get("TURN_TTL", str(24 * 3600)))
# Which copy of this service this is: empty for the live one, "dev" for dev's
# own (server/README.md, Dev's signaling). Only ever said by /healthz, so a
# deploy can prove the dev site really reaches dev's copy - both answer "ok".
STAGE = os.environ.get("STAGE", "").strip()

log = logging.getLogger("signaling")
ROOMS = Rooms(
    party_ceiling=int(os.environ.get("PARTY_CEILING", "8")),
    max_rooms=int(os.environ.get("MAX_ROOMS", "500")),
    rooms_per_address=int(os.environ.get("ROOMS_PER_ADDRESS", "5")),
)


def clean_name(value) -> str:
    if not isinstance(value, str):
        return "Player"
    name = "".join(ch for ch in value if ch.isprintable()).strip()[:MAX_NAME]
    return name or "Player"


def clean_character(value) -> str:
    """A roster id is lower-case letters, digits and underscores; anything
    else is somebody else's string and the list shows the default body."""
    if not isinstance(value, str):
        return ""
    value = value[:MAX_NAME]
    return value if all(ch.isascii() and (ch.islower() or ch.isdigit() or ch == "_") for ch in value) else ""


def clean_zone(value) -> int:
    if not isinstance(value, int) or isinstance(value, bool):
        return 0
    return max(ZONE_RANGE[0], min(ZONE_RANGE[1], value))


def address_of(ws) -> str | None:
    """The far end's IP: the LAST X-Forwarded-For entry, which is the one
    Caddy wrote, or the socket's own peer when nothing stands in front."""
    forwarded = ws.request.headers.get("X-Forwarded-For") if ws.request is not None else None
    if forwarded:
        return forwarded.split(",")[-1].strip() or None
    remote = ws.remote_address
    return remote[0] if remote else None


def ice_for(code: str, peer_id: int) -> dict:
    return turn.ice_servers(PUBLIC_HOST, TURN_PORT, TURN_SECRET, f"{code}-{peer_id}", TURN_TTL)


async def send(ws, message: dict) -> None:
    try:
        await ws.send(json.dumps(message))
    except ConnectionClosed:
        pass


async def dispatch(ws, msg: dict) -> None:
    op = msg.get("op")
    version = msg.get("v")
    if op in ("host", "join") and version not in SPOKEN:
        raise Refused("version")
    if op == "list" and version != PROTOCOL:
        raise Refused("version")

    if op == "host":
        max_party = msg.get("max")
        if not isinstance(max_party, int):
            raise Refused("bad_party_size")
        listing = {}
        if version >= 3:
            wire = msg.get("wire")
            listing = {"public": msg.get("public") is True,
                       "wire": wire if isinstance(wire, int) and not isinstance(wire, bool) else None,
                       "zone": clean_zone(msg.get("zone")),
                       "character": clean_character(msg.get("character"))}
        room = ROOMS.open(ws, clean_name(msg.get("name")), max_party, address_of(ws), **listing)
        log.info("room %s opened (max %d%s), %d open", room.code, max_party,
                 ", public" if room.public else "", len(ROOMS))
        await send(ws, {"op": "hosted", "code": room.code, "id": 1, "ice": ice_for(room.code, 1)})

    elif op == "join":
        code, room_id = msg.get("code", ""), msg.get("room")
        if not isinstance(code, str) or (room_id is not None and not isinstance(room_id, str)):
            raise Refused("no_such_room")
        name = clean_name(msg.get("name"))
        room, peer_id = ROOMS.join(ws, code, name, address_of(ws), room_id)
        log.info("room %s: peer %d joined", room.code, peer_id)
        await send(ws, {"op": "joined", "code": room.code, "id": peer_id, "host": room.names[1],
                        "ice": ice_for(room.code, peer_id)})
        await send(room.host, {"op": "peer", "id": peer_id, "name": name})

    elif op == "list":
        await send(ws, {"op": "rooms", "rooms": ROOMS.listing(msg.get("wire"))})

    elif op == "public":
        room = ROOMS.set_public(ws, msg.get("on") is True)
        log.info("room %s: now %s", room.code, "public" if room.public else "private")

    elif op == "kick":
        peer_id = msg.get("id")
        if not isinstance(peer_id, int):
            raise Refused("no_such_peer")
        found = ROOMS.lookup(ws)
        for other, note in ROOMS.kick(ws, peer_id):
            await send(other, note)
        log.info("room %s: peer %d kicked", found[0].code, peer_id)

    elif op == "signal":
        to, data = msg.get("to"), msg.get("data")
        found = ROOMS.lookup(ws)
        target = ROOMS.route(ws, to) if isinstance(to, int) else None
        if found is None or target is None or not isinstance(data, dict):
            raise Refused("no_route")
        await send(target, {"op": "signal", "from": found[1], "data": data})

    elif op == "start":
        room = ROOMS.start(ws)
        log.info("room %s: started with %d", room.code, len(room.members))

    elif op == "leave":
        await leave(ws)

    else:
        raise Refused("bad_op")


async def leave(ws) -> None:
    found = ROOMS.lookup(ws)
    for other, note in ROOMS.leave(ws):
        await send(other, note)
    if found is not None:
        log.info("room %s: peer %d left, %d open", found[0].code, found[1], len(ROOMS))


async def handler(ws) -> None:
    window_start, count = time.monotonic(), 0
    try:
        async for raw in ws:
            now = time.monotonic()
            if now - window_start > RATE_WINDOW:
                window_start, count = now, 0
            count += 1
            if count > RATE_MESSAGES:
                await ws.close(1008, "rate")
                break
            try:
                msg = json.loads(raw) if isinstance(raw, str) else None
            except ValueError:
                msg = None
            if not isinstance(msg, dict):
                await send(ws, {"op": "error", "reason": "bad_json"})
                continue
            try:
                await dispatch(ws, msg)
            except Refused as refused:
                await send(ws, {"op": "error", "reason": str(refused)})
    except ConnectionClosed:
        pass
    finally:
        await leave(ws)


def health(connection, request):
    # Plain HTTP for a load balancer or `curl`; anything else is the WebSocket.
    if request.path == "/healthz":
        return connection.respond(HTTPStatus.OK, f"ok {STAGE}\n" if STAGE else "ok\n")
    return None


async def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    if not TURN_SECRET:
        log.warning("TURN_SECRET is empty: relay logins will be refused by coturn")
    async with serve(handler, "0.0.0.0", PORT, process_request=health,
                     max_size=MAX_MESSAGE, ping_interval=20, ping_timeout=20) as server:
        try:
            asyncio.get_running_loop().add_signal_handler(signals.SIGTERM, server.close)
        except NotImplementedError:
            pass  # Windows, for a local run; Docker on Linux has it
        log.info("signaling on :%d, telling clients STUN/TURN at %s:%d", PORT, PUBLIC_HOST, TURN_PORT)
        await server.serve_forever()


if __name__ == "__main__":
    asyncio.run(main())
