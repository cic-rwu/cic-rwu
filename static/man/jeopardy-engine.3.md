---
title: jeopardy-engine
section: 3
date: October 5 2026
header: CIC Library Functions Manual
footer: jeopardy 0.1.0
---

# NAME

| jeopardy.engine -- Jeopardy game rules as a state machine

# SYNOPSIS

| from jeopardy.engine import Engine, ActionError
|
| **Engine**(_game_=None, _on_log_=None)

# DESCRIPTION

**Engine** applies player actions to a **Game** (see **jeopardy-model**(3)) and enforces the rules. It does no I/O and never reads a clock: methods that depend on time take _now_ in seconds from the caller. This keeps it easy to test, and lets **jeopardy-server**(1) be the only place that talks to the network.

Every action takes the id of the player making it, _pid_, as its first argument. An action that is not allowed in the current phase, or not by that player, raises **ActionError** with a short message and changes nothing.

_game_ is an existing **Game** to resume, or None for a new one. _on_log_ is called with each game event as it is logged. The last 50 events are also kept in **game.log**.

# METHODS

Lobby

**join**(_pid_, _name_, _host_=False)
: Add a player, or mark a known one as connected again. Fails if the name is taken, ignoring case, or if _host_ is true and there is already a host.

**disconnect**(_pid_)
: Mark a player as not connected. Their seat and score are kept.

**start**(_pid_, _qs_)
: Host only. Load a **QuestionSet** and start the game. Needs at least one player besides the host. The first player to have joined gets control.

**reset**(_pid_)
: Host only. Return to the lobby with the same people and scores set to zero.

Board

**select_clue**(_pid_, _cat_, _idx_)
: The player in control, or the host, picks a clue. A Daily Double goes to the wager phase and any other clue is shown.

**skip_clue**(_pid_)
: Host only. Drop the open clue and reveal its answer.

**adjust_score**(_pid_, _target_, _delta_)
: Host only. Add _delta_ to a player's score.

Daily Double

**set_wager**(_pid_, _amount_)
: The player in control wagers from 5 up to **max_wager**(_pid_), which is their score or the highest value on the board, whichever is larger.

Buzzing

**open_buzzers**(_pid_, _now_)
: Host only. Let players buzz in.

**buzz**(_pid_, _now_)
: A player tries to take the floor. Returns True if they got it. Buzzing before the buzzers open locks the player out for a quarter of a second. A player who has already answered the clue wrongly cannot buzz again.

**judge**(_pid_, _correct_)
: Host only. A correct answer adds the clue's value, or the wager, to the score and gives the player control. A wrong one subtracts it and lets the others buzz. The clue ends when someone is correct, when every player has tried, or at once after a wrong Daily Double.

Final Jeopardy

**start_final**(_pid_)
: Host only, from the board. Only players with a positive score take part. If there are none, the game is over.

**final_wager**(_pid_, _amount_), **final_answer**(_pid_, _text_)
: An eligible player wagers from 0 up to their score, then answers. The phase moves on once everyone eligible has done so.

**force_advance**(_pid_)
: Host only. Move on without waiting. Missing wagers become 0 and missing answers become "(no answer)".

**judge_final**(_pid_, _target_, _correct_)
: Host only. Add or subtract the player's wager. The game ends after the last player is judged.

Queries

**snapshot**(_viewer_)
: The game as a JSON-ready dictionary for one viewer, with hidden information removed. See **jeopardy-protocol**(7).

**current_clue**(), **contestants**(), **final_eligible**(), **max_wager**(_pid_), **max_board_value**()
: Helpers that read the state.

# SEE ALSO

**jeopardy-model**(3), **jeopardy-protocol**(7), **jeopardy-server**(1)
