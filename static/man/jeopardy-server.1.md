---
title: jeopardy-server
section: 1
date: October 5 2026
header: CIC Commands Manual
footer: jeopardy 0.1.0
---

# NAME

| jeopardy-server -- host a multiplayer Jeopardy game

# SYNOPSIS

| jeopardy-server [**--socket** _path_ | **--tcp** _host_:_port_]
|     [**--games-dir** _dir_] [**--state** _file_]
|     [**--allow-name-reclaim**] [**-v**]

# DESCRIPTION

**jeopardy-server** runs one shared game. Players, the host and spectators connect to it with **jeopardy-client**(1).

The server owns all game state and decides what each client may see. Clients only send requests (see **jeopardy-protocol**(7)), so a modified client cannot read hidden answers or other players' final wagers.

After every change the server writes the game to the state file. On start it loads that file if it exists. Everyone starts out disconnected and is reconnected when their client rejoins with its saved token.

# OPTIONS

**--socket** _path_
: Listen on a UNIX socket. This is the default. The path is taken from **JEOPARDY_SOCKET**, or is */tmp/jeopardy.sock*. An existing file at the path is removed first. The socket is made readable and writable by owner and group (mode 0660).

**--tcp** _host_:_port_
: Listen on a TCP port instead. If _host_ is empty, *127.0.0.1* is used. Cannot be combined with **--socket**.

**--games-dir** _dir_
: Directory searched for question sets. Default: *games*. See **jeopardy-questions**(5).

**--state** _file_
: Where to save and restore the game. Default: *state.json*.

**--allow-name-reclaim**
: Let a new connection take over a disconnected seat by giving the same name and role. Meant for a trusted group that shares one account: anyone can impersonate an absent player. Without this option a seat can only be recovered with its token.

**-v**, **--verbose**
: Also log connections and every request received. Request arguments are never logged.

# ENVIRONMENT

**JEOPARDY_SOCKET**
: Default for **--socket**.

# FILES

*state.json*
: Saved game. It also holds the secret tokens that identify players, so keep it readable only by the account running the server.

*games/*
: Question sets (*.yaml*, *.yml* or *.json*).

# NOTES

**--tcp** offers no authentication or encryption. Listen on the loopback address and reach it through an SSH tunnel, or use a UNIX socket.

Log lines go to standard error, one per game event such as a join, a chosen clue, a buzz, a judged answer or a score adjustment. Press **Ctrl-C** to stop the server.

# EXAMPLES

Serve on a local socket:

    jeopardy-server

Serve on port 7777 with verbose logging:

    jeopardy-server --tcp 127.0.0.1:7777 -v

# SEE ALSO

**jeopardy-client**(1), **jeopardy-validate**(1), **jeopardy-questions**(5), **jeopardy-protocol**(7)
