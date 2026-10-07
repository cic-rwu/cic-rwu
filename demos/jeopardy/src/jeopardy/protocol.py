"""Wire protocol: newline-delimited JSON over a stream socket.

Client -> server:  {"op": <name>, ...args}
Server -> client:  {"type": "welcome", "token": ..., "id": ...}
                   {"type": "state", "state": <snapshot>, "sets": [...]}
                   {"type": "error", "message": ...}
"""
from __future__ import annotations

import json

MAX_LINE = 16 * 1024
MAX_NAME = 20
MAX_ANSWER = 200

# op -> required argument names (join also accepts an optional token)
OPS: dict[str, tuple[str, ...]] = {
    "join": ("name", "role"),       # role: host | player | spectator; optional token
    "start": ("set",),
    "select": ("cat", "idx"),
    "open": (),
    "buzz": (),
    "judge": ("correct",),
    "skip": (),
    "wager": ("amount",),
    "adjust": ("target", "delta"),
    "start_final": (),
    "final_wager": ("amount",),
    "final_answer": ("text",),
    "judge_final": ("target", "correct"),
    "advance": (),
    "reset": (),
}

ARG_TYPES = {"cat": int, "idx": int, "amount": int, "delta": int, "correct": bool,
             "name": str, "role": str, "set": str, "target": str, "text": str, "token": str}
TYPE_WORDS = {int: "an integer", str: "a string", bool: "a boolean"}


class ProtocolError(Exception):
    pass


def encode(msg: dict) -> bytes:
    return json.dumps(msg, separators=(",", ":")).encode() + b"\n"


def decode(line: bytes) -> dict:
    """Parse and shape-check one client message."""
    try:
        msg = json.loads(line)
    except ValueError:
        raise ProtocolError("bad json") from None
    if not isinstance(msg, dict) or msg.get("op") not in OPS:
        raise ProtocolError("unknown op")
    for arg in OPS[msg["op"]]:
        if arg not in msg:
            raise ProtocolError(f"missing {arg}")
    for arg, kind in ARG_TYPES.items():
        if arg in msg and type(msg[arg]) is not kind:
            raise ProtocolError(f"{arg} must be {TYPE_WORDS[kind]}")
    return msg
