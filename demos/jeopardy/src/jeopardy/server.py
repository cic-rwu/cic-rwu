"""Asyncio game server: the single source of truth for one shared game."""
from __future__ import annotations

import argparse
import asyncio
import json
import logging
import os
import re
import secrets
import time
from pathlib import Path
from typing import Callable

from .cli import add_address_args, parse_tcp
from .engine import ActionError, Engine
from .loader import LoadError, load_set
from .model import Game
from .protocol import MAX_ANSWER, MAX_LINE, MAX_NAME, ProtocolError, decode, encode

log = logging.getLogger("jeopardy")

SAFE_SET = re.compile(r"^[A-Za-z0-9_-]+$")


class GameServer:
    def __init__(self, games_dir: str | Path = "games", state_path: str | Path | None = None,
                 clock: Callable[[], float] = time.monotonic, allow_name_reclaim: bool = False):
        self.allow_name_reclaim = allow_name_reclaim
        self.games_dir = Path(games_dir)
        self.state_path = Path(state_path) if state_path else None
        self.clock = clock
        self.engine = Engine(on_log=log.info)
        self.tokens: dict[str, str] = {}              # secret token -> public player id
        self.conns: dict[asyncio.StreamWriter, str | None] = {}   # writer -> player id
        self._load_state()

    # ---- persistence ---------------------------------------------------
    def _load_state(self) -> None:
        if not self.state_path or not self.state_path.exists():
            return
        try:
            data = json.loads(self.state_path.read_text())
            self.engine = Engine(Game.model_validate(data["game"]), on_log=log.info)
            self.tokens = data["tokens"]
        except (OSError, ValueError, KeyError):
            return                                     # unreadable state: start fresh
        for p in self.engine.game.players.values():
            p.connected = False

    def _save_state(self) -> None:
        if not self.state_path:
            return
        data = {"game": self.engine.game.model_dump(mode="json"), "tokens": self.tokens}
        tmp = self.state_path.with_suffix(".tmp")
        tmp.write_text(json.dumps(data))
        os.replace(tmp, self.state_path)

    # ---- sets ----------------------------------------------------------
    def available_sets(self) -> list[str]:
        if not self.games_dir.is_dir():
            return []
        return sorted(p.stem for p in self.games_dir.iterdir()
                      if p.suffix in (".yaml", ".yml", ".json"))

    def _find_set(self, name: str) -> Path:
        if not SAFE_SET.match(name):
            raise ActionError("bad set name")
        for ext in (".yaml", ".yml", ".json"):
            p = self.games_dir / (name + ext)
            if p.is_file():
                return p
        raise ActionError("no such set")

    # ---- messaging -----------------------------------------------------
    def _state_msg(self, pid: str | None) -> bytes:
        return encode({"type": "state", "state": self.engine.snapshot(pid),
                       "sets": self.available_sets()})

    def _name(self, pid: str | None) -> str:
        p = self.engine.game.players.get(pid) if pid else None
        return p.name if p else "unjoined"

    def _who(self, w: asyncio.StreamWriter) -> str:
        return self._name(self.conns.get(w))

    async def broadcast(self) -> None:
        dropped = False
        for w, pid in list(self.conns.items()):
            try:
                w.write(self._state_msg(pid))
                await w.drain()
            except (ConnectionError, OSError):
                dropped |= self._drop(w)
        if dropped:
            await self._publish()

    async def _publish(self) -> None:
        """Save the game, then send the new state to everyone."""
        self._save_state()
        await self.broadcast()

    def _drop(self, w: asyncio.StreamWriter) -> bool:
        """Forget a connection. True if that left its player disconnected."""
        pid = self.conns.pop(w, None)
        log.debug("connection closed (%s)", self._name(pid))
        if pid and pid not in self.conns.values():
            self.engine.disconnect(pid)
            log.info("%s disconnected", self._name(pid))
            return True
        return False

    # ---- actions -------------------------------------------------------
    def _welcome(self, w: asyncio.StreamWriter, pid: str | None, token: str | None) -> dict:
        self.conns[w] = pid
        return {"type": "welcome", "token": token, "id": pid}

    def _join(self, w: asyncio.StreamWriter, msg: dict) -> dict:
        e = self.engine
        if self.conns.get(w) is not None:
            raise ActionError("already joined")
        role, token = msg["role"], msg.get("token")
        if token in self.tokens and self.tokens[token] in e.game.players:   # reconnect
            pid = self.tokens[token]
            e.join(pid, e.game.players[pid].name)
            return self._welcome(w, pid, token)
        if role == "spectator":
            return self._welcome(w, None, None)
        if role not in ("host", "player"):
            raise ActionError("bad role")
        name = msg["name"].strip()
        if not name or len(name) > MAX_NAME or not name.isprintable():
            raise ActionError(f"name must be 1-{MAX_NAME} printable characters")
        if self.allow_name_reclaim and (pid := self._reclaimable(name, role)):
            self.tokens = {t: p for t, p in self.tokens.items() if p != pid}   # revoke old tokens
            e.join(pid, name)
        else:
            pid = secrets.token_hex(4)
            e.join(pid, name, host=(role == "host"))
        token = secrets.token_urlsafe(16)
        self.tokens[token] = pid
        return self._welcome(w, pid, token)

    def _reclaimable(self, name: str, role: str) -> str | None:
        """A disconnected seat with this name and the same kind of role, if any."""
        g = self.engine.game
        for pid, p in g.players.items():
            if p.name.lower() == name.lower() and not p.connected and \
                    (role == "host") == (pid == g.host):
                return pid
        return None

    def _act(self, pid: str, msg: dict) -> None:
        e, op = self.engine, msg["op"]
        if op == "start":
            try:
                qs = load_set(self._find_set(msg["set"]))
            except LoadError as err:
                raise ActionError(f"bad set: {err}") from None
            e.start(pid, qs)
        elif op == "select":
            e.select_clue(pid, msg["cat"], msg["idx"])
        elif op == "open":
            e.open_buzzers(pid, self.clock())
        elif op == "buzz":
            e.buzz(pid, self.clock())
        elif op == "judge":
            e.judge(pid, msg["correct"])
        elif op == "skip":
            e.skip_clue(pid)
        elif op == "wager":
            e.set_wager(pid, msg["amount"])
        elif op == "adjust":
            e.adjust_score(pid, msg["target"], msg["delta"])
        elif op == "start_final":
            e.start_final(pid)
        elif op == "final_wager":
            e.final_wager(pid, msg["amount"])
        elif op == "final_answer":
            e.final_answer(pid, msg["text"][:MAX_ANSWER])
        elif op == "judge_final":
            e.judge_final(pid, msg["target"], msg["correct"])
        elif op == "advance":
            e.force_advance(pid)
        elif op == "reset":
            e.reset(pid)

    async def handle(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        self.conns[writer] = None
        log.debug("connection opened")
        try:
            while line := await reader.readline():
                reply = None
                try:
                    msg = decode(line)
                    log.debug("op %s from %s", msg["op"], self._who(writer))
                    if msg["op"] == "join":
                        reply = self._join(writer, msg)
                    elif self.conns.get(writer) is None:
                        raise ActionError("join first")
                    else:
                        self._act(self.conns[writer], msg)
                except (ProtocolError, ActionError) as err:
                    log.debug("rejected from %s: %s", self._who(writer), err)
                    writer.write(encode({"type": "error", "message": str(err)}))
                    await writer.drain()
                    continue
                if reply:
                    writer.write(encode(reply))
                await self._publish()
        except (ConnectionError, asyncio.LimitOverrunError, ValueError):
            pass
        finally:
            if self._drop(writer):
                await self._publish()
            writer.close()


async def serve(server: GameServer, *, path: str | None = None, host: str | None = None,
                port: int | None = None) -> asyncio.AbstractServer:
    if path:
        if os.path.exists(path):
            os.unlink(path)
        srv = await asyncio.start_unix_server(server.handle, path=path, limit=MAX_LINE)
        os.chmod(path, 0o660)
        return srv
    return await asyncio.start_server(server.handle, host, port, limit=MAX_LINE)


def main() -> None:
    ap = argparse.ArgumentParser(description="Jeopardy game server")
    add_address_args(ap)
    ap.add_argument("--games-dir", default="games")
    ap.add_argument("--allow-name-reclaim", action="store_true",
                    help="let a new connection take over a DISCONNECTED seat by typing its name "
                         "(for trusted groups sharing one SSH account; anyone can impersonate "
                         "an absent player)")
    ap.add_argument("--state", default="state.json", help="persisted game state file")
    ap.add_argument("-v", "--verbose", action="store_true",
                    help="also log connections and every op (never op arguments)")
    args = ap.parse_args()
    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.INFO,
                        format="%(asctime)s %(message)s", datefmt="%H:%M:%S")
    gs = GameServer(args.games_dir, args.state, allow_name_reclaim=args.allow_name_reclaim)

    async def run() -> None:
        if args.tcp:
            host, port = parse_tcp(args.tcp)
            srv = await serve(gs, host=host, port=port)
        else:
            srv = await serve(gs, path=args.socket)
        async with srv:
            await srv.serve_forever()

    try:
        asyncio.run(run())
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
