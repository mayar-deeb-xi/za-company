"""The signaling service's checks: the bookkeeping on its own, then the real
socket end to end. Run from server/signaling with websockets installed:

    python -m unittest test_signaling
"""

import asyncio
import base64
import hashlib
import hmac
import json
import unittest

from websockets.asyncio.client import connect
from websockets.asyncio.server import serve

import main
import turn
from rooms import ALPHABET, CODE_LENGTH, Refused, Rooms


class TurnTest(unittest.TestCase):
    def test_login_is_coturns_hmac_of_the_username(self):
        username, credential = turn.credentials("s3cret", "ABCDEF-2", ttl=60, now=1000)
        self.assertEqual(username, "1060:ABCDEF-2")
        expected = base64.b64encode(hmac.new(b"s3cret", b"1060:ABCDEF-2", hashlib.sha1).digest()).decode()
        self.assertEqual(credential, expected)

    def test_stun_and_turn_are_separate_lists(self):
        ice = turn.ice_servers("play.example.com", 3478, "x", "u", 60)
        self.assertEqual(ice["stun"], [{"urls": ["stun:play.example.com:3478"]}])
        self.assertNotIn("username", ice["stun"][0])
        self.assertEqual(ice["turn"][0]["urls"], ["turn:play.example.com:3478?transport=udp"])


class RoomsTest(unittest.TestCase):
    def setUp(self):
        self.rooms = Rooms(party_ceiling=8, max_rooms=2)

    def test_code_shape(self):
        room = self.rooms.open("h", "Host", 4)
        self.assertEqual(len(room.code), CODE_LENGTH)
        self.assertTrue(all(ch in ALPHABET for ch in room.code))

    def test_host_is_one_and_guests_count_up(self):
        room = self.rooms.open("h", "Host", 4)
        self.assertEqual(self.rooms.join("a", room.code, "A")[1], 2)
        self.assertEqual(self.rooms.join("b", room.code.lower(), "B")[1], 3)

    def test_room_holds_exactly_max_party(self):
        room = self.rooms.open("h", "Host", 2)
        self.rooms.join("a", room.code, "A")
        with self.assertRaisesRegex(Refused, "room_full"):
            self.rooms.join("b", room.code, "B")

    def test_refusals(self):
        with self.assertRaisesRegex(Refused, "bad_party_size"):
            self.rooms.open("h", "Host", 9)
        with self.assertRaisesRegex(Refused, "no_such_room"):
            self.rooms.join("a", "NOPE00", "A")
        self.rooms.open("h1", "Host", 4)
        self.rooms.open("h2", "Host", 4)
        with self.assertRaisesRegex(Refused, "server_full"):
            self.rooms.open("h3", "Host", 4)

    def test_star_routing(self):
        room = self.rooms.open("h", "Host", 4)
        self.rooms.join("a", room.code, "A")
        self.rooms.join("b", room.code, "B")
        self.assertEqual(self.rooms.route("h", 2), "a")
        self.assertEqual(self.rooms.route("a", 1), "h")
        self.assertIsNone(self.rooms.route("a", 3), "guest to guest must be refused")
        self.assertIsNone(self.rooms.route("a", 2), "nobody signals themselves")

    def test_guest_leaving_tells_host_and_frees_a_seat(self):
        room = self.rooms.open("h", "Host", 2)
        self.rooms.join("a", room.code, "A")
        self.assertEqual(self.rooms.leave("a"), [("h", {"op": "gone", "id": 2})])
        self.assertEqual(self.rooms.join("b", room.code, "B")[1], 3, "ids are never reused")

    def test_host_leaving_closes_the_room(self):
        room = self.rooms.open("h", "Host", 4)
        self.rooms.join("a", room.code, "A")
        told = self.rooms.leave("h")
        self.assertEqual(told, [("a", {"op": "closed", "reason": "host_left"})])
        self.assertIsNone(self.rooms.lookup("a"))
        self.assertEqual(len(self.rooms), 0)


class SocketTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        main.ROOMS = Rooms(party_ceiling=8, max_rooms=10)
        main.TURN_SECRET = "test"
        self.server = await serve(main.handler, "127.0.0.1", 0, process_request=main.health)
        port = self.server.sockets[0].getsockname()[1]
        self.url = f"ws://127.0.0.1:{port}"

    async def asyncTearDown(self):
        self.server.close()
        await self.server.wait_closed()

    async def recv(self, ws):
        return json.loads(await asyncio.wait_for(ws.recv(), 2))

    async def test_host_join_signal_leave(self):
        async with connect(self.url) as host, connect(self.url) as guest:
            await host.send(json.dumps({"op": "host", "v": 1, "name": "Mayar", "max": 4}))
            hosted = await self.recv(host)
            self.assertEqual(hosted["op"], "hosted")
            self.assertEqual(hosted["id"], 1)
            self.assertIn("turn", hosted["ice"])

            await guest.send(json.dumps({"op": "join", "v": 1, "name": "Ivo", "code": hosted["code"]}))
            joined = await self.recv(guest)
            self.assertEqual((joined["op"], joined["id"], joined["host"]), ("joined", 2, "Mayar"))
            self.assertEqual(await self.recv(host), {"op": "peer", "id": 2, "name": "Ivo"})

            await guest.send(json.dumps({"op": "signal", "to": 1, "data": {"kind": "offer", "sdp": "x"}}))
            self.assertEqual(await self.recv(host),
                             {"op": "signal", "from": 2, "data": {"kind": "offer", "sdp": "x"}})

            await guest.send(json.dumps({"op": "signal", "to": 3, "data": {}}))
            self.assertEqual(await self.recv(guest), {"op": "error", "reason": "no_route"})

            await guest.close()
            self.assertEqual(await self.recv(host), {"op": "gone", "id": 2})

    async def test_host_closing_ends_room_for_guests(self):
        async with connect(self.url) as host, connect(self.url) as guest:
            await host.send(json.dumps({"op": "host", "v": 1, "name": "H", "max": 2}))
            code = (await self.recv(host))["code"]
            await guest.send(json.dumps({"op": "join", "v": 1, "name": "G", "code": code}))
            await self.recv(guest)
            await host.close()
            self.assertEqual(await self.recv(guest), {"op": "closed", "reason": "host_left"})

    async def test_wrong_protocol_and_junk(self):
        async with connect(self.url) as ws:
            await ws.send(json.dumps({"op": "host", "v": 99, "name": "H", "max": 2}))
            self.assertEqual(await self.recv(ws), {"op": "error", "reason": "version"})
            await ws.send("not json")
            self.assertEqual(await self.recv(ws), {"op": "error", "reason": "bad_json"})


if __name__ == "__main__":
    unittest.main()
