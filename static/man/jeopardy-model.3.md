---
title: jeopardy-model
section: 3
date: October 5 2026
header: CIC Library Functions Manual
footer: jeopardy 0.1.0
---

# NAME

| jeopardy.model -- data types for a Jeopardy game

# SYNOPSIS

| from jeopardy.model import Clue, Category, FinalClue, QuestionSet,
|     Player, Game, Phase

# DESCRIPTION

The module defines the data shared by the server, the engine and the loader. All types are **pydantic**(BaseModel) classes, except **Phase**. They hold data only and do no I/O.

**Phase**
: A **str** enumeration of the stages of a game. Values: **lobby**, **board**, **wager**, **clue**, **buzz_open**, **answering**, **final_wager**, **final_answer**, **final_judge**, **game_over**.

**Clue**
: **clue**, **answer**, **value**, **daily_double** (default False), **answered** (default False).

**Category**
: **name** and a list of **clues**.

**FinalClue**
: **category**, **clue**, **answer**.

**QuestionSet**
: What is loaded from a file: **title** (default "Jeopardy"), a list of **categories** and an optional **final**. See **jeopardy-questions**(5).

**Player**
: **id**, **name**, **score** (default 0), **connected** (default True), and the final round fields **final_wager**, **final_answer** and **final_correct**, all None until set.

**Game**
: The complete state of one game: the **phase**, and the **title**, **categories** and **final** clue copied from the question set at the start. **players** holds the players by id, the host included, and **host** and **chooser** are the ids of the host and of the player who picks the next clue. **current** is the open clue as (category, index), or None. **answerer**, **tried** and **wager** are who has the floor, who has already answered the open clue wrongly, and the Daily Double wager. **buzz_opened_at** and **lockouts** time the buzzers, in seconds on the caller's clock. **log** holds recent events.

A **Game** can be saved with **model_dump**(mode="json") and restored with **model_validate**. The server does this for its state file.

# SEE ALSO

**jeopardy-engine**(3), **jeopardy-loader**(3), **jeopardy-protocol**(7)
