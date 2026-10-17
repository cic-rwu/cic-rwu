"""Pure game state machine. No I/O; time is passed in by the caller."""
from __future__ import annotations

from collections.abc import Callable

from .model import Clue, Game, Phase, Player, QuestionSet

EARLY_BUZZ_LOCKOUT = 0.25   # seconds
MIN_WAGER = 5
LOG_LIMIT = 50


class ActionError(Exception):
    """An action was invalid in the current state."""


class Engine:
    def __init__(self, game: Game | None = None, on_log: Callable[[str], None] | None = None):
        self.on_log = on_log
        self.game = game or Game()

    # ---- helpers -------------------------------------------------------
    def _log(self, msg: str) -> None:
        self.game.log.append(msg)
        if self.on_log:
            self.on_log(msg)
        del self.game.log[:-LOG_LIMIT]

    def _need(self, *phases: Phase) -> None:
        if self.game.phase not in phases:
            raise ActionError(f"not allowed during {self.game.phase.value}")

    def _need_host(self, pid: str) -> None:
        if pid != self.game.host:
            raise ActionError("host only")

    def _player(self, pid: str) -> Player:
        try:
            return self.game.players[pid]
        except KeyError:
            raise ActionError("unknown player") from None

    def current_clue(self) -> Clue:
        if self.game.current is None:
            raise ActionError("no active clue")
        c, i = self.game.current
        return self.game.categories[c].clues[i]

    def contestants(self) -> list[Player]:
        return [p for pid, p in self.game.players.items() if pid != self.game.host]

    def max_board_value(self) -> int:
        return max((c.value for cat in self.game.categories for c in cat.clues), default=0)

    # ---- lobby ---------------------------------------------------------
    def join(self, pid: str, name: str, host: bool = False) -> None:
        g = self.game
        if pid in g.players:                      # reconnect
            g.players[pid].connected = True
            self._log(f"{g.players[pid].name} reconnected")
            return
        if any(p.name.lower() == name.lower() for p in g.players.values()):
            raise ActionError("name taken")
        if host and g.host is not None:
            raise ActionError("host already claimed")
        g.players[pid] = Player(id=pid, name=name)
        if host:
            g.host = pid
        self._log(f"{name} joined")

    def disconnect(self, pid: str) -> None:
        if pid in self.game.players:
            self.game.players[pid].connected = False

    def start(self, pid: str, qs: QuestionSet) -> None:
        self._need_host(pid)
        self._need(Phase.LOBBY)
        people = self.contestants()
        if not people:
            raise ActionError("need at least one contestant")
        g = self.game
        g.title, g.final = qs.title, qs.final
        g.categories = [c.model_copy(deep=True) for c in qs.categories]
        g.chooser = people[0].id
        g.phase = Phase.BOARD
        self._log("game started")

    def reset(self, pid: str) -> None:
        """Back to the lobby with the same people, scores zeroed."""
        self._need_host(pid)
        g = self.game
        for p in g.players.values():
            p.score, p.final_wager, p.final_answer, p.final_correct = 0, None, None, None
        g.categories, g.final, g.chooser, g.current = [], None, None, None
        g.answerer, g.wager, g.buzz_opened_at, g.tried, g.lockouts = None, None, None, [], {}
        g.phase = Phase.LOBBY
        self._log("game reset")

    # ---- board ---------------------------------------------------------
    def select_clue(self, pid: str, cat: int, idx: int) -> None:
        g = self.game
        self._need(Phase.BOARD)
        if pid not in (g.chooser, g.host):
            raise ActionError("not your turn to choose")
        try:
            clue = g.categories[cat].clues[idx]
        except IndexError:
            raise ActionError("no such clue") from None
        if clue.answered:
            raise ActionError("already played")
        g.current = (cat, idx)
        g.tried, g.lockouts, g.wager, g.answerer = [], {}, None, None
        g.phase = Phase.WAGER if clue.daily_double else Phase.CLUE
        self._log(f"{g.categories[cat].name} for {clue.value}")

    def _finish_clue(self) -> None:
        g = self.game
        clue = self.current_clue()
        clue.answered = True
        self._log(f"answer: {clue.answer}")
        g.current = g.answerer = g.wager = g.buzz_opened_at = None
        g.tried, g.lockouts = [], {}
        g.phase = Phase.BOARD

    # ---- daily double --------------------------------------------------
    def max_wager(self, pid: str) -> int:
        return max(self._player(pid).score, self.max_board_value())

    def set_wager(self, pid: str, amount: int) -> None:
        g = self.game
        self._need(Phase.WAGER)
        if pid != g.chooser:
            raise ActionError("only the chooser wagers")
        if not MIN_WAGER <= amount <= self.max_wager(pid):
            raise ActionError(f"wager must be {MIN_WAGER}-{self.max_wager(pid)}")
        g.wager, g.answerer, g.phase = amount, pid, Phase.ANSWERING

    # ---- buzzing -------------------------------------------------------
    def open_buzzers(self, pid: str, now: float) -> None:
        self._need_host(pid)
        self._need(Phase.CLUE)
        g = self.game
        g.phase, g.buzz_opened_at = Phase.BUZZ_OPEN, now

    def buzz(self, pid: str, now: float) -> bool:
        """Returns True if this buzz won the floor."""
        g = self.game
        self._player(pid)
        if pid == g.host:
            raise ActionError("host cannot buzz")
        self._need(Phase.CLUE, Phase.BUZZ_OPEN)
        if now < g.lockouts.get(pid, 0):
            return False
        if g.phase == Phase.CLUE:               # early: locked out briefly
            g.lockouts[pid] = now + EARLY_BUZZ_LOCKOUT
            return False
        if pid in g.tried:
            return False
        g.answerer, g.phase = pid, Phase.ANSWERING
        self._log(f"{g.players[pid].name} buzzed")
        return True

    # ---- judging -------------------------------------------------------
    def judge(self, pid: str, correct: bool) -> None:
        self._need_host(pid)
        self._need(Phase.ANSWERING)
        g = self.game
        clue = self.current_clue()
        who = self._player(g.answerer)
        stake = g.wager if g.wager is not None else clue.value
        if correct:
            who.score += stake
            g.chooser = who.id
            self._log(f"{who.name} correct +{stake}")
            self._finish_clue()
            return
        who.score -= stake
        self._log(f"{who.name} wrong -{stake}")
        if g.wager is not None:                  # daily double: no second chance
            self._finish_clue()
            return
        g.tried.append(who.id)
        g.answerer = None
        if all(p.id in g.tried for p in self.contestants()):
            self._finish_clue()
        else:
            g.phase = Phase.BUZZ_OPEN

    def skip_clue(self, pid: str) -> None:
        self._need_host(pid)
        self._need(Phase.CLUE, Phase.BUZZ_OPEN, Phase.ANSWERING, Phase.WAGER)
        self._finish_clue()

    def adjust_score(self, pid: str, target: str, delta: int) -> None:
        self._need_host(pid)
        self._player(target).score += delta
        self._log(f"host adjusted {self._player(target).name} by {delta:+d}")

    # ---- final jeopardy ------------------------------------------------
    def final_eligible(self) -> list[Player]:
        return [p for p in self.contestants() if p.score > 0]

    def start_final(self, pid: str) -> None:
        self._need_host(pid)
        self._need(Phase.BOARD)
        if self.game.final is None:
            raise ActionError("no final clue in this set")
        if not self.final_eligible():
            self.game.phase = Phase.GAME_OVER
            return
        self.game.phase = Phase.FINAL_WAGER

    def final_wager(self, pid: str, amount: int) -> None:
        self._need(Phase.FINAL_WAGER)
        p = self._player(pid)
        if p not in self.final_eligible():
            raise ActionError("not eligible")
        if not 0 <= amount <= p.score:
            raise ActionError(f"wager must be 0-{p.score}")
        p.final_wager = amount
        if all(q.final_wager is not None for q in self.final_eligible()):
            self.game.phase = Phase.FINAL_ANSWER

    def final_answer(self, pid: str, text: str) -> None:
        self._need(Phase.FINAL_ANSWER)
        p = self._player(pid)
        if p not in self.final_eligible():
            raise ActionError("not eligible")
        p.final_answer = text.strip() or "(no answer)"
        if all(q.final_answer is not None for q in self.final_eligible()):
            self.game.phase = Phase.FINAL_JUDGE

    def force_advance(self, pid: str) -> None:
        """Host moves on without waiting for stragglers."""
        self._need_host(pid)
        self._need(Phase.FINAL_WAGER, Phase.FINAL_ANSWER)
        g = self.game
        if g.phase == Phase.FINAL_WAGER:
            for p in self.final_eligible():
                if p.final_wager is None:
                    p.final_wager = 0
            g.phase = Phase.FINAL_ANSWER
        else:
            for p in self.final_eligible():
                if p.final_answer is None:
                    p.final_answer = "(no answer)"
            g.phase = Phase.FINAL_JUDGE

    def judge_final(self, pid: str, target: str, correct: bool) -> None:
        self._need_host(pid)
        self._need(Phase.FINAL_JUDGE)
        p = self._player(target)
        if p not in self.final_eligible() or p.final_correct is not None:
            raise ActionError("cannot judge that player")
        p.score += p.final_wager if correct else -p.final_wager
        p.final_correct = correct
        self._log(f"{p.name} final {'correct' if correct else 'wrong'}")
        if all(q.final_correct is not None for q in self.final_eligible()):
            self.game.phase = Phase.GAME_OVER

    # ---- views ---------------------------------------------------------
    def snapshot(self, viewer: str | None) -> dict:
        """JSON-able state for one viewer; hides unrevealed answers/wagers."""
        d = self.game.model_dump(mode="json")
        self._hide_final_round(d, viewer)
        self._hide_clues(d, is_host=viewer == self.game.host)
        d["you"] = viewer
        return d

    def _hide_final_round(self, d: dict, viewer: str | None) -> None:
        g = self.game
        revealed = g.phase in (Phase.FINAL_JUDGE, Phase.GAME_OVER)
        for pid, p in d["players"].items():
            if not revealed and pid != viewer:
                p["final_answer"] = None
                p["final_wager"] = None if p["final_wager"] is None else -1  # -1: submitted
        if g.final and viewer != g.host and g.phase != Phase.GAME_OVER:
            d["final"]["answer"] = None
        if g.final and g.phase in (Phase.LOBBY, Phase.BOARD, Phase.FINAL_WAGER):
            d["final"]["clue"] = None

    def _hide_clues(self, d: dict, is_host: bool) -> None:
        g = self.game
        showing = g.phase in (Phase.CLUE, Phase.BUZZ_OPEN, Phase.ANSWERING)
        for ci, cat in enumerate(d["categories"]):
            for ii, c in enumerate(cat["clues"]):
                is_current = g.current == (ci, ii)
                active = is_current and showing
                if not (is_host and active):
                    c["answer"] = c["answer"] if c["answered"] else None
                if not (is_host or c["answered"] or is_current):
                    c["daily_double"] = False       # don't leak unplayed Daily Doubles
                if not (active or c["answered"]):
                    c["clue"] = None
