"""Who is in which room. Pure bookkeeping: no sockets, no asyncio, no JSON.

A room is one host and the guests who joined it by code. The host is always
peer 1, which is Godot's convention for the server of a MultiplayerAPI, and a
guest gets the next free id from 2. The topology is a STAR - a guest talks to
the host and to nobody else - so `route()` refuses guest-to-guest, and a room
is closed outright when its host goes: the host's machine IS the game.

`listing()` is the game's list of games: every room on the asker's own game
version, public or private, waiting or started, each with a STATUS that says
which - `open`, `private`, `full` or `playing` - so a player can see what is
going on in the building and not only what they can join. It never carries a
code. A row is joined by its `id` instead: a public room lets anybody in that
way, and a private one only somebody who also has its code, which is the
whole of what private means. A room is private unless its host says
otherwise, and a code alone still joins any room (a join link, an older game).

A connection is an opaque key here. main.py passes in whatever object it has;
this file never calls a method on it, which is what lets the tests use strings.
An ADDRESS is the same: whatever main.py says the far end's IP is, or None.
"""

import secrets

# No 0/O, 1/I/L: a code is read aloud over voice chat and typed by hand.
ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
CODE_LENGTH = 6
HOST_ID = 1
# How many games one listing carries, joinable ones first. The game shows
# seven at a time; this only stops a full server's answer outgrowing a frame.
LIST_LIMIT = 50
# A listing's order, best first: what a player can join, then what they could
# with a code, then what they can only look at.
STATUS_ORDER = ("open", "private", "full", "playing")


class Refused(Exception):
    """A join or host that cannot happen; the message is the reason code sent back."""


class Room:
    def __init__(self, code: str, host, host_name: str, max_party: int, *,
                 public=False, wire=None, zone=0, character="", address=None):
        self.code = code
        # What the list calls this room. Random and unrelated to the code, so
        # a private room can be shown to everybody without being opened to them.
        self.id = secrets.token_hex(6)
        self.max_party = max_party
        self.members = {HOST_ID: host}
        self.names = {HOST_ID: host_name}
        self.addresses = {HOST_ID: address}
        # Joinable from the list without the code, and only because the host
        # said so.
        self.public = public
        # The game's own protocol (its WIRE): a room is listed only to a build
        # that speaks it, since the host would refuse any other anyway.
        self.wire = wire
        # Minutes from UTC, off the host's own clock: the list's only hint of
        # where a room is. Nothing here looks an address up.
        self.zone = zone
        self.character = character
        # Addresses the host kicked, refused this room for good.
        self.banned: set[str] = set()
        # Set when the host starts the run: a party is joined in the lobby and
        # never mid-run (DESIGN.md's Multiplayer), so a started room takes
        # nobody new. Its players stay in it - their leaving still has to be
        # reported, and the host leaving still closes it.
        self.started = False
        self._next_id = HOST_ID + 1

    @property
    def host(self):
        return self.members[HOST_ID]

    def full(self) -> bool:
        return len(self.members) >= self.max_party

    def take_id(self) -> int:
        peer_id = self._next_id
        self._next_id += 1
        return peer_id

    def status(self) -> str:
        if self.started:
            return "playing"
        if self.full():
            return "full"
        return "open" if self.public else "private"

    def row(self) -> dict:
        """What the list of games says about this room. Never its code."""
        return {"id": self.id, "host": self.names[HOST_ID], "character": self.character,
                "players": len(self.members), "max": self.max_party,
                "zone": self.zone, "status": self.status()}


class Rooms:
    def __init__(self, party_ceiling: int, max_rooms: int, rooms_per_address: int = 5):
        self.party_ceiling = party_ceiling
        self.max_rooms = max_rooms
        # One address may host this many rooms at once: enough for a house
        # full of players, not enough to fill the list of open games.
        self.rooms_per_address = rooms_per_address
        self._rooms: dict[str, Room] = {}
        self._by_id: dict[str, Room] = {}
        self._where: dict[object, tuple[Room, int]] = {}

    def __len__(self) -> int:
        return len(self._rooms)

    def lookup(self, conn) -> tuple[Room, int] | None:
        return self._where.get(conn)

    def open(self, host, name: str, max_party: int, address=None, **listing) -> Room:
        """A new room with `host` as peer 1. The party size is the GAME's number
        (its MAX_PARTY), clamped by the ceiling this server is willing to carry.
        `listing` is the room's public / wire / zone / character."""
        if host in self._where:
            raise Refused("already_in_room")
        if len(self._rooms) >= self.max_rooms:
            raise Refused("server_full")
        if not 2 <= max_party <= self.party_ceiling:
            raise Refused("bad_party_size")
        if address is not None and sum(1 for room in self._rooms.values()
                                       if room.addresses[HOST_ID] == address) >= self.rooms_per_address:
            raise Refused("too_many_rooms")
        code = self._fresh_code()
        room = Room(code, host, name, max_party, address=address, **listing)
        self._rooms[code] = room
        self._by_id[room.id] = room
        self._where[host] = (room, HOST_ID)
        return room

    def join(self, conn, code: str, name: str, address=None, room_id: str | None = None) -> tuple[Room, int]:
        """Into a room by its code, or - from the list - by its `room_id`, which
        a private room also wants the right code with."""
        if conn in self._where:
            raise Refused("already_in_room")
        typed = (code or "").strip().upper()
        if room_id is not None:
            room = self._by_id.get(room_id)
            if room is None:
                raise Refused("no_such_room")
            if not room.public and typed != room.code:
                raise Refused("wrong_code")
        else:
            room = self._rooms.get(typed)
        if room is None:
            raise Refused("no_such_room")
        if address is not None and address in room.banned:
            raise Refused("kicked")
        if room.started:
            raise Refused("started")
        if room.full():
            raise Refused("room_full")
        peer_id = room.take_id()
        room.members[peer_id] = conn
        room.names[peer_id] = name
        room.addresses[peer_id] = address
        self._where[conn] = (room, peer_id)
        return room, peer_id

    def listing(self, wire) -> list[dict]:
        """Every game a build speaking `wire` is shown: joinable first, then
        oldest first within each status. A room that named no wire - a game
        from before the list - is never shown, not even to an ask that names
        none either."""
        if wire is None:
            return []
        rows = [room.row() for room in self._rooms.values() if room.wire == wire]
        rows.sort(key=lambda row: STATUS_ORDER.index(row["status"]))
        return rows[:LIST_LIMIT]

    def set_public(self, conn, public: bool) -> Room:
        """The host only: joinable from the list, or only with the code."""
        room = self._hosted_by(conn)
        room.public = public
        return room

    def kick(self, conn, peer_id: int) -> list[tuple[object, dict]]:
        """The host only: take a guest out of the room and refuse their address
        this room from now on. Only the guest is told - the host already knows,
        and its own line to the guest is what actually ends their game."""
        room = self._hosted_by(conn)
        guest = room.members.get(peer_id) if peer_id != HOST_ID else None
        if guest is None:
            raise Refused("no_such_peer")
        address = room.addresses.pop(peer_id, None)
        if address is not None:
            room.banned.add(address)
        del room.members[peer_id]
        del room.names[peer_id]
        self._where.pop(guest, None)
        return [(guest, {"op": "closed", "reason": "kicked"})]

    def start(self, conn) -> Room:
        """The host has started the run: nobody else may join. Only the host
        can say so, and saying it twice is saying it once."""
        room = self._hosted_by(conn)
        room.started = True
        return room

    def leave(self, conn) -> list[tuple[object, dict]]:
        """Take `conn` out of wherever it is, and say who must be told what.
        The host leaving closes the room for everybody still in it."""
        found = self._where.pop(conn, None)
        if found is None:
            return []
        room, peer_id = found
        if peer_id == HOST_ID:
            del self._rooms[room.code]
            del self._by_id[room.id]
            told = []
            for other_id, other in room.members.items():
                if other_id != HOST_ID:
                    self._where.pop(other, None)
                    told.append((other, {"op": "closed", "reason": "host_left"}))
            return told
        del room.members[peer_id]
        del room.names[peer_id]
        room.addresses.pop(peer_id, None)
        return [(room.host, {"op": "gone", "id": peer_id})]

    def route(self, conn, to: int):
        """Where a signal from `conn` addressed to peer `to` goes, or None. The
        host may reach any guest; a guest may reach only the host."""
        found = self._where.get(conn)
        if found is None:
            return None
        room, peer_id = found
        if to == peer_id:
            return None
        if peer_id != HOST_ID and to != HOST_ID:
            return None
        return room.members.get(to)

    def _hosted_by(self, conn) -> Room:
        found = self._where.get(conn)
        if found is None or found[1] != HOST_ID:
            raise Refused("not_host")
        return found[0]

    def _fresh_code(self) -> str:
        while True:
            code = "".join(secrets.choice(ALPHABET) for _ in range(CODE_LENGTH))
            if code not in self._rooms:
                return code
