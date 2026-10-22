"""Reads the committed word list (data/wordlist/wordlist.tsv)."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Optional, Tuple


class WordListError(ValueError):
    pass


@dataclass(frozen=True)
class WordList:
    headwords: Tuple[str, ...]  # index 0 is rank 1
    header: Tuple[Tuple[str, str], ...] = ()

    @property
    def size(self) -> int:
        return len(self.headwords)

    def headword_at(self, rank: int) -> Optional[str]:
        if 1 <= rank <= self.size:
            return self.headwords[rank - 1]
        return None

    def ranks(self) -> Dict[str, int]:
        return {word: index + 1 for index, word in enumerate(self.headwords)}

    def header_value(self, key: str) -> Optional[str]:
        return dict(self.header).get(key)


def parse_word_list(text: str) -> WordList:
    header = []
    headwords = []
    for number, line in enumerate(text.splitlines(), start=1):
        if line.startswith("#"):
            key, _, value = line[1:].strip().partition(":")
            header.append((key.strip(), value.strip()))
            continue
        if not line.strip():
            continue
        parts = line.split("\t")
        # isdigit() alone accepts "²", which int() then rejects.
        if len(parts) != 2 or not (parts[0].isascii() and parts[0].isdigit()):
            raise WordListError(f"line {number}: expected 'rank<TAB>headword', got {line!r}")
        rank = int(parts[0])
        if rank != len(headwords) + 1:
            raise WordListError(f"line {number}: rank {rank} out of order, expected {len(headwords) + 1}")
        headwords.append(parts[1])
    return WordList(headwords=tuple(headwords), header=tuple(header))


def read_word_list(path: Path) -> WordList:
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as error:
        raise WordListError(f"cannot read word list {path}: {error}") from error
    try:
        return parse_word_list(text)
    except WordListError as error:
        raise WordListError(f"{path}: {error}") from error
