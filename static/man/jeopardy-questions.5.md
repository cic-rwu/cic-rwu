---
title: jeopardy-questions
section: 5
date: October 5 2026
header: CIC File Formats Manual
footer: jeopardy 0.1.0
---

# NAME

| jeopardy-questions -- question set file format for Jeopardy

# DESCRIPTION

A question set describes one game: its categories, their clues, and an optional Final Jeopardy clue. **jeopardy-server**(1) lists the sets found in its games directory and the host picks one in the lobby.

A set is a YAML file (*.yaml* or *.yml*) or a JSON file (*.json*). The file name without its extension is the name shown to the host, so it should contain only letters, digits, **_** and **-**. Other names are listed but cannot be started.

Check a set with **jeopardy-validate**(1).

# FORMAT

The top level has these keys:

**title**
: Name of the game. Optional. Default: *Jeopardy*.

**categories**
: List of categories. Required, and not empty.

**final**
: The Final Jeopardy clue. Optional. Without it the host cannot start the final round.

Each category has:

**name**
: Column heading.

**clues**
: List of clues, lowest value first. Every category must have the same number of clues.

Each clue has:

**value**
: Dollar value, a positive integer. Must not decrease down a category.

**clue**
: Text shown to everyone.

**answer**
: Text shown to the host while the clue is open, and to everyone afterwards. Jeopardy style puts it as a question, as in *What is Mars?*.

**daily_double**
: Set to **true** to make this a Daily Double. Optional. The player who picks it wagers between 5 and their score, or the highest value on the board if that is larger, and has one chance to answer.

**answered**
: Set by the server while a game is played. Leave it out; a set that has it set is rejected.

The **final** clue has **category**, **clue** and **answer**, all text.

# EXAMPLES

    title: Sample Game
    categories:
    - name: Science
      clues:
      - value: 200
        clue: This planet is known as the Red Planet
        answer: What is Mars?
      - value: 400
        clue: H2O is the chemical formula for this
        answer: What is water?
        daily_double: true
    final:
      category: Space
      clue: The first human in space
      answer: Who is Yuri Gagarin?

# SEE ALSO

**jeopardy-validate**(1), **jeopardy-server**(1), **jeopardy-loader**(3)
