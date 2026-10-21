"""Builders for test word lists and batch files."""

import itertools
import json
import string
import tempfile
from pathlib import Path

from lingvo_dict.contract import batch_ranks, tier_for_rank
from lingvo_dict.wordlist_file import WordList

NAMED = ("be", "big", "large", "house", "Monday")


def generated_headwords(count):
    letters = itertools.product(string.ascii_lowercase, repeat=3)
    return ["w" + "".join(next(letters)) for _ in range(count)]


def make_word_list(size=1600):
    headwords = list(NAMED) + generated_headwords(size - len(NAMED))
    return WordList(
        headwords=tuple(headwords),
        header=(
            ("source", "wordfreq 3.1.1 (en)"),
            ("license", "wordfreq data by Robyn Speer, CC BY-SA 4.0"),
        ),
    )


def quiz_entry(word_list, rank, **changes):
    headword = word_list.headword_at(rank)
    entry = {
        "rank": rank,
        "headword": headword,
        "tier": "quiz",
        "pos": "noun",
        "translations": ["дом"],
        "ipa": "/haʊs/",
        "example": f"This {headword} is very old.",
        "synonym_group": headword,
    }
    entry.update(changes)
    return entry


def lookup_entry(word_list, rank, **changes):
    entry = {
        "rank": rank,
        "headword": word_list.headword_at(rank),
        "tier": "lookup",
        "pos": "noun",
        "translations": ["дом", "здание"],
        "ipa": "/haʊs/",
    }
    entry.update(changes)
    return entry


def entry_for(word_list, rank):
    if tier_for_rank(rank) == "quiz":
        return quiz_entry(word_list, rank)
    return lookup_entry(word_list, rank)


def full_batch(word_list, number):
    first, last = batch_ranks(number)
    return [entry_for(word_list, rank) for rank in range(first, last + 1)]


class BatchFolder:
    """A temporary folder of batch files; use as a context manager."""

    def __enter__(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.path = Path(self._tmp.name)
        return self

    def __exit__(self, *exc):
        self._tmp.cleanup()

    def write(self, number, entries, batch=None, name=None):
        batch_name = batch or f"batch-{number:02d}"
        file = self.path / (name or f"{batch_name}.json")
        file.write_text(
            json.dumps({"batch": batch_name, "entries": entries}, ensure_ascii=False),
            encoding="utf-8",
        )
        return file

    def write_exclusions(self, *lines):
        """Writes a quiz-exclusion list (empty by default) and returns its path."""
        return self.write_raw("quiz-exclusions.txt", "".join(line + "\n" for line in lines))

    def write_raw(self, name, text):
        file = self.path / name
        file.write_text(text, encoding="utf-8")
        return file
