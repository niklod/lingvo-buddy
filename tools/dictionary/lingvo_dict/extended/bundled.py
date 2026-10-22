"""What the bundled dictionary already has: the extended dictionary only adds words outside it."""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

from lingvo_dict.extended.clean import russian_key


@dataclass(frozen=True)
class Bundled:
    headwords: frozenset[str]
    # Russian translations in `russian_key` form: the words Russian input already finds.
    russian_keys: frozenset[str]


def load_bundled(batches_dir: Path) -> Bundled:
    headwords: set[str] = set()
    russian_keys: set[str] = set()
    for path in sorted(batches_dir.glob("batch-*.json")):
        for entry in json.loads(path.read_text(encoding="utf-8"))["entries"]:
            headwords.add(entry["headword"].lower())
            russian_keys.update(russian_key(text) for text in entry["translations"])
    return Bundled(frozenset(headwords), frozenset(russian_keys))
