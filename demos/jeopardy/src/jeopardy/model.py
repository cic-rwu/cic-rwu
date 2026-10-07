"""Data models. Plain pydantic; no I/O."""
from __future__ import annotations

from enum import Enum

from pydantic import BaseModel, Field


class Phase(str, Enum):
    LOBBY = "lobby"
    BOARD = "board"              # chooser picks a clue
    WAGER = "wager"              # Daily Double wager
    CLUE = "clue"                # clue shown, buzzers not yet open
    BUZZ_OPEN = "buzz_open"
    ANSWERING = "answering"      # someone has the floor; host judges
    FINAL_WAGER = "final_wager"
    FINAL_ANSWER = "final_answer"
    FINAL_JUDGE = "final_judge"
    GAME_OVER = "game_over"


class Clue(BaseModel):
    clue: str
    answer: str
    value: int
    daily_double: bool = False
    answered: bool = False


class Category(BaseModel):
    name: str
    clues: list[Clue]


class FinalClue(BaseModel):
    category: str
    clue: str
    answer: str


class QuestionSet(BaseModel):
    title: str = "Jeopardy"
    categories: list[Category]
    final: FinalClue | None = None


class Player(BaseModel):
    id: str
    name: str
    score: int = 0
    connected: bool = True
    final_wager: int | None = None
    final_answer: str | None = None
    final_correct: bool | None = None


class Game(BaseModel):
    phase: Phase = Phase.LOBBY
    title: str = "Jeopardy"
    categories: list[Category] = Field(default_factory=list)
    final: FinalClue | None = None
    players: dict[str, Player] = Field(default_factory=dict)
    host: str | None = None
    chooser: str | None = None
    current: tuple[int, int] | None = None   # (category, clue index)
    answerer: str | None = None
    tried: list[str] = Field(default_factory=list)
    wager: int | None = None
    buzz_opened_at: float | None = None
    lockouts: dict[str, float] = Field(default_factory=dict)  # pid -> locked until
    log: list[str] = Field(default_factory=list)
