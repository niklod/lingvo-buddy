"""The committed text source of the extended dictionary: compact, sorted and the same on every run.

Format, after the `# key: value` header lines (tab separated, translations joined by "|"):
  E  headword  pos  ipa  translations  example  example_ru
  R  word  translations
English entries come first, each block sorted, so a refresh of the data is a reviewable diff.
"""

from __future__ import annotations

import re
from collections.abc import Iterable, Mapping
from dataclasses import dataclass

from lingvo_dict.extended.merge import EnglishEntry, RussianEntry

LICENSE = (
    "Word translations, transcriptions and examples: Wiktionary contributors (en.wiktionary.org, ru.wiktionary.org), "
    "via kaikki.org, CC BY-SA 4.0, https://creativecommons.org/licenses/by-sa/4.0/. "
    "Modified: cleaned, shortened and merged."
)
SOURCE = (
    "Wiktionary extracts by kaikki.org (English words with Russian translations, Russian words with English glosses)"
)
SEPARATOR = "|"
HEADER_LINE = re.compile(r"# ([a-z_]+): (.+)")
ENGLISH_FIELDS = 7
RUSSIAN_FIELDS = 3


class SourceError(ValueError):
    pass


@dataclass(frozen=True)
class ExtendedData:
    english: tuple[EnglishEntry, ...]
    russian: tuple[RussianEntry, ...]
    meta: Mapping[str, str]


def render_source(english: Iterable[EnglishEntry], russian: Iterable[RussianEntry], meta: Mapping[str, str]) -> str:
    lines = [
        "# LingvoBuddy extended dictionary: cleaned Wiktionary data. Made by tools/dictionary/import_wiktionary.py;",
        "# do not edit by hand. `make dictionary` turns it into the bundled extended-dictionary.sqlite.",
        "#   E <tab> headword <tab> pos <tab> ipa <tab> translations <tab> example <tab> example_ru",
        "#   R <tab> russian word (no stress, е for ё) <tab> english translations",
        *(f"# {key}: {value}" for key, value in sorted(meta.items())),
    ]
    lines += [_english_line(entry) for entry in sorted(english, key=lambda entry: entry.headword)]
    lines += [_russian_line(entry) for entry in sorted(russian, key=lambda entry: entry.word)]
    return "\n".join(lines) + "\n"


def parse_source(text: str) -> ExtendedData:
    meta: dict[str, str] = {}
    english: list[EnglishEntry] = []
    russian: list[RussianEntry] = []
    for number, line in enumerate(text.splitlines(), start=1):
        if line.startswith("#"):
            if match := HEADER_LINE.fullmatch(line):
                meta[match.group(1)] = match.group(2)
        elif line:
            fields = line.split("\t")
            try:
                _parse_line(fields, english, russian)
            except ValueError as error:
                raise SourceError(f"line {number}: {error}") from error
    return ExtendedData(english=tuple(english), russian=tuple(russian), meta=meta)


def _parse_line(fields: list[str], english: list[EnglishEntry], russian: list[RussianEntry]) -> None:
    kind = fields[0]
    if kind == "E" and len(fields) == ENGLISH_FIELDS:
        _, headword, pos, ipa, translations, example, example_ru = fields
        english.append(
            EnglishEntry(headword, pos, ipa or None, _split(translations), example or None, example_ru or None)
        )
    elif kind == "R" and len(fields) == RUSSIAN_FIELDS:
        russian.append(RussianEntry(fields[1], _split(fields[2])))
    else:
        raise ValueError(f"expected an E line with {ENGLISH_FIELDS} fields or an R line with {RUSSIAN_FIELDS}")


def _english_line(entry: EnglishEntry) -> str:
    return "\t".join(
        [
            "E",
            entry.headword,
            entry.pos,
            entry.ipa or "",
            SEPARATOR.join(entry.translations),
            entry.example or "",
            entry.example_ru or "",
        ]
    )


def _russian_line(entry: RussianEntry) -> str:
    return "\t".join(["R", entry.word, SEPARATOR.join(entry.translations)])


def _split(translations: str) -> tuple[str, ...]:
    return tuple(translations.split(SEPARATOR)) if translations else ()


def default_meta() -> dict[str, str]:
    return {"license": LICENSE, "source": SOURCE}
