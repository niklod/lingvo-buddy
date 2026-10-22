"""Merges the Wiktionary extracts into sorted extended entries."""

from __future__ import annotations

from collections import defaultdict
from collections.abc import Collection, Iterable
from dataclasses import dataclass
from itertools import chain

from lingvo_dict.extended.clean import MAX_TRANSLATIONS, distinct
from lingvo_dict.extended.records import EnglishRecord, RussianRecord


@dataclass(frozen=True)
class EnglishEntry:
    headword: str
    pos: str
    ipa: str | None
    translations: tuple[str, ...]
    example: str | None
    example_ru: str | None


@dataclass(frozen=True)
class RussianEntry:
    word: str
    translations: tuple[str, ...]


def merge_english(english: Iterable[EnglishRecord], russian: Iterable[EnglishRecord]) -> list[EnglishEntry]:
    """English Wiktionary first: its translations are curated, the Russian glosses only add to them."""
    groups: dict[str, list[EnglishRecord]] = defaultdict(list)
    for record in chain(english, russian):
        groups[record.word].append(record)
    entries = (_merge_word(word, records) for word, records in sorted(groups.items()))
    return [entry for entry in entries if entry is not None]


def _merge_word(word: str, records: list[EnglishRecord]) -> EnglishEntry | None:
    main = next((record for record in records if record.translations), None)
    if main is None:
        return None
    # Translations of another part of speech would sit under the wrong label.
    same_pos = [record for record in records if record.pos == main.pos]
    translations = distinct(item for record in same_pos for item in record.translations)[:MAX_TRANSLATIONS]
    example = next((r.example for r in same_pos if r.example and r.example[1]), None) or next(
        (r.example for r in same_pos if r.example), None
    )
    return EnglishEntry(
        headword=word,
        pos=main.pos,
        ipa=next((record.ipa for record in records if record.ipa), None),
        translations=tuple(translations),
        example=example[0] if example else None,
        example_ru=(example[1] or None) if example else None,
    )


def merge_russian(records: Iterable[RussianRecord], bundled_keys: Collection[str]) -> list[RussianEntry]:
    groups: dict[str, list[str]] = defaultdict(list)
    for record in records:
        if record.key not in bundled_keys:
            groups[record.key].extend(record.translations)
    entries = (
        RussianEntry(word=word, translations=tuple(distinct(items)[:MAX_TRANSLATIONS]))
        for word, items in sorted(groups.items())
    )
    return [entry for entry in entries if entry.translations]
