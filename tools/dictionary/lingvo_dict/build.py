"""Builds the bundled read-only SQLite dictionary from validated batch files."""

from __future__ import annotations

import argparse
import hashlib
import sqlite3
import sys
from collections.abc import Sequence
from pathlib import Path
from typing import Optional

from lingvo_dict.contract import POS_VALUES, TIERS, TRANSLATION_LANG
from lingvo_dict.paths import DEFAULT_DICTIONARY
from lingvo_dict.russian_text import normalized
from lingvo_dict.sqlite_file import atomic_database, sql_in_list
from lingvo_dict.validate import (
    LoadedEntry,
    add_selection_arguments,
    batch_files,
    load_and_validate,
    plural,
)
from lingvo_dict.wordlist_file import WordList

ATTRIBUTION = (
    "Word frequencies: wordfreq by Robyn Speer, CC BY-SA 4.0, https://github.com/rspeer/wordfreq. "
    "Translations, transcriptions and examples: LingvoBuddy."
)


# Mirrors LingvoCore/Sources/LingvoCore/Dictionary/DictionarySchema.swift; keep both in step.
SCHEMA_VERSION = 4
SCHEMA = f"""
CREATE TABLE entries (
    id INTEGER PRIMARY KEY,
    headword TEXT NOT NULL UNIQUE,
    rank INTEGER NOT NULL UNIQUE,
    pos TEXT NOT NULL CHECK (pos IN ({sql_in_list(POS_VALUES)})),
    ipa TEXT NOT NULL,
    example TEXT,
    example_ru TEXT,
    synonym_group TEXT,
    tier TEXT NOT NULL CHECK (tier IN ({sql_in_list(TIERS)}))
);
CREATE TABLE translations (
    entry_id INTEGER NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
    lang TEXT NOT NULL,
    ord INTEGER NOT NULL,
    text TEXT NOT NULL,
    norm TEXT NOT NULL,
    PRIMARY KEY (entry_id, lang, ord)
);
CREATE INDEX translations_norm ON translations(lang, norm);
CREATE TABLE quiz_exclusions (
    headword TEXT PRIMARY KEY REFERENCES entries(headword)
);
CREATE TABLE meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
PRAGMA user_version = {SCHEMA_VERSION};
"""


INSERT_ENTRY = (
    "INSERT INTO entries (id, headword, rank, pos, ipa, example, example_ru, synonym_group, tier)"
    " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
)
INSERT_TRANSLATION = "INSERT INTO translations (entry_id, lang, ord, text, norm) VALUES (?, ?, ?, ?, ?)"
INSERT_EXCLUSION = "INSERT INTO quiz_exclusions (headword) VALUES (?)"
INSERT_META = "INSERT INTO meta (key, value) VALUES (?, ?)"

MetaRow = tuple[str, str]
EntryRow = tuple[int, str, int, str, str, Optional[str], Optional[str], Optional[str], str]


def write_dictionary(
    entries: Sequence[LoadedEntry], meta: Sequence[MetaRow], out: Path, quiz_exclusions: Sequence[str] = ()
) -> None:
    with atomic_database(out) as connection:
        _insert_all(connection, sorted(entries, key=lambda item: item.rank), meta, quiz_exclusions)


def _insert_all(
    connection: sqlite3.Connection,
    ordered: Sequence[LoadedEntry],
    meta: Sequence[MetaRow],
    quiz_exclusions: Sequence[str],
) -> None:
    connection.executescript(SCHEMA)
    connection.executemany(INSERT_ENTRY, [_entry_row(item) for item in ordered])
    connection.executemany(
        INSERT_TRANSLATION,
        [
            # Russian input matches `norm` with an index, so the app needs no lookup table in memory.
            (item.rank, TRANSLATION_LANG, index, text, normalized(text))
            for item in ordered
            for index, text in enumerate(item.data["translations"])
        ],
    )
    # A partial build (--through 1000) holds only some ranks; skip exclusions of words it lacks.
    built = {item.headword for item in ordered}
    connection.executemany(INSERT_EXCLUSION, [(headword,) for headword in sorted(quiz_exclusions) if headword in built])
    connection.executemany(INSERT_META, meta)


def _entry_row(item: LoadedEntry) -> EntryRow:
    data = item.data
    return (
        item.rank,  # id equals rank so ids stay stable when batches are rebuilt
        item.headword,
        item.rank,
        data["pos"],
        data["ipa"],
        data.get("example"),
        data.get("example_ru"),
        data.get("synonym_group"),
        data["tier"],
    )


def build_meta(
    word_list: WordList, word_list_path: Path, paths: Sequence[Path], entries: Sequence[LoadedEntry]
) -> list[MetaRow]:
    batch_names = ", ".join(path.stem for path in paths)
    batches_digest = hashlib.sha256()
    for path in paths:
        batches_digest.update(path.read_bytes())
    word_list_digest = hashlib.sha256(word_list_path.read_bytes()).hexdigest()[:12]
    built_from = (
        f"{word_list_path.name} sha256:{word_list_digest}; "
        f"{batch_names} sha256:{batches_digest.hexdigest()[:12]}; {len(entries)} entries"
    )
    return [
        ("source", word_list.header_value("source") or "wordfreq"),
        ("license", ATTRIBUTION),
        ("built_from", built_from),
    ]


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    add_selection_arguments(parser)
    parser.add_argument("--out", type=Path, default=DEFAULT_DICTIONARY, help="SQLite file to write")
    args = parser.parse_args(argv)
    # Without a coverage rule a missing batch file would ship a dictionary with a hole in it.
    if not (args.full or args.through is not None or args.allow_partial):
        parser.error("pass --full, --through RANK or --allow-partial")

    paths = batch_files(args.batches)
    word_list, report = load_and_validate(args, paths)
    if word_list is None or report.errors:
        for error in report.errors:
            print(error, file=sys.stderr)
        print("build stopped: fix the validation errors first", file=sys.stderr)
        return 2 if word_list is None else 1
    try:
        meta = build_meta(word_list, args.word_list, paths, report.entries)
        write_dictionary(report.entries, meta, args.out, report.quiz_exclusions)
    except (OSError, sqlite3.Error) as error:
        print(f"error: cannot write {args.out}: {error}", file=sys.stderr)
        return 1
    print(
        f"wrote {args.out}: {plural(report.entry_count, 'entry')} from {plural(report.batch_count, 'batch')}, "
        f"{plural(len(report.quiz_exclusions), 'quiz exclusion')}"
    )
    return 0
