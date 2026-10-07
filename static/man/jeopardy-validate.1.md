---
title: jeopardy-validate
section: 1
date: October 5 2026
header: CIC Commands Manual
footer: jeopardy 0.1.0
---

# NAME

| jeopardy-validate -- check Jeopardy question sets

# SYNOPSIS

| jeopardy-validate _file_...

# DESCRIPTION

**jeopardy-validate** loads each question set and reports whether the server would accept it. A set must match the format in **jeopardy-questions**(5) and pass these checks:

- there is at least one category;
- every category has the same number of clues, and at least one;
- clue values are positive and ascending within a category;
- no clue is already marked as answered.

A set without a final clue is accepted, with a warning.

For each file, one line is printed: **ok** with the title and counts, or **FAIL** with the reason. Warnings follow an **ok** line.

# EXIT STATUS

**0**
: All files are valid.

**1**
: At least one file failed.

Running it with no arguments prints a usage message and exits with status 1.

# EXAMPLES

    $ jeopardy-validate games/sample.yaml
    ok   games/sample.yaml: 'Sample Game', 6 categories, 30 clues

# SEE ALSO

**jeopardy-questions**(5), **jeopardy-loader**(3), **jeopardy-server**(1)
