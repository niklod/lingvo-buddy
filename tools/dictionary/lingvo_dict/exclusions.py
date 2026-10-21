"""Reads the quiz-exclusion list: lookup-tier headwords that never become quiz cards.

Format (data/quiz-exclusions.txt): one headword per line; '#' starts a comment,
also after a headword ("dude  # slang"); blank lines are ignored.
"""

from __future__ import annotations

from pathlib import Path
from typing import List, Tuple

from lingvo_dict.contract import QUIZ_MAX_RANK
from lingvo_dict.wordlist_file import WordList


def parse_exclusions(text: str, word_list: WordList, name: str) -> Tuple[Tuple[str, ...], List[str]]:
    """Returns (headwords in file order, errors)."""
    ranks = word_list.ranks()
    headwords: List[str] = []
    errors: List[str] = []
    for number, line in enumerate(text.splitlines(), start=1):
        headword = line.split("#", 1)[0].strip()
        if not headword:
            continue
        label = f"{name}:{number} '{headword}'"
        rank = ranks.get(headword)
        if rank is None:
            errors.append(f"{label}: not a headword of the word list")
        elif rank <= QUIZ_MAX_RANK:
            # Quiz-tier words were reviewed with examples; drop them from the word list instead.
            errors.append(f"{label}: rank {rank} is quiz tier; only lookup-tier words (rank > {QUIZ_MAX_RANK}) can be excluded")
        elif headword in headwords:
            errors.append(f"{label}: listed twice")
        else:
            headwords.append(headword)
    return tuple(headwords), errors


def read_exclusions(path: Path, word_list: WordList) -> Tuple[Tuple[str, ...], List[str]]:
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as error:
        return (), [f"cannot read quiz exclusions {path}: {error}"]
    return parse_exclusions(text, word_list, path.name)
