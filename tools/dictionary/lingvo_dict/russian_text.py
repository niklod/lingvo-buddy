"""The form in which Russian input meets the bundled translations."""

from __future__ import annotations


def normalized(text: str) -> str:
    """Mirrors `RussianText.normalized` in LingvoCore; `lingvo-dict check` fails when the two differ.

    Learners often type «е» for «ё», and the dictionary spells some words either way.
    """
    return text.strip().lower().replace("ё", "е")
