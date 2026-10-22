"""Checks for one batch entry that need no other entry."""

from __future__ import annotations

import re
from typing import Any

from lingvo_dict.contract import (
    EXAMPLE_LENGTH,
    EXAMPLE_PATTERN,
    EXAMPLE_RU_MAX_LENGTH,
    EXAMPLE_RU_PATTERN,
    IPA_PATTERN,
    IPA_VOWELS,
    POS_VALUES,
    TIER_RULES,
    TRANSLATION_MAX_LENGTH,
    TRANSLATION_PATTERN,
    TierRules,
    tier_for_rank,
)
from lingvo_dict.wordlist_file import WordList

WORD_TOKEN = re.compile(r"[a-z]+")


def is_rank(value: Any) -> bool:
    # bool is a subclass of int, so True would pass as rank 1.
    return isinstance(value, int) and not isinstance(value, bool) and value >= 1


def check_entry(entry: Any, word_list: WordList, ranks: tuple[int, int], batch: str) -> list[str]:
    if not isinstance(entry, dict):
        return ["entry must be a JSON object"]
    rank = entry.get("rank")
    if not is_rank(rank):
        return [f"rank must be a positive integer, got {rank!r}"]

    tier = tier_for_rank(rank)
    rules = TIER_RULES[tier]
    errors = _check_fields(entry, rules)
    errors += _check_rank(rank, ranks, batch)
    errors += _check_headword(entry, rank, word_list)
    if "tier" in entry and entry["tier"] != tier:
        errors.append(f"tier must be '{tier}' for rank {rank}, got {entry['tier']!r}")
    if "pos" in entry and entry["pos"] not in POS_VALUES:
        errors.append(f"pos {entry['pos']!r} must be one of: {', '.join(POS_VALUES)}")
    if "translations" in entry:
        errors += check_translations(entry["translations"], rules.translations)
    if "ipa" in entry:
        errors += check_ipa(entry["ipa"])
    # Where a tier does not allow a field, _check_fields already reports it.
    if "example" in entry and "example" in rules.allowed and isinstance(entry.get("headword"), str):
        errors += check_example(entry["example"], entry["headword"])
    if "example_ru" in entry and "example_ru" in rules.allowed:
        errors += check_example_ru(entry["example_ru"], has_example="example" in entry)
    if tier == "quiz" and "synonym_group" in entry:
        group = entry["synonym_group"]
        if not isinstance(group, str) or not group:
            errors.append(f"synonym_group must be a headword, got {group!r}")
    return errors


def _check_fields(entry: dict[str, Any], rules: TierRules) -> list[str]:
    missing = [f"missing field '{name}'" for name in rules.fields if name not in entry]
    unknown = [f"unknown field '{name}' for this tier" for name in entry if name not in rules.allowed]
    return missing + unknown


def _check_rank(rank: int, ranks: tuple[int, int], batch: str) -> list[str]:
    first, last = ranks
    if first <= rank <= last:
        return []
    return [f"rank {rank} is outside {batch} ranks {first}-{last}"]


def _check_headword(entry: dict[str, Any], rank: int, word_list: WordList) -> list[str]:
    if "headword" not in entry:
        return []
    expected = word_list.headword_at(rank)
    if expected is None:
        return [f"rank {rank} is beyond the word list ({word_list.size} words)"]
    if entry["headword"] != expected:
        return [f"headword {entry['headword']!r} does not match: word list has '{expected}' at rank {rank}"]
    return []


def check_translations(translations: Any, limits: tuple[int, int]) -> list[str]:
    if not isinstance(translations, list):
        return ["translations must be a list of strings"]
    low, high = limits
    errors: list[str] = []
    if not low <= len(translations) <= high:
        errors.append(f"needs {low} to {high} translations, got {len(translations)}")
    seen: set[str] = set()
    for text in translations:
        if not isinstance(text, str) or not TRANSLATION_PATTERN.fullmatch(text):
            errors.append(f"translation {text!r} must be Cyrillic words separated by single spaces or hyphens")
        elif len(text) > TRANSLATION_MAX_LENGTH:
            errors.append(f"translation {text!r} is longer than {TRANSLATION_MAX_LENGTH} characters")
        elif text in seen:
            errors.append(f"duplicate translation {text!r}")
        else:
            seen.add(text)
    return errors


def check_ipa(ipa: Any) -> list[str]:
    if not isinstance(ipa, str) or not IPA_PATTERN.fullmatch(ipa):
        return [f"ipa {ipa!r} must be a British IPA transcription between slashes, e.g. '/ˈwɜːd/'"]
    if ipa.count("ˈ") > 1:
        return [f"ipa {ipa!r} has more than one primary stress mark"]
    for index, char in enumerate(ipa):
        if char == "ː" and ipa[index - 1] not in IPA_VOWELS:
            return [f"ipa {ipa!r}: the length mark ː must follow a vowel"]
    return []


def check_example(example: Any, headword: str) -> list[str]:
    if not isinstance(example, str):
        return ["example must be a string"]
    low, high = EXAMPLE_LENGTH
    if not low <= len(example) <= high:
        return [f"example must have {low} to {high} characters, got {len(example)}"]
    if not EXAMPLE_PATTERN.fullmatch(example):
        return [f"example {example!r} must be one English sentence: capital first, '.', '!' or '?' last"]
    stem = _stem(headword.lower())
    if not any(token.startswith(stem) for token in WORD_TOKEN.findall(example.lower())):
        return [f"example must contain '{headword}' or a form that starts with '{stem}'"]
    return []


def check_example_ru(example_ru: Any, has_example: bool) -> list[str]:
    if not has_example:
        return ["example_ru needs an English example: it is the translation of 'example'"]
    if example_ru == "":
        return ["example_ru must not be empty"]
    if isinstance(example_ru, str) and len(example_ru) > EXAMPLE_RU_MAX_LENGTH:
        return [f"example_ru must have at most {EXAMPLE_RU_MAX_LENGTH} characters, got {len(example_ru)}"]
    if not isinstance(example_ru, str) or not EXAMPLE_RU_PATTERN.fullmatch(example_ru):
        return [f"example_ru {example_ru!r} must be one Russian sentence: Cyrillic, capital first, no Latin"]
    return []


def _stem(headword: str) -> str:
    """Lets regular forms match: make -> making, try -> tried."""
    if len(headword) > 2 and headword[-1] in "ey":
        return headword[:-1]
    return headword
