---
title: jeopardy-client
section: 1
date: October 5 2026
header: CIC Commands Manual
footer: jeopardy 0.1.0
---

# NAME

| jeopardy-client -- terminal client for multiplayer Jeopardy

# SYNOPSIS

| jeopardy-client [**--socket** _path_ | **--tcp** _host_:_port_]
|     [**--ascii**] [**--mono**] [**--name** _name_]
|     [**--role** player|host|spectator]

# DESCRIPTION

**jeopardy-client** connects to a **jeopardy-server**(1) and shows the board, the current clue and the scores in the terminal.

Without **--role** it asks whether to join as a player, the host or a spectator, and then for a name. A game has one host. The host picks the question set, opens the buzzers, judges answers and can adjust scores. Players choose clues when they have control and buzz in. Spectators only watch.

If the connection is lost, the client retries every two seconds and rejoins as the same person.

Only plain ASCII and standard box-drawing characters are used. State is shown in words and text styles, not icons.

# OPTIONS

**--socket** _path_
: Connect to a UNIX socket. This is the default. The path is taken from **JEOPARDY_SOCKET**, or is */tmp/jeopardy.sock*.

**--tcp** _host_:_port_
: Connect over TCP. If _host_ is empty, *127.0.0.1* is used.

**--ascii**
: Draw borders with **+**, **-** and **|**.

**--mono**
: Use no colors, only bold, reverse and underline.

**--name** _name_
: Fill in the name prompt in advance. Up to 20 characters. You still press **Enter** to join.

**--role** _role_
: Skip the role menu and join as **player**, **host** or **spectator**.

# KEYS

**q**
: Quit. Works everywhere except while typing in a prompt.

In the lobby (host):

**Up**, **Down**
: Choose a question set.

**Enter**
: Start the game.

On the board:

**Arrows**, **h j k l**
: Move the cursor.

**Enter**
: Pick the highlighted clue. Only the player in control, or the host, may do this.

**f** (host)
: Start Final Jeopardy.

During a clue:

**Space** (player)
: Buzz in.

**o** (host)
: Open the buzzers.

**c**, **w** (host)
: Mark the answer correct or wrong.

**s** (host)
: Skip the clue.

Wagers and Final Jeopardy answers are typed into a prompt that opens by itself. **Esc** closes it, and **Enter** opens it again. In Final Jeopardy, the host presses **n** to move on without waiting for everyone, then **c** or **w** to judge each player in turn. When the game is over, **n** returns to the lobby with scores reset.

**a** (host)
: Adjust a score at any time after the game has started. Type a name and an amount, for example *Ann +200* or *Bob -100*.

# ENVIRONMENT

**JEOPARDY_SOCKET**
: Default for **--socket**.

**JEOPARDY_ASCII**
: Set to **1** to force ASCII borders, or **0** to force box-drawing characters. When unset, ASCII is used if **TERM** is *linux*, *vt100* or *dumb*, or if the locale is not UTF-8.

# EXAMPLES

Join a local game as a player:

    jeopardy-client --name Ann --role player

Host a game on a remote server over a tunnel:

    jeopardy-client --tcp 127.0.0.1:7777 --role host --name Sam

# SEE ALSO

**jeopardy-server**(1), **jeopardy-protocol**(7)
