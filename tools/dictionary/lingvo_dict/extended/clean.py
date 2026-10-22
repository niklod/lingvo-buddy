"""The cleaning rules for Wiktionary data. Each rule is pure, so the tests feed it small literals."""

from __future__ import annotations

import re
import unicodedata
from collections.abc import Iterable, Mapping
from typing import Any

from lingvo_dict.contract import IPA_PATTERN

MAX_ITEM_WORDS = 3
MAX_TRANSLATIONS = 5
MAX_EXAMPLE_LENGTH = 140
MAX_EXAMPLE_RU_LENGTH = 180
MIN_EXAMPLE_LENGTH = 8

STRESS_MARKS = ("́", "̀")
# A domain label such as "муз." or "разг.,": Russian Wiktionary writes them in front of a gloss.
LABELS = re.compile(r"^(?:[а-яё]{1,12}\.,?\s+)+")
PARENTHESES = re.compile(r"\([^)]*(?:\)|$)")
# A usage example is a whole sentence: "genuinely surprised" would be a fragment in the example box.
SENTENCE = re.compile(r"[A-Z0-9\"'‘“].*[.!?…\"'’”]")
RUSSIAN_ITEM = re.compile(r"[а-яёА-ЯЁ]+(?:[ -][а-яёА-ЯЁ]+)*")
ENGLISH_ITEM = re.compile(r"[A-Za-z]+(?:['-][A-Za-z]+)*(?: [A-Za-z]+(?:['-][A-Za-z]+)*)*")
# Glosses that only point at another word: they say nothing a bubble could show. A bare "форма" or
# "вариант" is a real translation, so the words need something after them.
RUSSIAN_JUNK = re.compile(
    r"^(?:(?:вариант|форм[аы]|сокращение|сокр\.|причастие|деепричастие|прошедшее|альтернативн\w+|"
    r"уменьшительн\w+|ласкательн\w+|уничижительн\w+|разговорн\w+ форма|устаревш\w+|неправильное написание|"
    r"ошибочн\w+|множественное число|превосходная степень|сравнительная степень|настоящее время|3-е лицо)\s+\S"
    r"|то же,? что|см\.)",
    re.IGNORECASE,
)
ENGLISH_JUNK = re.compile(
    r"^(?:plural|singular|alternative|alt\.?|obsolete|archaic|dated|nonstandard|misspelling|inflection|genitive|dative|"
    r"accusative|instrumental|prepositional|nominative|locative|vocative|diminutive|augmentative|feminine|masculine|"
    r"neuter|comparative|superlative|past|present|future|imperative|participle|gerund|abbreviation|initialism|"
    r"acronym|eye dialect|short form|contraction|clipping|pronunciation spelling|form|romanization)\b[^,;]*"
    r"\b(?:of|form)\b",
    re.IGNORECASE,
)
ENGLISH_LEADING_WORDS = re.compile(r"^(?:to|a|an|the)\s+(?=\S)", re.IGNORECASE)
PARTS_OF_SPEECH = {
    "noun": "noun",
    "verb": "verb",
    "adj": "adjective",
    "adv": "adverb",
    "pron": "pronoun",
    "prep": "preposition",
    "conj": "conjunction",
    "det": "determiner",
    "article": "determiner",
    "num": "numeral",
    "intj": "interjection",
}

IPA_SYMBOLS = {
    ".": "",
    " ": "",
    "(": "",
    ")": "",
    "ʔ": "",
    "ʰ": "",
    "ˑ": "",
    "ɹ": "r",
    "ɫ": "l",
    "g": "ɡ",
    "ʧ": "tʃ",
    "ʤ": "dʒ",
    "ɛ": "e",
    "ɚ": "ə",
    "ɝ": "ɜː",
    "ɾ": "t",
}
IPA_TRANSLATION = str.maketrans(IPA_SYMBOLS)
# The bundled dictionary is British (RP); the American transcription is the last resort.
BRITISH_TAGS = {"Received-Pronunciation", "UK", "British", "Southern-England"}
AMERICAN_TAGS = {"General-American", "US", "Canada"}


def strip_stress(text: str) -> str:
    decomposed = unicodedata.normalize("NFD", text)
    return unicodedata.normalize("NFC", "".join(ch for ch in decomposed if ch not in STRESS_MARKS))


def strip_labels(text: str) -> str:
    return LABELS.sub("", text.strip())


def russian_items(gloss: str) -> list[str]:
    """Short Russian translations out of one Russian gloss; empty for a gloss that only refers to another word."""
    text = PARENTHESES.sub("", strip_stress(gloss)).strip()
    if RUSSIAN_JUNK.match(text) or RUSSIAN_JUNK.match(strip_labels(text)):
        return []
    items: list[str] = []
    for segment in text.split(";"):
        for part in strip_labels(segment).split(","):
            items.append(strip_labels(part).strip(" ."))
    return _short_items(items, RUSSIAN_ITEM)


def russian_translation_items(word: str) -> list[str]:
    """A translation from the translations table of an English entry: one translation per row, so no gloss rules.

    A row with a comma or semicolon is a clause ("болезнь, вызванная паразитом"), not a bubble.
    """
    text = PARENTHESES.sub("", strip_stress(word)).strip(" .")
    return [] if re.search(r"[;,]", text) else _short_items([text], RUSSIAN_ITEM)


def russian_key(text: str) -> str:
    """The form in which Russian words are compared: no stress, lower case, «е» for «ё»."""
    return strip_stress(text).strip().lower().replace("ё", "е")


def english_items(gloss: str) -> list[str]:
    """Short English translations out of one English gloss: "to run, to flee (quickly)" gives run and flee."""
    text = PARENTHESES.sub("", gloss).strip()
    if ENGLISH_JUNK.match(text):
        return []
    parts = re.split(r"[;,]", text)
    return _short_items([ENGLISH_LEADING_WORDS.sub("", part.strip()).strip(" .") for part in parts], ENGLISH_ITEM)


def _short_items(items: Iterable[str], pattern: re.Pattern[str]) -> list[str]:
    return distinct(item for item in items if item and pattern.fullmatch(item) and len(item.split()) <= MAX_ITEM_WORDS)


def distinct(items: Iterable[str]) -> list[str]:
    """Drops repeats that differ only in case; the first spelling wins."""
    kept: dict[str, str] = {}
    for item in items:
        kept.setdefault(item.lower(), item)
    return list(kept.values())


def normalize_ipa(raw: str) -> str | None:
    """The bundled style: no syllable dots, r for ɹ, ɡ for g, e for ɛ. `None` when a symbol is not in that style."""
    text = raw.strip()
    if not (text.startswith("/") and text.endswith("/")) or len(text) < 3:
        return None
    decomposed = unicodedata.normalize("NFD", text[1:-1])
    body = "".join(ch for ch in decomposed if not unicodedata.combining(ch)).translate(IPA_TRANSLATION)
    result = f"/{body}/"
    return result if body and IPA_PATTERN.fullmatch(result) else None


def pick_ipa(sounds: Iterable[Mapping[str, Any]]) -> str | None:
    """The best transcription: British before untagged before American; a template fragment only as a last resort."""
    whole: list[tuple[int, str]] = []
    fragments: list[tuple[int, str]] = []
    for sound in sounds:
        raw = str(sound.get("ipa") or "").strip()
        priority = _ipa_priority(sound.get("tags") or [])
        if match := re.match(r"/[^/]+/", raw):
            whole.append((priority, match.group()))
        elif raw.startswith("/") and "/" not in raw[1:]:
            # The IPA template split "a, -b" into pieces; the first piece is the usual form.
            fragments.append((priority, raw + "/"))
    for _, candidate in sorted(whole, key=lambda item: item[0]) + sorted(fragments, key=lambda item: item[0]):
        if ipa := normalize_ipa(candidate):
            return ipa
    return None


def _ipa_priority(tags: Iterable[str]) -> int:
    tag_set = set(tags)
    if tag_set & BRITISH_TAGS:
        return 0
    if not tag_set:
        return 1
    return 2 if tag_set & AMERICAN_TAGS else 3


def pick_example(examples: Iterable[Mapping[str, Any]], translated: bool = False) -> tuple[str, str] | None:
    """The first short usage example (not a quotation) and its Russian translation or an empty string.

    `translated` is for Russian Wiktionary, where examples have no type but a Russian translation:
    those without one are skipped. English Wiktionary marks usage examples with type "example".
    """
    for example in examples:
        if example.get("ref"):
            continue
        text = _one_line(example.get("text"), MAX_EXAMPLE_LENGTH)
        if text is None or len(text) < MIN_EXAMPLE_LENGTH:
            continue
        if not SENTENCE.fullmatch(text):
            continue
        if translated:
            russian = _one_line(example.get("translation"), MAX_EXAMPLE_RU_LENGTH)
            if russian and re.search(r"[а-яё]", russian, re.IGNORECASE):
                return text, russian
        elif example.get("type") == "example":
            return text, ""
    return None


def _one_line(value: Any, limit: int) -> str | None:
    if not isinstance(value, str) or "\n" in value:
        return None
    text = " ".join(value.split())
    return text if 0 < len(text) <= limit else None
