"""Command-line pieces shared by the server and the client."""
from __future__ import annotations

import argparse
import os


def add_address_args(ap: argparse.ArgumentParser) -> None:
    where = ap.add_mutually_exclusive_group()
    where.add_argument("--socket", default=os.environ.get("JEOPARDY_SOCKET", "/tmp/jeopardy.sock"))
    where.add_argument("--tcp", metavar="HOST:PORT", help="e.g. 127.0.0.1:7777")


def parse_tcp(value: str) -> tuple[str, int]:
    host, _, port = value.rpartition(":")
    return host or "127.0.0.1", int(port)
