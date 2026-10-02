"""Who is in which room. Pure bookkeeping: no sockets, no asyncio, no JSON.

A room is one host and the guests who joined it by code. The host is always
peer 1, which is Godot's convention for the server of a MultiplayerAPI, and a
guest gets the next free id from 2. The topology is a STAR - a guest talks to
the host and to nobody else - so `route()` refuses guest-to-guest, and a room
is closed outright when its host goes: the host's machine IS the game.

A connection is an opaque key here. main.py passes in whatever object it has;
this file never calls a method on it, which is what lets the tests use strings.
"""

import secrets

# No 0/O, 1/I/L: a code is read aloud over voice chat and typed by hand.
ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
CODE_LENGTH = 6
HOST_ID = 1


class Refused(Exception):
    """A join or host that cannot happen; the message is the reason code sent back."""


class Room:
    def __init__(self, code: str, host, host_name: str, max_party: int):
        self.code = code
        self.max_party = max_party
        self.members = {HOST_ID: host}
        self.names = {HOST_ID: host_name}
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


class Rooms:
    def __init__(self, party_ceiling: int, max_rooms: int):
        self.party_ceiling = party_ceiling
        self.max_rooms = max_rooms
        self._rooms: dict[str, Room] = {}
        self._where: dict[object, tuple[Room, int]] = {}

    def __len__(self) -> int:
        return len(self._rooms)

    def lookup(self, conn) -> tuple[Room, int] | None:
        return self._where.get(conn)

    def open(self, host, name: str, max_party: int) -> Room:
        """A new room with `host` as peer 1. The party size is the GAME's number
        (its MAX_PARTY), clamped by the ceiling this server is willing to carry."""
        if host in self._where:
            raise Refused("already_in_room")
        if len(self._rooms) >= self.max_rooms:
            raise Refused("server_full")
        if not 2 <= max_party <= self.party_ceiling:
            raise Refused("bad_party_size")
        code = self._fresh_code()
        room = Room(code, host, name, max_party)
        self._rooms[code] = room
        self._where[host] = (room, HOST_ID)
        return room

    def join(self, conn, code: str, name: str) -> tuple[Room, int]:
        if conn in self._where:
            raise Refused("already_in_room")
        room = self._rooms.get(code.strip().upper())
        if room is None:
            raise Refused("no_such_room")
        if room.started:
            raise Refused("started")
        if room.full():
            raise Refused("room_full")
        peer_id = room.take_id()
        room.members[peer_id] = conn
        room.names[peer_id] = name
        self._where[conn] = (room, peer_id)
        return room, peer_id

    def start(self, conn) -> Room:
        """The host has started the run: nobody else may join. Only the host
        can say so, and saying it twice is saying it once."""
        found = self._where.get(conn)
        if found is None or found[1] != HOST_ID:
            raise Refused("not_host")
        found[0].started = True
        return found[0]

    def leave(self, conn) -> list[tuple[object, dict]]:
        """Take `conn` out of wherever it is, and say who must be told what.
        The host leaving closes the room for everybody still in it."""
        found = self._where.pop(conn, None)
        if found is None:
            return []
        room, peer_id = found
        if peer_id == HOST_ID:
            del self._rooms[room.code]
            told = []
            for other_id, other in room.members.items():
                if other_id != HOST_ID:
                    self._where.pop(other, None)
                    told.append((other, {"op": "closed", "reason": "host_left"}))
            return told
        del room.members[peer_id]
        del room.names[peer_id]
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

    def _fresh_code(self) -> str:
        while True:
            code = "".join(secrets.choice(ALPHABET) for _ in range(CODE_LENGTH))
            if code not in self._rooms:
                return code
