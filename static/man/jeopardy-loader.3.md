---
title: jeopardy-loader
section: 3
date: October 5 2026
header: CIC Library Functions Manual
footer: jeopardy 0.1.0
---

# NAME

| jeopardy.loader -- load and validate Jeopardy question sets

# SYNOPSIS

| from jeopardy.loader import load_set, check, validate_main, LoadError
|
| **load_set**(_path_) -> QuestionSet
| **check**(_qs_) -> errors
| **validate_main**(_argv_=None)

# DESCRIPTION

**load_set**(_path_)
: Read a question set from a file and return a **QuestionSet** (see **jeopardy-model**(3)). A file ending in *.json* is parsed as JSON, any other as YAML. Raises **LoadError** if the file cannot be read or parsed, does not match the format, or fails **check**. The message starts with the path.

**check**(_qs_)
: Run the semantic checks that the format alone cannot express and return a list of error messages, empty if the set is fine. The errors are: no categories, categories of different sizes, a category without clues, values that are not ascending or not positive, or a clue already marked answered.

**validate_main**(_argv_=None)
: Entry point of **jeopardy-validate**(1). Prints one result per file, with a warning if the set has no final clue, and exits the process with status 0 or 1. Uses **sys.argv**[1:] when _argv_ is None.

**LoadError**
: Exception raised by **load_set**.

# EXAMPLES

    from jeopardy.loader import load_set, LoadError

    try:
        qs = load_set("games/sample.yaml")
    except LoadError as err:
        print(err)

# SEE ALSO

**jeopardy-validate**(1), **jeopardy-questions**(5), **jeopardy-model**(3)
