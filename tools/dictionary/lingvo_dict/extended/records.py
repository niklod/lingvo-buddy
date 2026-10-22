"""Reads kaikki.org JSON lines into small records. Only the three extracts' lemmas outside the bundled data survive."""

from __future__ import annotations

import json
import re
from collections.abc import Collection, Iterable, Iterator, Mapping
from dataclasses import dataclass
from typing import Any, Callable, TypeVar

from lingvo_dict.extended.clean import (
    PARTS_OF_SPEECH,
    english_items,
    pick_example,
    pick_ipa,
    russian_items,
    russian_key,
    russian_translation_items,
)

ENGLISH_WORD = re.compile(r"[a-z]+(?:['-][a-z]+)*")
RUSSIAN_WORD = re.compile(r"[а-яё]+(?:-[а-яё]+)*")
# A single letter is a letter of the alphabet in Wiktionary, not a word a learner adds.
MIN_WORD_LENGTH = 2
# Parts of speech that are no word a learner adds: names, affixes, symbols, phrases, abbreviations.
NOT_A_WORD = frozenset(
    {
        "name", "character", "symbol", "prefix", "suffix", "infix", "interfix", "circumfix", "affix",
        "proverb", "contraction", "punct", "abbrev", "phrase", "prep_phrase", "postp",
    }
)  # fmt: skip
OLD_TRANSLATION_TAGS = frozenset({"obsolete", "archaic", "dated", "dialectal", "historical", "nonstandard"})
FORM_TAGS = frozenset({"form-of", "alt-of"})

T = TypeVar("T")


@dataclass(frozen=True)
class EnglishRecord:
    """What one Wiktionary entry says about an English word."""

    word: str
    pos: str
    translations: tuple[str, ...]
    ipa: str | None
    # (English sentence, Russian translation or an empty string)
    example: tuple[str, str] | None


@dataclass(frozen=True)
class RussianRecord:
    key: str
    translations: tuple[str, ...]


def english_records(lines: Iterable[str], skip: Collection[str]) -> Iterator[EnglishRecord]:
    """English Wiktionary: English words with their Russian translations, IPA and usage examples."""
    return _records(lines, lambda entry: _english_record(entry, skip, _english_wiktionary_translations, False))


def russian_wiktionary_records(lines: Iterable[str], skip: Collection[str]) -> Iterator[EnglishRecord]:
    """Russian Wiktionary: English words with Russian glosses and examples that have a Russian translation."""
    return _records(lines, lambda entry: _english_record(entry, skip, _russian_gloss_translations, True))


def russian_word_records(lines: Iterable[str]) -> Iterator[RussianRecord]:
    """English Wiktionary: Russian words with English glosses."""
    return _records(lines, _russian_word_record)


def _records(lines: Iterable[str], build: Callable[[Mapping[str, Any]], T | None]) -> Iterator[T]:
    for number, line in enumerate(lines, start=1):
        try:
            entry = json.loads(line)
        except json.JSONDecodeError as error:
            raise ValueError(f"line {number}: invalid JSON: {error}") from error
        record = build(entry)
        if record is not None:
            yield record


def _english_record(
    entry: Mapping[str, Any],
    skip: Collection[str],
    translations_of: Callable[[Mapping[str, Any]], Iterable[str]],
    translated_examples: bool,
) -> EnglishRecord | None:
    word = entry.get("word", "")
    if entry.get("lang_code") != "en" or entry.get("pos") in NOT_A_WORD:
        return None
    if not ENGLISH_WORD.fullmatch(word) or len(word) < MIN_WORD_LENGTH or word in skip or _is_only_a_form(entry):
        return None
    examples = [example for sense in entry.get("senses", []) for example in sense.get("examples", [])]
    record = EnglishRecord(
        word=word,
        pos=PARTS_OF_SPEECH.get(entry.get("pos", ""), "other"),
        translations=tuple(translations_of(entry)),
        ipa=None if translated_examples else pick_ipa(entry.get("sounds", [])),
        example=pick_example(examples, translated=translated_examples),
    )
    # A record with no translation, IPA or example adds nothing to the merge; keeping it only costs memory.
    return record if record.translations or record.ipa or record.example else None


def _english_wiktionary_translations(entry: Mapping[str, Any]) -> Iterator[str]:
    listed = [
        *entry.get("translations", []),
        *(t for sense in entry.get("senses", []) for t in sense.get("translations", [])),
    ]
    for translation in listed:
        if translation.get("lang_code") == "ru" and not OLD_TRANSLATION_TAGS & set(translation.get("tags", [])):
            yield from russian_translation_items(translation.get("word", ""))


def _russian_gloss_translations(entry: Mapping[str, Any]) -> Iterator[str]:
    for sense in entry.get("senses", []):
        if glosses := sense.get("glosses"):
            yield from russian_items(glosses[-1])


def _russian_word_record(entry: Mapping[str, Any]) -> RussianRecord | None:
    word = entry.get("word", "")
    if entry.get("lang_code") != "ru" or entry.get("pos") in NOT_A_WORD or not RUSSIAN_WORD.fullmatch(word):
        return None
    senses = [sense for sense in entry.get("senses", []) if not _is_form(sense) and sense.get("glosses")]
    translations = tuple(item for sense in senses for item in english_items(sense["glosses"][-1]))
    return RussianRecord(key=russian_key(word), translations=translations) if translations else None


def _is_form(sense: Mapping[str, Any]) -> bool:
    return bool(sense.get("form_of") or sense.get("alt_of") or FORM_TAGS & set(sense.get("tags", [])))


def _is_only_a_form(entry: Mapping[str, Any]) -> bool:
    senses = entry.get("senses", [])
    return not senses or all(_is_form(sense) for sense in senses)
