"""Builds the bundled read-only SQLite extended dictionary from the committed source, with no network."""

from __future__ import annotations

import argparse
import hashlib
import sqlite3
import sys
from pathlib import Path

from lingvo_dict.contract import POS_VALUES
from lingvo_dict.extended.bundled import BundledError, load_bundled
from lingvo_dict.extended.paths import DEFAULT_EXTENDED_DICTIONARY, EXTENDED_SOURCE_FILE
from lingvo_dict.extended.source import SEPARATOR, ExtendedData, SourceError, parse_source
from lingvo_dict.extended.validate import print_errors, validate_extended
from lingvo_dict.paths import BATCHES_DIR
from lingvo_dict.sqlite_file import atomic_database, sql_in_list

# Mirrors LingvoCore/Sources/LingvoCore/Dictionary/ExtendedSchema.swift; keep both in step.
SCHEMA_VERSION = 1
SCHEMA = f"""
CREATE TABLE english (
    headword TEXT PRIMARY KEY,
    pos TEXT NOT NULL CHECK (pos IN ({sql_in_list(POS_VALUES)})),
    ipa TEXT,
    translations TEXT NOT NULL,
    example TEXT,
    example_ru TEXT
) WITHOUT ROWID;
CREATE TABLE russian (
    word TEXT PRIMARY KEY,
    translations TEXT NOT NULL
) WITHOUT ROWID;
CREATE TABLE meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
PRAGMA user_version = {SCHEMA_VERSION};
"""


def write_extended(data: ExtendedData, source_digest: str, out: Path) -> None:
    with atomic_database(out) as connection:
        connection.executescript(SCHEMA)
        connection.executemany(
            "INSERT INTO english (headword, pos, ipa, translations, example, example_ru) VALUES (?, ?, ?, ?, ?, ?)",
            [(e.headword, e.pos, e.ipa, SEPARATOR.join(e.translations), e.example, e.example_ru) for e in data.english],
        )
        connection.executemany(
            "INSERT INTO russian (word, translations) VALUES (?, ?)",
            [(e.word, SEPARATOR.join(e.translations)) for e in data.russian],
        )
        connection.executemany("INSERT INTO meta (key, value) VALUES (?, ?)", _meta(data, source_digest))


def _meta(data: ExtendedData, source_digest: str) -> list[tuple[str, str]]:
    built_from = f"{len(data.english)} English, {len(data.russian)} Russian entries; sha256:{source_digest[:12]}"
    return [*sorted(data.meta.items()), ("built_from", built_from)]


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Builds the extended dictionary SQLite from its committed source.")
    parser.add_argument("--source", type=Path, default=EXTENDED_SOURCE_FILE)
    parser.add_argument("--out", type=Path, default=DEFAULT_EXTENDED_DICTIONARY)
    parser.add_argument(
        "--batches", type=Path, default=BATCHES_DIR, help="bundled batch files; words in them may not repeat"
    )
    args = parser.parse_args(argv)
    try:
        text = args.source.read_text(encoding="utf-8")
        data = parse_source(text)
        bundled = load_bundled(args.batches)
    except (OSError, SourceError) as error:
        print(f"error: cannot read {args.source}: {error}", file=sys.stderr)
        return 2
    except BundledError as error:
        print(f"error: {error}", file=sys.stderr)
        return 2
    errors = validate_extended(data, bundled)
    if errors:
        print_errors(errors, f"build stopped: {len(errors)} validation errors in {args.source}")
        return 1
    try:
        write_extended(data, hashlib.sha256(text.encode("utf-8")).hexdigest(), args.out)
    except (OSError, sqlite3.Error) as error:
        print(f"error: cannot write {args.out}: {error}", file=sys.stderr)
        return 1
    print(f"wrote {args.out}: {len(data.english)} English and {len(data.russian)} Russian entries")
    return 0
