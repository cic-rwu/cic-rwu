"""Textual client: a thin shell around render.py and the server connection."""
from __future__ import annotations

import argparse
import asyncio
import locale
import os

from rich.console import Group
from rich.panel import Panel
from rich.text import Text
from textual import events
from textual.app import App, ComposeResult
from textual.containers import Vertical
from textual.screen import ModalScreen, Screen
from textual.widgets import Input, Static

from ..cli import add_address_args, parse_tcp
from ..protocol import MAX_NAME
from . import render
from .net import Connection
from .render import Theme

CSS = """
Screen { background: $surface; }
* { scrollbar-size: 0 0; }
#title { height: 1; text-style: bold; }
#scores { height: auto; max-height: 4; }
#main { height: 1fr; }
#log { height: 3; }
#hint { height: 1; color: $text-muted; }
Input { border: solid $primary; }
.ascii Input { border: ascii $primary; }
#join-box { width: 50; height: auto; margin: 2 4; }
PromptScreen { align: center middle; }
#prompt-box { width: 60; height: auto; border: solid $primary; background: $surface; padding: 1 2; }
.ascii #prompt-box { border: ascii $primary; }
"""

ROLES = {"p": "player", "h": "host", "s": "spectator"}
MIN_W, MIN_H = 80, 24


def parse_adjust(text: str, state: dict) -> tuple[str, int]:
    """'Ann +200' / 'bob -100' -> (player id, delta). Raises ValueError with a message."""
    parts = text.strip().rsplit(None, 1)
    if len(parts) != 2:
        raise ValueError("use: NAME +AMOUNT or NAME -AMOUNT")
    name, amount = parts
    try:
        delta = int(amount)
    except ValueError:
        raise ValueError("amount must be a whole number, e.g. +200") from None
    matches = [p for p in render.contestants(state) if p["name"].lower() == name.lower()]
    if len(matches) != 1:
        raise ValueError(f"no contestant named {name!r}")
    return matches[0]["id"], delta


class PromptScreen(ModalScreen[str | None]):
    BINDINGS = [("escape", "cancel", "Cancel")]

    def __init__(self, question: str, ascii_mode: bool = False, max_length: int = 0):
        super().__init__()
        self.question, self.max_length = question, max_length
        if ascii_mode:
            self.add_class("ascii")

    def compose(self) -> ComposeResult:
        with Vertical(id="prompt-box"):
            yield Static(Text(self.question))
            yield Input(id="answer", max_length=self.max_length)
            yield Static(Text("ENTER to submit, ESC to cancel", style="dim"))

    def on_input_submitted(self, event: Input.Submitted) -> None:
        self.dismiss(event.value)

    def action_cancel(self) -> None:
        self.dismiss(None)


class JoinScreen(Screen):
    def __init__(self):
        super().__init__()
        self.role: str | None = None

    def compose(self) -> ComposeResult:
        with Vertical(id="join-box"):
            yield Static(Text("JEOPARDY", style="bold"), id="join-title")
            yield Static(self._menu(), id="join-menu")
            yield Input(placeholder="Your name", max_length=MAX_NAME, id="name")
            yield Static(Text(""), id="join-msg")

    def on_mount(self) -> None:
        if self.app.theme_cfg.ascii:
            self.add_class("ascii")
        self.query_one("#name").display = False
        pre = self.app.pre_role
        if pre:
            self._choose(pre)

    def _menu(self) -> Text:
        return Text("Join as:  [P]layer   [H]ost   [S]pectator   (q to quit)")

    def _choose(self, role: str) -> None:
        self.role = role
        if role == "spectator":
            self.app.join("", role)
            return
        self.query_one("#join-menu", Static).update(Text(f"Joining as {role}. Enter your name:"))
        box = self.query_one("#name", Input)
        box.display = True
        pre_name = self.app.pre_name
        if pre_name:
            box.value = pre_name
        box.focus()

    def on_key(self, event: events.Key) -> None:
        if self.role is None:
            if event.character and event.character.lower() in ROLES:
                self._choose(ROLES[event.character.lower()])
                event.stop()
            elif event.character == "q":
                self.app.exit()

    def on_input_submitted(self, event: Input.Submitted) -> None:
        name = event.value.strip()
        if not name:
            self.query_one("#join-msg", Static).update(Text("Please enter a name."))
            return
        self.app.join(name, self.role)


class GameScreen(Screen):
    def __init__(self):
        super().__init__()
        self.cursor = (0, 0)
        self.pick = 0
        self.prompting = False
        self.declined: str | None = None      # phase whose prompt the player dismissed
        self._last_phase: str | None = None

    def compose(self) -> ComposeResult:
        yield Static(id="title")
        yield Static(id="scores")
        yield Static(id="main")
        yield Static(id="log")
        yield Static(id="hint")

    def on_mount(self) -> None:
        if self.app.theme_cfg.ascii:
            self.add_class("ascii")
        self.refresh_view()

    def on_resize(self, event: events.Resize) -> None:
        self.refresh_view()

    # ---- drawing -------------------------------------------------------
    def refresh_view(self) -> None:
        app, st, th = self.app, self.app.state, self.app.theme_cfg
        if st is None or not self.is_mounted:
            return
        w, h = self.size
        if w < MIN_W or h < MIN_H:
            self.query_one("#main", Static).update(
                Text(f"Terminal too small ({w}x{h}). Need at least {MIN_W}x{MIN_H}."))
            return
        if st["phase"] != self._last_phase:
            self._last_phase, self.declined = st["phase"], None
        title = f"{render.clean(st['title'])}  -  {render.role_of(st)}"
        if not app.online:
            title += "   [DISCONNECTED - retrying]"
        self.query_one("#title", Static).update(Text(title, style="bold"))
        self.query_one("#scores", Static).update(
            render.scoreboard(st, th) if st["phase"] != "lobby" else Text(""))
        self.query_one("#main", Static).update(self._main(st, th, roomy=h >= 34))
        self.query_one("#log", Static).update(render.log_lines(st, 3))
        self.query_one("#hint", Static).update(Text(render.hints(st)))
        self._maybe_prompt(st)

    def _main(self, st: dict, th: Theme, roomy: bool):
        phase = st["phase"]
        if phase == "lobby":
            return render.lobby(st, th, self.app.sets, self.pick)
        if phase == "board":
            return render.board(st, th, self.cursor if self._can_choose(st) else None, roomy)
        if phase == "wager":
            who = render.name_of(st, st["chooser"])
            return Panel(Group(Text("DAILY DOUBLE!", style="bold", justify="center"),
                               Text(f"{who} is choosing a wager...", justify="center")),
                         box=th.box, padding=(2, 2))
        if phase in ("clue", "buzz_open", "answering"):
            return render.clue_panel(st, th)
        if phase in ("final_wager", "final_answer", "final_judge"):
            return render.final_panel(st, th)
        if phase == "game_over":
            return render.game_over(st, th) if not st["final"] or not render.judge_order(st) else \
                Group(render.game_over(st, th), render.final_panel(st, th))
        return Panel(Text(f"Phase '{phase}' is not supported by this client version yet."), box=th.box)

    def _can_choose(self, st: dict) -> bool:
        return st.get("you") is not None and st["you"] in (st["host"], st["chooser"])

    # ---- prompts -------------------------------------------------------
    def _maybe_prompt(self, st: dict, force: bool = False) -> None:
        """Open the wager/answer box when it is this player's turn to supply one."""
        you, phase = st.get("you"), st["phase"]
        if self.prompting or you is None or (self.declined == phase and not force):
            return
        me = st["players"].get(you)
        if phase == "wager" and st["chooser"] == you:
            cap = max(me["score"], self._max_value(st))
            self._ask(f"Daily Double! Wager 5-{cap}:", self._send_wager, phase)
        elif phase == "final_wager" and render.is_eligible(st, you) and me["final_wager"] is None:
            self._ask(f"Final Jeopardy - wager 0-{me['score']}:", self._send_final_wager, phase)
        elif phase == "final_answer" and render.is_eligible(st, you) and me["final_answer"] is None:
            self._ask("Final Jeopardy - type your answer:", self._send_final_answer, phase, 200)

    @staticmethod
    def _max_value(st: dict) -> int:
        return max((c["value"] for cat in st["categories"] for c in cat["clues"]), default=0)

    def _ask(self, question: str, then, phase: str | None = None, max_length: int = 0) -> None:
        self.prompting = True

        def done(value: str | None) -> None:
            self.prompting = False
            self.declined = phase          # don't reopen while the server's reply is in flight
            if value is not None:
                then(value)                # may clear `declined` again on bad input
            self.refresh_view()

        self.app.push_screen(PromptScreen(question, self.app.theme_cfg.ascii, max_length), done)

    def _number(self, value: str) -> int | None:
        try:
            return int(value.strip().lstrip("$"))
        except ValueError:
            self.app.notify("Please enter a whole number.", severity="error")
            self.declined = None
            return None

    def _send_wager(self, value: str) -> None:
        if (n := self._number(value)) is not None:
            self.app.send(op="wager", amount=n)

    def _send_final_wager(self, value: str) -> None:
        if (n := self._number(value)) is not None:
            self.app.send(op="final_wager", amount=n)

    def _send_final_answer(self, value: str) -> None:
        self.app.send(op="final_answer", text=value)

    def _send_adjust(self, value: str) -> None:
        try:
            pid, delta = parse_adjust(value, self.app.state)
        except ValueError as e:
            self.app.notify(str(e), severity="error")
            return
        self.app.send(op="adjust", target=pid, delta=delta)

    # ---- keys ----------------------------------------------------------
    def on_key(self, event: events.Key) -> None:
        app = self.app
        st = app.state
        if st is None or self.prompting:
            return
        key, phase, role = event.key, st["phase"], render.role_of(st)
        if key == "q":
            app.exit()
            return
        if role == "spectator":
            return
        if phase == "lobby" and role == "host":
            n = max(len(app.sets), 1)
            if key == "up":
                self.pick = (self.pick - 1) % n
            elif key == "down":
                self.pick = (self.pick + 1) % n
            elif key == "enter" and app.sets:
                app.send(op="start", set=app.sets[self.pick])
        elif phase == "board":
            self._board_key(key, st, role)
        elif phase in ("clue", "buzz_open", "answering"):
            self._clue_key(key, phase, role)
        elif phase in ("wager", "final_wager", "final_answer"):
            if role == "player" and key == "enter":
                self._maybe_prompt(st, force=True)
            elif role == "host" and key == "n" and phase != "wager":
                app.send(op="advance")
        elif phase == "final_judge" and role == "host" and key in ("c", "w"):
            if (p := render.next_to_judge(st)):
                app.send(op="judge_final", target=p["id"], correct=(key == "c"))
        elif phase == "game_over" and role == "host" and key == "n":
            app.send(op="reset")
        if role == "host" and key == "a" and phase != "lobby":
            self._ask("Adjust score (e.g. Ann +200 or Bob -100):", self._send_adjust)
        self.refresh_view()

    def _board_key(self, key: str, st: dict, role: str) -> None:
        cats = st["categories"]
        c, r = self.cursor
        if key in ("left", "h"):
            c = max(c - 1, 0)
        elif key in ("right", "l"):
            c = min(c + 1, len(cats) - 1)
        elif key in ("up", "k"):
            r = max(r - 1, 0)
        elif key in ("down", "j"):
            r = min(r + 1, max(len(cats[c]["clues"]) - 1, 0))
        elif key == "enter":
            if self._can_choose(st):
                self.app.send(op="select", cat=c, idx=r)
            else:
                self.app.notify("It is not your turn to choose.")
        elif key == "f" and role == "host":
            self.app.send(op="start_final")
        self.cursor = (c, min(r, max(len(cats[c]["clues"]) - 1, 0)))

    def _clue_key(self, key: str, phase: str, role: str) -> None:
        send = self.app.send
        if role == "player" and key == "space" and phase in ("clue", "buzz_open"):
            send(op="buzz")
        elif role == "host":
            if key == "o" and phase == "clue":
                send(op="open")
            elif key == "c" and phase == "answering":
                send(op="judge", correct=True)
            elif key == "w" and phase == "answering":
                send(op="judge", correct=False)
            elif key == "s":
                send(op="skip")


class JeopardyApp(App):
    CSS = CSS

    def __init__(self, conn: Connection, theme: Theme, name: str | None = None,
                 role: str | None = None):
        super().__init__()
        self.conn, self.theme_cfg = conn, theme
        self.pre_name, self.pre_role = name, role
        self.state: dict | None = None
        self.sets: list[str] = []
        self.token: str | None = None
        self.online = False
        self._joined = False

    def on_mount(self) -> None:
        self.push_screen(JoinScreen())
        self.run_worker(self._net_loop(), exclusive=False)

    # ---- network -------------------------------------------------------
    def send(self, **msg) -> None:
        asyncio.ensure_future(self.conn.send(**msg))

    def join(self, name: str, role: str) -> None:
        self.send(op="join", name=name, role=role, **({"token": self.token} if self.token else {}))

    async def _net_loop(self) -> None:
        while True:
            try:
                await self.conn.open()
            except OSError:
                self.online = False
                self.state_changed()
                await asyncio.sleep(2)
                continue
            self.online = True
            if self.token:                       # reconnect as the same player
                await self.conn.send(op="join", name="", role="player", token=self.token)
            async for msg in self.conn.messages():
                self._handle_server_msg(msg)
            self.online = False
            self.state_changed()
            await asyncio.sleep(2)

    def _handle_server_msg(self, msg: dict) -> None:
        kind = msg.get("type")
        if kind == "welcome":
            self.token = msg.get("token") or self.token
            if not self._joined:
                self._joined = True
                self.switch_screen(GameScreen())
        elif kind == "state":
            self.state, self.sets = msg["state"], msg.get("sets", [])
            self.state_changed()
        elif kind == "error":
            self.notify(render.clean(msg.get("message", "error")), severity="error")
            if not self._joined and isinstance(self.screen, JoinScreen):
                self.screen.query_one("#join-msg", Static).update(
                    Text(render.clean(msg.get("message", "")), style="bold"))

    def state_changed(self) -> None:
        scr = self.screen
        if isinstance(scr, PromptScreen) and len(self.screen_stack) > 1:
            scr = self.screen_stack[-2]
        if isinstance(scr, GameScreen):
            scr.refresh_view()

    def on_unmount(self) -> None:
        self.conn.close()


def default_ascii() -> bool:
    if os.environ.get("JEOPARDY_ASCII") == "1":
        return True
    if os.environ.get("JEOPARDY_ASCII") == "0":
        return False
    enc = (locale.getpreferredencoding(False) or "").lower().replace("-", "")
    return os.environ.get("TERM") in ("linux", "vt100", "dumb") or enc not in ("utf8", "utf8mb4")


def main() -> None:
    ap = argparse.ArgumentParser(description="Jeopardy terminal client")
    add_address_args(ap)
    ap.add_argument("--ascii", action="store_true", default=None, help="plain + - | borders")
    ap.add_argument("--mono", action="store_true", help="no colors")
    ap.add_argument("--name")
    ap.add_argument("--role", choices=["player", "host", "spectator"])
    a = ap.parse_args()
    if a.tcp:
        host, port = parse_tcp(a.tcp)
        conn = Connection(host=host, port=port)
    else:
        conn = Connection(path=a.socket)
    ascii_mode = a.ascii if a.ascii is not None else default_ascii()
    JeopardyApp(conn, Theme(ascii=ascii_mode, mono=a.mono), a.name, a.role).run()


if __name__ == "__main__":
    main()
