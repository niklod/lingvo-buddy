"""Reads the quiz-exclusion list: lookup-tier headwords that never become quiz cards.

Format (data/quiz-exclusions.txt): one headword per line; '#' starts a comment,
also after a headword ("dude  # slang"); blank lines are ignored.
"""

from __future__ import annotations

from pathlib import Path
from typing import List, Set, Tuple

from lingvo_dict.contract import QUIZ_MAX_RANK, is_quiz_rank
from lingvo_dict.text_lines import content_lines
from lingvo_dict.wordlist_file import WordList


def parse_exclusions(text: str, word_list: WordList, name: str) -> Tuple[Tuple[str, ...], List[str]]:
    """Returns (headwords in file order, errors)."""
    ranks = word_list.ranks()
    headwords: List[str] = []
    seen: Set[str] = set()
    errors: List[str] = []
    for number, headword in content_lines(text):
        label = f"{name}:{number} '{headword}'"
        rank = ranks.get(headword)
        if rank is None:
            errors.append(f"{label}: not a headword of the word list")
        elif is_quiz_rank(rank):
            # Quiz-tier words were reviewed with examples; drop them from the word list instead.
            errors.append(f"{label}: rank {rank} is quiz tier; only lookup-tier words (rank > {QUIZ_MAX_RANK}) can be excluded")
        elif headword in seen:
            errors.append(f"{label}: listed twice")
        else:
            seen.add(headword)
            headwords.append(headword)
    return tuple(headwords), errors


def read_exclusions(path: Path, word_list: WordList) -> Tuple[Tuple[str, ...], List[str]]:
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as error:
        return (), [f"cannot read quiz exclusions {path}: {error}"]
    return parse_exclusions(text, word_list, path.name)
