"""The signaling service: introduces a guest to a host, then gets out of the way.

It never carries a frame of the game. A host opens a room and gets a code; a
guest joins by that code; the two then trade WebRTC offers, answers and
candidates THROUGH here until they can reach each other directly (or through
coturn), after which this socket is idle for the rest of the session. It stays
open only so a leaving host can close the room and a leaving guest can be
reported gone.

The protocol is JSON text frames, each with an `op`. Client to server:

    {"op": "host", "v": 2, "name": "Mayar", "max": 4}
    {"op": "join", "v": 2, "name": "Ivo", "code": "K7Q2PX"}
    {"op": "signal", "to": 1, "data": {...}}       # opaque to this service
    {"op": "start"}                                # the host only: no more joins
    {"op": "leave"}

Server to client:

    {"op": "hosted", "code": "K7Q2PX", "id": 1, "ice": {...}}
    {"op": "joined", "code": "K7Q2PX", "id": 2, "host": "Mayar", "ice": {...}}
    {"op": "peer", "id": 2, "name": "Ivo"}         # to the host
    {"op": "gone", "id": 2}                        # to the host
    {"op": "signal", "from": 2, "data": {...}}
    {"op": "closed", "reason": "host_left"}        # to every guest
    {"op": "error", "reason": "room_full"}

`max` is the game's own MAX_PARTY, sent by the host, so the party size stays
ONE number in the game rather than a second one here; PARTY_CEILING only
stops a modified client asking this box to carry a hundred.

Version 2 added `start`: a party is joined in the lobby and never mid-run, so
once the host starts the run a `join` for that room is refused with
`started`. Everyone already in it stays, so their leaving is still reported.
A client speaking any other version is refused with `version`, which is why
dev runs a copy of this service of its own (server/README.md).
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

PROTOCOL = 2
MAX_MESSAGE = 64 * 1024
MAX_NAME = 24
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
)


def clean_name(value) -> str:
    if not isinstance(value, str):
        return "Player"
    name = "".join(ch for ch in value if ch.isprintable()).strip()[:MAX_NAME]
    return name or "Player"


def ice_for(code: str, peer_id: int) -> dict:
    return turn.ice_servers(PUBLIC_HOST, TURN_PORT, TURN_SECRET, f"{code}-{peer_id}", TURN_TTL)


async def send(ws, message: dict) -> None:
    try:
        await ws.send(json.dumps(message))
    except ConnectionClosed:
        pass


async def dispatch(ws, msg: dict) -> None:
    op = msg.get("op")
    if op in ("host", "join") and msg.get("v") != PROTOCOL:
        raise Refused("version")

    if op == "host":
        max_party = msg.get("max")
        if not isinstance(max_party, int):
            raise Refused("bad_party_size")
        room = ROOMS.open(ws, clean_name(msg.get("name")), max_party)
        log.info("room %s opened (max %d), %d open", room.code, max_party, len(ROOMS))
        await send(ws, {"op": "hosted", "code": room.code, "id": 1, "ice": ice_for(room.code, 1)})

    elif op == "join":
        code = msg.get("code")
        if not isinstance(code, str):
            raise Refused("no_such_room")
        name = clean_name(msg.get("name"))
        room, peer_id = ROOMS.join(ws, code, name)
        log.info("room %s: peer %d joined", room.code, peer_id)
        await send(ws, {"op": "joined", "code": room.code, "id": peer_id,
                        "host": room.names[1], "ice": ice_for(room.code, peer_id)})
        await send(room.host, {"op": "peer", "id": peer_id, "name": name})

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
