"""Load and validate question sets from YAML or JSON files."""
from __future__ import annotations

import json
import sys
from pathlib import Path

import yaml
from pydantic import ValidationError

from .model import QuestionSet


class LoadError(Exception):
    pass


def load_set(path: str | Path) -> QuestionSet:
    p = Path(path)
    try:
        text = p.read_text(encoding="utf-8")
        data = json.loads(text) if p.suffix == ".json" else yaml.safe_load(text)
    except (OSError, ValueError, yaml.YAMLError) as e:
        raise LoadError(f"{p}: {e}") from e
    try:
        qs = QuestionSet.model_validate(data)
    except ValidationError as e:
        raise LoadError(f"{p}: {e}") from e
    errors = check(qs)
    if errors:
        raise LoadError(f"{p}:\n  " + "\n  ".join(errors))
    return qs


def check(qs: QuestionSet) -> list[str]:
    """Semantic checks beyond the schema. Returns a list of error messages."""
    errors: list[str] = []
    if not qs.categories:
        errors.append("no categories")
    sizes = {len(c.clues) for c in qs.categories if c.clues}
    if len(sizes) > 1:
        errors.append(f"categories have different clue counts: {sorted(sizes)}")
    for c in qs.categories:
        if not c.clues:
            errors.append(f"category {c.name!r} has no clues")
        if [x.value for x in c.clues] != sorted(x.value for x in c.clues):
            errors.append(f"category {c.name!r}: values not ascending")
        for x in c.clues:
            if x.value <= 0:
                errors.append(f"category {c.name!r}: non-positive value {x.value}")
            if x.answered:
                errors.append(f"category {c.name!r}: clue {x.value} pre-marked answered")
    return errors


def validate_main(argv: list[str] | None = None) -> None:
    files = argv if argv is not None else sys.argv[1:]
    if not files:
        sys.exit("usage: jeopardy-validate FILE...")
    bad = 0
    for f in files:
        try:
            qs = load_set(f)
        except LoadError as e:
            print(f"FAIL {e}")
            bad += 1
            continue
        n = sum(len(c.clues) for c in qs.categories)
        print(f"ok   {f}: {qs.title!r}, {len(qs.categories)} categories, {n} clues")
        if qs.final is None:
            print("     warning: no final clue (Final Jeopardy will be unavailable)")
    sys.exit(1 if bad else 0)
