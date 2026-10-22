"""The data gate of the extended dictionary: the rules the cleaning promises, checked on the committed source."""

from __future__ import annotations

from collections.abc import Sequence

from lingvo_dict.contract import IPA_PATTERN, POS_VALUES
from lingvo_dict.extended.bundled import Bundled
from lingvo_dict.extended.clean import (
    ENGLISH_ITEM,
    MAX_EXAMPLE_LENGTH,
    MAX_EXAMPLE_RU_LENGTH,
    MAX_ITEM_WORDS,
    MAX_TRANSLATIONS,
    RUSSIAN_ITEM,
    russian_key,
)
from lingvo_dict.extended.merge import EnglishEntry, RussianEntry
from lingvo_dict.extended.records import ENGLISH_WORD, RUSSIAN_WORD
from lingvo_dict.extended.source import ExtendedData


def validate_extended(data: ExtendedData, bundled: Bundled) -> list[str]:
    errors: list[str] = []
    if not data.meta.get("license"):
        errors.append("header has no license note")
    _check_order([entry.headword for entry in data.english], "English", errors)
    _check_order([entry.word for entry in data.russian], "Russian", errors)
    for entry in data.english:
        errors += [f"{entry.headword}: {problem}" for problem in _english_problems(entry, bundled)]
    for russian in data.russian:
        errors += [f"{russian.word}: {problem}" for problem in _russian_problems(russian, bundled)]
    return errors


def _check_order(keys: Sequence[str], kind: str, errors: list[str]) -> None:
    for previous, key in zip(keys, keys[1:]):
        if key <= previous:
            errors.append(f"{kind} entry {key!r} is a duplicate or comes after {previous!r}: the source must be sorted")


def _english_problems(entry: EnglishEntry, bundled: Bundled) -> list[str]:
    problems = _translation_problems(entry.translations, RUSSIAN_ITEM, "Russian letters")
    if not ENGLISH_WORD.fullmatch(entry.headword):
        problems.append("headword is not a lower case English word")
    if entry.headword in bundled.headwords:
        problems.append("headword is in the bundled dictionary")
    if entry.pos not in POS_VALUES:
        problems.append(f"unknown pos {entry.pos!r}")
    if entry.ipa is not None and not IPA_PATTERN.fullmatch(entry.ipa):
        problems.append(f"ipa {entry.ipa!r} is not in the bundled style")
    problems += _text_problems("example", entry.example, MAX_EXAMPLE_LENGTH)
    problems += _text_problems("example_ru", entry.example_ru, MAX_EXAMPLE_RU_LENGTH)
    if entry.example_ru and not entry.example:
        problems.append("Russian example without an example")
    return problems


def _russian_problems(entry: RussianEntry, bundled: Bundled) -> list[str]:
    problems = _translation_problems(entry.translations, ENGLISH_ITEM, "English letters")
    if not RUSSIAN_WORD.fullmatch(entry.word) or entry.word != russian_key(entry.word):
        problems.append("word is not a lower case Russian word without stress and ё")
    if entry.word in bundled.russian_keys:
        problems.append("word is a bundled translation already")
    return problems


def _translation_problems(items: Sequence[str], pattern, letters: str) -> list[str]:
    if not items:
        return ["no translations"]
    problems = []
    if len(items) > MAX_TRANSLATIONS:
        problems.append(f"more than {MAX_TRANSLATIONS} translations")
    for item in items:
        if not pattern.fullmatch(item):
            problems.append(f"translation {item!r} is not made of {letters}")
        elif len(item.split()) > MAX_ITEM_WORDS:
            problems.append(f"translation {item!r} has more than {MAX_ITEM_WORDS} words; bubbles hold at most 3 words")
    return problems


def _text_problems(name: str, text: str | None, limit: int) -> list[str]:
    if text is None:
        return []
    if len(text) > limit:
        return [f"{name} is longer than {limit} characters"]
    return [] if text == " ".join(text.split()) else [f"{name} has stray whitespace"]
