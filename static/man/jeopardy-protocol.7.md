---
title: jeopardy-protocol
section: 7
date: October 5 2026
header: CIC Miscellaneous Manual
footer: jeopardy 0.1.0
---

# NAME

| jeopardy-protocol -- wire protocol between Jeopardy clients and server

# DESCRIPTION

Clients and **jeopardy-server**(1) exchange newline-delimited JSON over a UNIX or TCP stream socket. Each line is one JSON object. A line longer than 16 KiB closes the connection.

The client sends requests. The server answers with a reply to the sender only when the request fails or is a **join**, and then sends the new game state to every connected client. Requests that change nothing, such as an early buzz, still produce a new state.

# REQUESTS

Every request is an object with an **op** field and the arguments listed below. A message with an unknown **op**, a missing argument or an argument of the wrong type gets an **error** reply.

Apart from **join**, requests are accepted only after a successful join. The server enforces who may send each one, and when. The _chooser_ is the player who has control of the board:

| **op** | arguments | sent by, when |
|:-------|:----------|:----------------|
| **join** | **name**, **role**, [**token**] | anyone, once |
| **start** | **set** | host, lobby |
| **select** | **cat**, **idx** | chooser or host, board |
| **open** | | host, clue shown |
| **buzz** | | player, buzzers open |
| **judge** | **correct** | host, someone answering |
| **skip** | | host, any clue |
| **wager** | **amount** | chooser, Daily Double |
| **adjust** | **target**, **delta** | host, any time |
| **start_final** | | host, board |
| **final_wager** | **amount** | eligible player, final wager |
| **final_answer** | **text** | eligible player, final answer |
| **advance** | | host, final wager or answer |
| **judge_final** | **target**, **correct** | host, final judging |
| **reset** | | host, any time |

**cat**, **idx**, **amount** and **delta** are integers. **correct** is a boolean. The other arguments are strings. **target** is a player id. Names are 1 to 20 printable characters, and answers longer than 200 characters are cut.

**role** is **host**, **player** or **spectator**. There is one host per game, and names are unique, ignoring case. A valid **token** from an earlier join takes the old seat back and overrides **name** and **role**.

# REPLIES

**welcome**
: Reply to a successful join: `{"type":"welcome","token":T,"id":P}`. **token** is secret and proves identity on reconnect. **id** is the public player id used as **target**. Spectators get null for both.

**error**
: `{"type":"error","message":M}`. The request had no effect.

**state**
: `{"type":"state","state":S,"sets":[...]}`, sent after every change and after joining. **sets** lists the question sets the host can start.

# STATE

**state** holds the whole game, as seen by one viewer: the phase, title, board, players and scores, who is in control, who has the floor, the last 50 log lines, and **you**, the viewer's own id (null for spectators).

The server removes what a viewer may not know yet:

- a clue's text until it is shown (for a Daily Double, until the wager is made), and its answer until it has been played, except to the host while the clue is open;
- which unplayed clues are Daily Doubles, except for the host;
- other players' final wagers (shown as -1 once submitted) and final answers, until judging begins;
- the final clue until the final answers are due, and its answer, except to the host, until the game is over.

# PHASES

**lobby**, **board**, **wager**, **clue**, **buzz_open**, **answering**, **final_wager**, **final_answer**, **final_judge**, **game_over**.

# EXAMPLES

A player joins and buzzes:

    {"op":"join","name":"Ann","role":"player"}
    {"type":"welcome","token":"...","id":"1f3a9c02"}
    {"op":"buzz"}

# SEE ALSO

**jeopardy-server**(1), **jeopardy-client**(1), **jeopardy-engine**(3), **jeopardy-model**(3)
