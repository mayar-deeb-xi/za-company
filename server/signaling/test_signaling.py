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

    def test_a_started_room_takes_nobody_new(self):
        room = self.rooms.open("h", "Host", 4)
        self.rooms.join("a", room.code, "A")
        with self.assertRaisesRegex(Refused, "not_host"):
            self.rooms.start("a")
        self.rooms.start("h")
        self.rooms.start("h")  # twice is once
        with self.assertRaisesRegex(Refused, "started"):
            self.rooms.join("b", room.code, "B")
        self.assertEqual(self.rooms.leave("a"), [("h", {"op": "gone", "id": 2})],
                         "whoever is already in still leaves as before")

    def test_host_leaving_closes_the_room(self):
        room = self.rooms.open("h", "Host", 4)
        self.rooms.join("a", room.code, "A")
        told = self.rooms.leave("h")
        self.assertEqual(told, [("a", {"op": "closed", "reason": "host_left"})])
        self.assertIsNone(self.rooms.lookup("a"))
        self.assertEqual(len(self.rooms), 0)


class ListingTest(unittest.TestCase):
    def setUp(self):
        self.rooms = Rooms(party_ceiling=8, max_rooms=20, rooms_per_address=2)

    def test_every_game_is_listed_with_its_status_and_never_its_code(self):
        started = self.rooms.open("h3", "Started", 4, public=True, wire=2)
        self.rooms.start("h3")
        self.rooms.open("h2", "Private", 4, wire=2)
        full = self.rooms.open("h4", "Full", 2, public=True, wire=2)
        self.rooms.join("g4", full.code, "G")
        shown = self.rooms.open("h1", "Reem", 4, public=True, wire=2, zone=180, character="reem")
        self.rooms.open("h5", "Other build", 4, public=True, wire=3)
        rows = self.rooms.listing(2)
        self.assertEqual([(row["host"], row["status"]) for row in rows],
                         [("Reem", "open"), ("Private", "private"), ("Full", "full"), ("Started", "playing")],
                         "joinable first, then what wants a code, then what can only be looked at")
        self.assertEqual(rows[0], {"id": shown.id, "host": "Reem", "character": "reem",
                                   "players": 1, "max": 4, "zone": 180, "status": "open"})
        self.assertTrue(all("code" not in row for row in rows), "a listing never gives a code away")
        self.assertNotIn(started.code, json.dumps(rows))
        self.assertEqual([row["host"] for row in self.rooms.listing(3)], ["Other build"])
        self.assertEqual(self.rooms.listing(None), [], "an ask that names no wire is shown nothing")

    def test_a_game_from_before_the_list_is_never_shown(self):
        self.rooms.open("old", "Old", 4)
        self.assertEqual(self.rooms.listing(None), [])
        self.assertEqual(self.rooms.listing(2), [])

    def test_a_guest_counts_and_leaving_frees_the_seat(self):
        room = self.rooms.open("h", "Host", 2, public=True, wire=2)
        self.rooms.join("a", room.code, "A")
        self.assertEqual(self.rooms.listing(2)[0]["status"], "full")
        self.rooms.leave("a")
        self.assertEqual((self.rooms.listing(2)[0]["status"], self.rooms.listing(2)[0]["players"]), ("open", 1))

    def test_only_the_host_switches_it(self):
        room = self.rooms.open("h", "Host", 4, wire=2)
        self.rooms.join("a", room.code, "A")
        with self.assertRaisesRegex(Refused, "not_host"):
            self.rooms.set_public("a", True)
        self.rooms.set_public("h", True)
        self.assertEqual(self.rooms.listing(2)[0]["status"], "open")
        self.rooms.set_public("h", False)
        self.assertEqual(self.rooms.listing(2)[0]["status"], "private")

    def test_joining_from_the_list(self):
        public = self.rooms.open("h1", "Open", 4, public=True, wire=2)
        private = self.rooms.open("h2", "Shut", 4, wire=2)
        self.assertEqual(self.rooms.join("a", "", "A", room_id=public.id)[0], public,
                         "a public game needs no code")
        with self.assertRaisesRegex(Refused, "wrong_code"):
            self.rooms.join("b", "", "B", room_id=private.id)
        with self.assertRaisesRegex(Refused, "wrong_code"):
            self.rooms.join("b", public.code, "B", room_id=private.id)
        self.assertEqual(self.rooms.join("b", private.code.lower(), "B", room_id=private.id)[0], private)
        with self.assertRaisesRegex(Refused, "no_such_room"):
            self.rooms.join("c", "", "C", room_id="nope")
        self.assertEqual(self.rooms.join("d", private.code, "D")[0], private,
                         "a code alone still joins: the join link, and games from before the list")
        self.rooms.leave("h2")
        with self.assertRaisesRegex(Refused, "no_such_room"):
            self.rooms.join("e", private.code, "E", room_id=private.id)

    def test_kick_tells_only_the_guest_and_bans_the_address(self):
        room = self.rooms.open("h", "Host", 4, address="1.1.1.1")
        self.rooms.join("a", room.code, "A", address="2.2.2.2")
        self.rooms.join("b", room.code, "B", address="3.3.3.3")
        with self.assertRaisesRegex(Refused, "not_host"):
            self.rooms.kick("b", 2)
        self.assertEqual(self.rooms.kick("h", 2), [("a", {"op": "closed", "reason": "kicked"})])
        self.assertIsNone(self.rooms.lookup("a"))
        self.assertEqual(self.rooms.leave("a"), [], "a kicked guest's own leave is nothing")
        with self.assertRaisesRegex(Refused, "kicked"):
            self.rooms.join("a2", room.code, "A again", address="2.2.2.2")
        self.assertEqual(self.rooms.join("c", room.code, "C", address="4.4.4.4")[1], 4)
        with self.assertRaisesRegex(Refused, "no_such_peer"):
            self.rooms.kick("h", 1)
        with self.assertRaisesRegex(Refused, "no_such_peer"):
            self.rooms.kick("h", 2)

    def test_one_address_hosts_only_so_many(self):
        self.rooms.open("h1", "A", 4, address="9.9.9.9")
        self.rooms.open("h2", "B", 4, address="9.9.9.9")
        with self.assertRaisesRegex(Refused, "too_many_rooms"):
            self.rooms.open("h3", "C", 4, address="9.9.9.9")
        self.rooms.open("h4", "D", 4, address="8.8.8.8")
        self.rooms.leave("h1")
        self.rooms.open("h5", "E", 4, address="9.9.9.9")


class CleaningTest(unittest.TestCase):
    def test_character_zone_and_address(self):
        self.assertEqual(main.clean_character("mayar"), "mayar")
        self.assertEqual(main.clean_character("<b>Mayar</b>"), "")
        self.assertEqual(main.clean_character(7), "")
        self.assertEqual(main.clean_zone(180), 180)
        self.assertEqual(main.clean_zone(99999), 14 * 60)
        self.assertEqual(main.clean_zone(True), 0)
        self.assertEqual(main.clean_zone("180"), 0)

        class Request:
            def __init__(self, headers):
                self.headers = headers

        class Socket:
            def __init__(self, headers, remote):
                self.request = Request(headers)
                self.remote_address = remote

        # The last entry is the one Caddy wrote; anything before it the client did.
        self.assertEqual(main.address_of(Socket({"X-Forwarded-For": "6.6.6.6, 5.5.5.5"}, ("127.0.0.1", 1))),
                         "5.5.5.5")
        self.assertEqual(main.address_of(Socket({}, ("127.0.0.1", 1))), "127.0.0.1")


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
            await host.send(json.dumps({"op": "host", "v": main.PROTOCOL, "name": "Mayar", "max": 4}))
            hosted = await self.recv(host)
            self.assertEqual(hosted["op"], "hosted")
            self.assertEqual(hosted["id"], 1)
            self.assertIn("turn", hosted["ice"])

            await guest.send(json.dumps({"op": "join", "v": main.PROTOCOL, "name": "Ivo", "code": hosted["code"]}))
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
            await host.send(json.dumps({"op": "host", "v": main.PROTOCOL, "name": "H", "max": 2}))
            code = (await self.recv(host))["code"]
            await guest.send(json.dumps({"op": "join", "v": main.PROTOCOL, "name": "G", "code": code}))
            await self.recv(guest)
            await host.close()
            self.assertEqual(await self.recv(guest), {"op": "closed", "reason": "host_left"})

    async def test_start_closes_the_door_over_the_wire(self):
        async with connect(self.url) as host, connect(self.url) as late:
            await host.send(json.dumps({"op": "host", "v": main.PROTOCOL, "name": "H", "max": 4}))
            code = (await self.recv(host))["code"]
            await host.send(json.dumps({"op": "start"}))
            await late.send(json.dumps({"op": "join", "v": main.PROTOCOL, "name": "L", "code": code}))
            self.assertEqual(await self.recv(late), {"op": "error", "reason": "started"})

    async def test_health_names_its_stage(self):
        # The live service says "ok"; dev's own copy says so, which is how a
        # deploy proves the dev site's route reaches dev's copy and not ours.
        class Request:
            path = "/healthz"

        class Connection:
            def respond(self, status, body):
                return status, body

        saved = main.STAGE
        try:
            main.STAGE = ""
            self.assertEqual(main.health(Connection(), Request())[1], "ok\n")
            main.STAGE = "dev"
            self.assertEqual(main.health(Connection(), Request())[1], "ok dev\n")
        finally:
            main.STAGE = saved

    async def test_wrong_protocol_and_junk(self):
        async with connect(self.url) as ws:
            await ws.send(json.dumps({"op": "host", "v": 99, "name": "H", "max": 2}))
            self.assertEqual(await self.recv(ws), {"op": "error", "reason": "version"})
            await ws.send(json.dumps({"op": "list", "v": 2, "wire": 2}))
            self.assertEqual(await self.recv(ws), {"op": "error", "reason": "version"},
                             "the list is version 3's")
            await ws.send("not json")
            self.assertEqual(await self.recv(ws), {"op": "error", "reason": "bad_json"})

    async def host(self, ws, **extra):
        await ws.send(json.dumps({"op": "host", "v": main.PROTOCOL, "name": "Mayar", "max": 4,
                                  "wire": 2, "zone": 180, "character": "mayar", **extra}))
        return (await self.recv(ws))["code"]

    async def listing(self, ws, wire=2):
        await ws.send(json.dumps({"op": "list", "v": main.PROTOCOL, "wire": wire}))
        answer = await self.recv(ws)
        self.assertEqual(answer["op"], "rooms")
        return answer["rooms"]

    async def test_the_list_over_the_wire(self):
        async with connect(self.url) as host, connect(self.url) as looker:
            code = await self.host(host, public=True)
            rows = await self.listing(looker)
            self.assertEqual(len(rows), 1)
            self.assertEqual({k: v for k, v in rows[0].items() if k != "id"}, {
                "host": "Mayar", "character": "mayar", "players": 1, "max": 4,
                "zone": 180, "status": "open"})
            self.assertNotIn(code, json.dumps(rows), "the code never goes out in the list")
            self.assertEqual(await self.listing(looker, wire=3), [], "another build sees nothing")
            await host.send(json.dumps({"op": "public", "on": False}))
            self.assertEqual((await self.listing(looker))[0]["status"], "private")
            await host.send(json.dumps({"op": "public", "on": True}))
            self.assertEqual((await self.listing(looker))[0]["status"], "open")
            await host.send(json.dumps({"op": "start"}))
            self.assertEqual((await self.listing(looker))[0]["status"], "playing")

    async def test_a_room_is_private_unless_it_asks(self):
        async with connect(self.url) as host, connect(self.url) as looker:
            await self.host(host)
            self.assertEqual((await self.listing(looker))[0]["status"], "private")

    async def test_a_private_game_from_the_list_wants_its_code(self):
        async with connect(self.url) as host, connect(self.url) as guest, connect(self.url) as looker:
            code = await self.host(host)
            room_id = (await self.listing(looker))[0]["id"]
            await guest.send(json.dumps({"op": "join", "v": main.PROTOCOL, "name": "G",
                                         "room": room_id, "code": "WRONG2"}))
            self.assertEqual(await self.recv(guest), {"op": "error", "reason": "wrong_code"})
            await guest.send(json.dumps({"op": "join", "v": main.PROTOCOL, "name": "G",
                                         "room": room_id, "code": code.lower()}))
            self.assertEqual((await self.recv(guest))["op"], "joined")

    async def test_version_two_still_plays_and_is_never_listed(self):
        async with connect(self.url) as host, connect(self.url) as guest, connect(self.url) as looker:
            await host.send(json.dumps({"op": "host", "v": 2, "name": "Old", "max": 4, "public": True}))
            code = (await self.recv(host))["code"]
            await guest.send(json.dumps({"op": "join", "v": 2, "name": "G", "code": code}))
            self.assertEqual((await self.recv(guest))["op"], "joined")
            self.assertEqual(await self.listing(looker, wire=None), [])

    async def test_kick_over_the_wire(self):
        async with connect(self.url) as host, connect(self.url) as guest, connect(self.url) as again:
            code = await self.host(host, public=True)
            await guest.send(json.dumps({"op": "join", "v": main.PROTOCOL, "name": "G", "code": code}))
            await self.recv(guest)
            await self.recv(host)  # the peer note
            await host.send(json.dumps({"op": "kick", "id": 2}))
            self.assertEqual(await self.recv(guest), {"op": "closed", "reason": "kicked"})
            # Every socket here is 127.0.0.1, so the second one is the same address.
            await again.send(json.dumps({"op": "join", "v": main.PROTOCOL, "name": "G", "code": code}))
            self.assertEqual(await self.recv(again), {"op": "error", "reason": "kicked"})
            await guest.send(json.dumps({"op": "kick", "id": 1}))
            self.assertEqual(await self.recv(guest), {"op": "error", "reason": "not_host"})


if __name__ == "__main__":
    unittest.main()
