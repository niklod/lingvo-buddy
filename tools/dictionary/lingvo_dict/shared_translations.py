"""Report-only view of synonym groups against first translations, for a human review.

The quiz shows the first translation, so two cards in different groups with the same first
translation look like two right answers; one group with different first translations may be a
wrong merge. Both can also be fine, so this never fails validation.
"""

from __future__ import annotations

from collections import defaultdict
from collections.abc import Iterable, Sequence
from typing import Callable

from lingvo_dict.loaded_entry import LoadedEntry

SPLIT_TITLE = "same first translation, different groups"
MERGED_TITLE = "one group, different first translations"


def shared_translation_report(entries: Sequence[LoadedEntry], quiz_exclusions: Iterable[str]) -> list[str]:
    excluded = set(quiz_exclusions)
    cards = [item for item in entries if item.synonym_group is not None and item.headword not in excluded]
    firsts = {item.headword: first for item in cards if (first := _first_translation(item)) is not None}
    cards = [item for item in cards if item.headword in firsts]

    split = _sections(cards, lambda item: firsts[item.headword], lambda item: item.synonym_group)
    merged = _sections(cards, lambda item: item.synonym_group, lambda item: firsts[item.headword])
    return _format(SPLIT_TITLE, split, lambda m: f"-> {m.synonym_group}") + _format(
        MERGED_TITLE, merged, lambda m: firsts[m.headword]
    )


def _format(
    title: str, sections: list[tuple[str, list[LoadedEntry]]], detail: Callable[[LoadedEntry], str]
) -> list[str]:
    lines = [f"{title}: {len(sections)}"]
    for name, members in sections:
        lines.append(f"  {name}: " + "; ".join(f"{m.headword}({m.rank}) {detail(m)}" for m in members))
    return lines


def _sections(
    cards: Sequence[LoadedEntry],
    bucket_of: Callable[[LoadedEntry], str | None],
    differs_by: Callable[[LoadedEntry], str | None],
) -> list[tuple[str, list[LoadedEntry]]]:
    """Buckets whose members disagree on differs_by, ordered by their lowest rank."""
    buckets: dict[str, list[LoadedEntry]] = defaultdict(list)
    for item in sorted(cards, key=lambda item: item.rank):
        buckets[str(bucket_of(item))].append(item)
    return [(name, members) for name, members in buckets.items() if len({differs_by(m) for m in members}) > 1]


def _first_translation(item: LoadedEntry) -> str | None:
    translations = item.data.get("translations")
    if isinstance(translations, list) and translations and isinstance(translations[0], str):
        return translations[0]
    return None
