"""The batch contract: one source for the validator, the build and batch.schema.json."""

from __future__ import annotations

import re
from dataclasses import dataclass
from types import MappingProxyType

BATCH_SIZE = 500
BATCH_COUNT = 20
# Top-1000 and Top-2000 words become quiz cards; the rest is for quick-add lookup only.
TOP_1000_MAX_RANK = 1000
QUIZ_MAX_RANK = 2000
TRANSLATION_LANG = "ru"

POS_VALUES = (
    "noun",
    "verb",
    "adjective",
    "adverb",
    "pronoun",
    "preposition",
    "conjunction",
    "determiner",
    "numeral",
    "interjection",
    "other",
)
QUIZ_TRANSLATIONS = (1, 3)
LOOKUP_TRANSLATIONS = (1, 5)
TRANSLATION_MAX_LENGTH = 40
EXAMPLE_LENGTH = (10, 140)
# Russian runs about a quarter longer than the same English sentence.
EXAMPLE_RU_MAX_LENGTH = 180

BATCH_ID_PATTERN = re.compile(r"batch-(\d{2})")
TRANSLATION_PATTERN = re.compile(r"[А-Яа-яЁё]+(?:[ -][А-Яа-яЁё]+)*")
# British (RP) broad transcription between slashes, as in the design ("/ɔːlˈðəʊ/").
IPA_VOWELS = "aeiuæɑɒɔəɜɛɪʊʌ"
IPA_CONSONANTS = "bdfghjklmnprstvwxzŋθðʃʒɡʔ"
IPA_MARKS = "ːˈˌ."
IPA_PATTERN = re.compile("/[" + IPA_VOWELS + IPA_CONSONANTS + IPA_MARKS + "]+/")
EXAMPLE_PATTERN = re.compile(r"[A-Z0-9\"'][A-Za-z0-9 ,.;:!?'\"()\-–—’]*[.!?]")
# No Latin letters: an English word left in the translation would show the answer on the card.
EXAMPLE_RU_PATTERN = re.compile(r"[А-ЯЁ0-9«\"][А-Яа-яЁё0-9 ,.;:!?\"()«»\-–—]*[.!?»\"]")

QUIZ_FIELDS = ("rank", "headword", "tier", "pos", "translations", "ipa", "example", "synonym_group")
LOOKUP_FIELDS = ("rank", "headword", "tier", "pos", "translations", "ipa")
# Optional until every quiz entry has one; then it joins QUIZ_FIELDS.
QUIZ_OPTIONAL_FIELDS = ("example_ru",)


@dataclass(frozen=True)
class TierRules:
    fields: tuple[str, ...]
    translations: tuple[int, int]  # min and max count
    optional: tuple[str, ...] = ()

    @property
    def allowed(self) -> tuple[str, ...]:
        return self.fields + self.optional


# Ordered: json_schema emits oneOf in this order, and the committed schema file expects quiz first.
TIER_RULES = MappingProxyType(
    {
        "quiz": TierRules(fields=QUIZ_FIELDS, translations=QUIZ_TRANSLATIONS, optional=QUIZ_OPTIONAL_FIELDS),
        "lookup": TierRules(fields=LOOKUP_FIELDS, translations=LOOKUP_TRANSLATIONS),
    }
)
TIERS = tuple(TIER_RULES)


def is_quiz_rank(rank: int) -> bool:
    return rank <= QUIZ_MAX_RANK


def tier_for_rank(rank: int) -> str:
    return "quiz" if is_quiz_rank(rank) else "lookup"


def batch_ranks(number: int) -> tuple[int, int]:
    first = (number - 1) * BATCH_SIZE + 1
    return first, first + BATCH_SIZE - 1


def batch_id(number: int) -> str:
    return f"batch-{number:02d}"


def parse_batch_id(text: object) -> int | None:
    """Returns NN of 'batch-NN' when it names one of the BATCH_COUNT batches, else None."""
    match = BATCH_ID_PATTERN.fullmatch(text) if isinstance(text, str) else None
    if match is None:
        return None
    number = int(match.group(1))
    return number if 1 <= number <= BATCH_COUNT else None


def _anchored(pattern: re.Pattern[str]) -> str:
    return f"^{pattern.pattern}$"


def json_schema() -> dict[str, object]:
    def entry(tier: str, rules: TierRules) -> dict[str, object]:
        properties: dict[str, object] = {
            "rank": {"type": "integer", "minimum": 1},
            "headword": {
                "type": "string",
                "description": "Exactly the headword of this rank in data/wordlist/wordlist.tsv.",
            },
            "tier": {"const": tier},
            "pos": {"enum": list(POS_VALUES)},
            "translations": {
                "type": "array",
                "minItems": rules.translations[0],
                "maxItems": rules.translations[1],
                "uniqueItems": True,
                "items": {
                    "type": "string",
                    "pattern": _anchored(TRANSLATION_PATTERN),
                    "maxLength": TRANSLATION_MAX_LENGTH,
                },
            },
            "ipa": {"type": "string", "pattern": _anchored(IPA_PATTERN)},
        }
        if "example" in rules.fields:
            properties["example"] = {
                "type": "string",
                "minLength": EXAMPLE_LENGTH[0],
                "maxLength": EXAMPLE_LENGTH[1],
                "pattern": _anchored(EXAMPLE_PATTERN),
            }
            properties["synonym_group"] = {
                "type": "string",
                "description": (
                    "Headword of the lowest-ranked quiz-tier word with the same main meaning;"
                    " the entry's own headword if none."
                ),
            }
        if "example_ru" in rules.allowed:
            properties["example_ru"] = {
                "type": "string",
                "description": "A natural Russian translation of example, in the meaning of the first translation.",
                "minLength": 1,
                "maxLength": EXAMPLE_RU_MAX_LENGTH,
                "pattern": _anchored(EXAMPLE_RU_PATTERN),
            }
        return {
            "type": "object",
            "additionalProperties": False,
            "required": list(rules.fields),
            "properties": properties,
        }

    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://github.com/niklod/lingvo-buddy/tools/dictionary/batch.schema.json",
        "title": "LingvoBuddy dictionary batch",
        "description": (
            f"One batch of {BATCH_SIZE} ranks: batch-NN covers ranks (NN-1)*{BATCH_SIZE}+1 to NN*{BATCH_SIZE}. "
            f"Ranks up to {QUIZ_MAX_RANK} are quiz tier, the rest lookup tier. "
            "Generated by tools/dictionary/write_schema.py; the validator checks more rules than this schema."
        ),
        "type": "object",
        "additionalProperties": False,
        "required": ["batch", "entries"],
        "properties": {
            "batch": {"type": "string", "pattern": _anchored(BATCH_ID_PATTERN)},
            "entries": {
                "type": "array",
                "items": {
                    "oneOf": [entry(tier, rules) for tier, rules in TIER_RULES.items()]
                },
            },
        },
    }
