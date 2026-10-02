"""What a client is told to use for ICE: our STUN, and a TURN login that expires.

coturn runs with `use-auth-secret`, which is the "TURN REST API" scheme: the
username is `<unix expiry>:<anything>` and the password is the base64 HMAC-SHA1
of that username under a secret only coturn and this service know. Nothing is
stored anywhere - coturn recomputes the HMAC and checks the expiry - and a
login copied out of a game client is useless a day later, which is the whole
point. A fixed TURN password baked into the game would be a free relay for the
whole internet the day anybody looked.

STUN and TURN go out as TWO lists rather than one, because the client connects
twice on purpose: STUN only first, and TURN only if that fails, which is how a
relayed connection is known to be one (see ui/net_spike/rtc_link.gd).
TURN is UDP only: the game's WebRTC is libdatachannel over libjuice, and
libjuice's TURN client does not do TCP.
"""

import base64
import hashlib
import hmac
import time


def credentials(secret: str, user: str, ttl: int, now: float | None = None) -> tuple[str, str]:
    expiry = int((time.time() if now is None else now) + ttl)
    username = f"{expiry}:{user}"
    digest = hmac.new(secret.encode(), username.encode(), hashlib.sha1).digest()
    return username, base64.b64encode(digest).decode()


def ice_servers(host: str, port: int, secret: str, user: str, ttl: int) -> dict:
    username, credential = credentials(secret, user, ttl)
    return {
        "stun": [{"urls": [f"stun:{host}:{port}"]}],
        "turn": [{
            "urls": [f"turn:{host}:{port}?transport=udp"],
            "username": username,
            "credential": credential,
        }],
    }
