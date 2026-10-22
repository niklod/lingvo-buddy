"""Reads the quiz-exclusion list: Top-2000 headwords (ranks 1001-2000) that never become quiz cards.

Format (data/quiz-exclusions.txt): one headword per line; '#' starts a comment,
also after a headword ("dude  # slang"); blank lines are ignored.
"""

from __future__ import annotations

from pathlib import Path
from typing import List, Set, Tuple

from lingvo_dict.contract import QUIZ_MAX_RANK, TOP_1000_MAX_RANK
from lingvo_dict.text_lines import content_lines
from lingvo_dict.wordlist_file import WordList

_EXCLUDABLE = f"only words of ranks {TOP_1000_MAX_RANK + 1}-{QUIZ_MAX_RANK} can be excluded"


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
        elif rank <= TOP_1000_MAX_RANK:
            # Top-1000 words were reviewed as cards; drop them from the word list instead.
            errors.append(f"{label}: rank {rank} is in the Top-1000; {_EXCLUDABLE}")
        elif rank > QUIZ_MAX_RANK:
            errors.append(f"{label}: rank {rank} is past the Top-2000 and never becomes a card; {_EXCLUDABLE}")
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
