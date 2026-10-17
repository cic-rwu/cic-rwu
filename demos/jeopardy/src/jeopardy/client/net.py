"""Client side of the JSON-lines protocol."""
from __future__ import annotations

import asyncio
import json
from collections.abc import AsyncIterator

from ..protocol import MAX_LINE, encode


class Connection:
    def __init__(self, path: str | None = None, host: str | None = None, port: int | None = None):
        self.path, self.host, self.port = path, host, port
        self.reader: asyncio.StreamReader | None = None
        self.writer: asyncio.StreamWriter | None = None

    @property
    def connected(self) -> bool:
        return self.writer is not None and not self.writer.is_closing()

    async def open(self) -> None:
        if self.path:
            self.reader, self.writer = await asyncio.open_unix_connection(self.path, limit=MAX_LINE * 8)
        else:
            self.reader, self.writer = await asyncio.open_connection(self.host, self.port,
                                                                     limit=MAX_LINE * 8)

    async def send(self, **msg) -> None:
        if not self.connected:
            return
        self.writer.write(encode(msg))
        try:
            await self.writer.drain()
        except (ConnectionError, OSError):
            pass

    async def messages(self) -> AsyncIterator[dict]:
        """Yield server messages until the connection ends."""
        while self.reader is not None:
            try:
                line = await self.reader.readline()
            except (ConnectionError, OSError, ValueError):
                return
            if not line:
                return
            try:
                yield json.loads(line)
            except ValueError:
                continue

    def close(self) -> None:
        if self.writer is not None:
            self.writer.close()
