"""Pure rendering: server snapshot in, Rich renderables out. No Textual, no I/O.

Only plain ASCII and (unless ascii mode) standard box-drawing characters are
ever produced. State is shown with words and styles, never with icon glyphs.
"""
from __future__ import annotations

import re
from dataclasses import dataclass

from rich import box
from rich.console import Group, RenderableType
from rich.panel import Panel
from rich.table import Table
from rich.text import Text

_CONTROL = re.compile(r"[\x00-\x1f\x7f-\x9f]")


def clean(s: object) -> str:
    """Strip control characters so server-supplied text can't drive the terminal."""
    return _CONTROL.sub("", str(s))


@dataclass(frozen=True)
class Theme:
    ascii: bool = False     # '+ - |' borders instead of box-drawing characters
    mono: bool = False      # no colors; bold/reverse/underline only

    @property
    def box(self) -> box.Box:
        return box.ASCII if self.ascii else box.SQUARE

    def style(self, color: str, mono: str = "") -> str:
        return mono if self.mono else color


# ---- small helpers -----------------------------------------------------
def money(n: int) -> str:
    return f"-${-n}" if n < 0 else f"${n}"


def name_of(state: dict, pid: str | None) -> str:
    p = state["players"].get(pid) if pid else None
    return clean(p["name"]) if p else "?"


def contestants(state: dict) -> list[dict]:
    return [p for pid, p in state["players"].items() if pid != state["host"]]


def current_clue(state: dict) -> tuple[dict, dict] | None:
    cur = state.get("current")
    if not cur:
        return None
    cat = state["categories"][cur[0]]
    return cat, cat["clues"][cur[1]]


def role_of(state: dict) -> str:
    you = state.get("you")
    if you is None:
        return "spectator"
    return "host" if you == state["host"] else "player"


# ---- panes -------------------------------------------------------------
def scoreboard(state: dict, th: Theme) -> RenderableType:
    """Compact: one column per contestant, three short rows (name, score, status)."""
    people = contestants(state)
    if not people:
        return Text("(no contestants yet)", style="dim")
    t = Table(box=None, expand=True, show_header=False, padding=(0, 2), pad_edge=False)
    for _ in people:
        t.add_column(justify="center", ratio=1, no_wrap=True, overflow="ellipsis")
    names, scores, status = [], [], []
    for p in people:
        pid = p["id"]
        names.append(Text(clean(p["name"]), style="reverse bold" if pid == state.get("answerer") else "bold"))
        scores.append(Text(money(p["score"]), style=th.style("red" if p["score"] < 0 else "green", "bold")))
        tags = []
        if pid == state.get("answerer"):
            tags.append("ANSWERING")
        elif pid == state.get("chooser") and state["phase"] in ("board", "wager"):
            tags.append("CHOOSING")
        elif pid in state.get("tried", []):
            tags.append("missed")
        if not p["connected"]:
            tags.append("away")
        if pid == state.get("you"):
            tags.append("you")
        status.append(Text(" ".join(tags), style="dim"))
    t.add_row(*names)
    t.add_row(*scores)
    t.add_row(*status)
    return t


def board(state: dict, th: Theme, cursor: tuple[int, int] | None = None,
          roomy: bool = False) -> RenderableType:
    cats = state["categories"]
    t = Table(box=th.box, expand=True, show_lines=roomy, padding=(0, 1))
    for cat in cats:
        t.add_column(Text(clean(cat["name"]).upper(), style=th.style("bold yellow", "bold")),
                     justify="center", ratio=1, overflow="fold")
    rows = max((len(c["clues"]) for c in cats), default=0)
    for r in range(rows):
        cells = []
        for ci, cat in enumerate(cats):
            clue = cat["clues"][r] if r < len(cat["clues"]) else None
            playable = clue is not None and not clue["answered"]
            text = Text(money(clue["value"]), style=th.style("bold cyan", "bold")) if playable else Text("")
            if cursor == (ci, r):
                text = Text(f"> {text.plain} <" if playable else ">  <", style="reverse bold")
            cells.append(text)
        t.add_row(*cells)
    return t


def clue_panel(state: dict, th: Theme) -> RenderableType:
    cc = current_clue(state)
    if cc is None:
        return Text("")
    cat, clue = cc
    title = f"{clean(cat['name']).upper()} - {money(clue['value'])}"
    if clue.get("daily_double"):
        title += " - DAILY DOUBLE"
    body = [Text(clean(clue["clue"] or ""), style="bold", justify="center")]
    if clue.get("answer"):
        body += [Text(""), Text("Answer: " + clean(clue["answer"]), style=th.style("yellow", "underline"),
                                justify="center")]
    body += [Text(""), Text(buzz_status(state), justify="center", style=th.style("cyan", "bold"))]
    return Panel(Group(*body), title=title, box=th.box, padding=(1, 2),
                 border_style=th.style("blue", ""))


def buzz_status(state: dict) -> str:
    phase, you = state["phase"], state.get("you")
    if phase == "clue":
        return "Host is reading. Wait for the buzzers to open (buzzing early locks you out briefly)."
    if phase == "buzz_open":
        return "BUZZERS OPEN" + ("  -  press SPACE!" if role_of(state) == "player"
                                 and you not in state.get("tried", []) else "")
    if phase == "answering":
        who = "You have" if state.get("answerer") == you else name_of(state, state.get("answerer")) + " has"
        return f"{who} the floor - waiting for the host to judge."
    return ""


def lobby(state: dict, th: Theme, sets: list[str], pick: int) -> RenderableType:
    host = state["host"]
    lines = [Text("LOBBY", style="bold"), Text("")]
    lines.append(Text("Host: " + (name_of(state, host) if host else "(none yet)")))
    lines.append(Text(f"Contestants: {len(contestants(state))}"))
    lines.append(Text(""))
    if role_of(state) == "host":
        lines.append(Text("Choose a question set (UP/DOWN), ENTER to start:"))
        for i, s in enumerate(sets or ["(no sets found on server)"]):
            lines.append(Text(("> " if i == pick else "  ") + clean(s),
                              style="reverse bold" if i == pick else ""))
    else:
        lines.append(Text("Waiting for the host to start the game..."))
    return Panel(Group(*lines), box=th.box, padding=(1, 2), title=clean(state["title"]))


def is_eligible(state: dict, pid: str | None) -> bool:
    p = state["players"].get(pid) if pid else None
    return bool(p) and pid != state["host"] and p["score"] > 0


def judge_order(state: dict) -> list[dict]:
    """Contestants who entered Final Jeopardy, lowest score first (as on TV)."""
    return sorted((p for p in contestants(state) if p["final_wager"] is not None
                   or p["final_answer"] is not None), key=lambda p: p["score"])


def next_to_judge(state: dict) -> dict | None:
    return next((p for p in judge_order(state) if p["final_correct"] is None), None)


def final_panel(state: dict, th: Theme) -> RenderableType:
    phase, final = state["phase"], state["final"] or {}
    you = state.get("you")
    lines: list[Text] = [Text("FINAL JEOPARDY", style="bold", justify="center"),
                         Text("Category: " + clean(final.get("category", "?")).upper(),
                              style=th.style("bold yellow", "bold"), justify="center"), Text("")]
    if final.get("clue"):
        lines += [Text(clean(final["clue"]), style="bold", justify="center"), Text("")]
    if final.get("answer") and role_of(state) == "host":
        lines += [Text("Answer: " + clean(final["answer"]), style=th.style("yellow", "underline"),
                       justify="center"), Text("")]
    if phase == "final_wager":
        lines += _final_progress(state, "final_wager", "wager locked in", "choosing a wager...")
        if role_of(state) == "player" and not is_eligible(state, you):
            lines.append(Text("You are not in Final Jeopardy (score must be above $0).", justify="center"))
    elif phase == "final_answer":
        lines += _final_progress(state, "final_answer", "answer locked in", "writing...")
    elif phase in ("final_judge", "game_over"):
        lines += _final_results(state, phase)
    return Panel(Group(*lines), box=th.box, padding=(1, 2))


def _final_progress(state: dict, field: str, done: str, waiting: str) -> list[Text]:
    """One line per Final Jeopardy contestant: has `field` been submitted yet?"""
    people = [p for p in contestants(state) if p["score"] > 0 or p["final_wager"] is not None]
    return [Text(f"{clean(p['name'])}: " + (done if p[field] is not None else waiting), justify="center")
            for p in people]


def _final_results(state: dict, phase: str) -> list[Text]:
    nxt = next_to_judge(state) if phase == "final_judge" else None
    lines = []
    for p in judge_order(state):
        res = {None: "", True: "  CORRECT", False: "  WRONG"}[p["final_correct"]]
        mark = "-> " if nxt and p["id"] == nxt["id"] else "   "
        lines.append(Text(f"{mark}{clean(p['name'])}: \"{clean(p['final_answer'])}\"  "
                          f"wagered {money(p['final_wager'])}{res}",
                          style="reverse bold" if mark == "-> " else "", justify="center"))
    return lines


def game_over(state: dict, th: Theme) -> RenderableType:
    ranked = sorted(contestants(state), key=lambda p: -p["score"])
    lines = [Text("GAME OVER", style="bold", justify="center"), Text("")]
    for i, p in enumerate(ranked, 1):
        lines.append(Text(f"{i}. {clean(p['name'])}  {money(p['score'])}",
                          style="bold" if i == 1 else "", justify="center"))
    if ranked:
        lines += [Text(""), Text(f"Winner: {clean(ranked[0]['name'])}", justify="center",
                                 style=th.style("bold yellow", "reverse bold"))]
    if state.get("host") == state.get("you"):
        lines += [Text(""), Text("Press n for a new game.", style="dim", justify="center")]
    return Panel(Group(*lines), box=th.box, padding=(1, 2))


def log_lines(state: dict, n: int = 4) -> RenderableType:
    return Text("\n".join(clean(x) for x in state["log"][-n:]), style="dim", no_wrap=True,
                overflow="ellipsis")


def hints(state: dict) -> str:
    phase, role = state["phase"], role_of(state)
    if role == "spectator":
        return "Spectating.   q quit"
    keys = {
        ("host", "lobby"): "UP/DOWN pick set   ENTER start   q quit",
        ("host", "board"): "arrows move   ENTER pick clue   a adjust score   f final   q quit",
        ("host", "clue"): "o open buzzers   s skip clue   a adjust score   q quit",
        ("host", "buzz_open"): "s skip clue (reveal answer)   a adjust score   q quit",
        ("host", "answering"): "c correct   w wrong   s skip   a adjust score   q quit",
        ("player", "board"): "arrows move   ENTER pick clue (if it's your turn)   q quit",
        ("player", "buzz_open"): "SPACE buzz   q quit",
        ("player", "clue"): "Get ready to buzz (SPACE) once buzzers open   q quit",
        ("host", "final_wager"): "n skip waiting (missing wagers count as $0)   a adjust score   q quit",
        ("host", "final_answer"): "n skip waiting for answers   a adjust score   q quit",
        ("host", "final_judge"): "c correct   w wrong (for the player marked ->)   a adjust score   q quit",
        ("host", "game_over"): "n new game   q quit",
        ("player", "wager"): "ENTER to open the wager box   q quit",
        ("player", "final_wager"): "ENTER to open the wager box   q quit",
        ("player", "final_answer"): "ENTER to open the answer box   q quit",
    }
    return keys.get((role, phase), "q quit")
