"""Builds the bundled read-only SQLite dictionary from validated batch files."""

from __future__ import annotations

import argparse
import hashlib
import os
import sqlite3
import sys
from pathlib import Path
from typing import List, Sequence

from lingvo_dict.contract import POS_VALUES, TIERS, TRANSLATION_LANG
from lingvo_dict.paths import DEFAULT_DICTIONARY
from lingvo_dict.validate import LoadedEntry, add_selection_arguments, batch_files, load_and_validate, plural
from lingvo_dict.wordlist_file import WordList

ATTRIBUTION = (
    "Word frequencies: wordfreq by Robyn Speer, CC BY-SA 4.0, https://github.com/rspeer/wordfreq. "
    "Translations, transcriptions and examples: LingvoBuddy."
)


def _in_list(values: Sequence[str]) -> str:
    return ", ".join(f"'{value}'" for value in values)


# Mirrors LingvoCore/Sources/LingvoCore/Dictionary/DictionarySchema.swift; keep both in step.
SCHEMA_VERSION = 2
SCHEMA = f"""
CREATE TABLE entries (
    id INTEGER PRIMARY KEY,
    headword TEXT NOT NULL UNIQUE,
    rank INTEGER NOT NULL UNIQUE,
    pos TEXT NOT NULL CHECK (pos IN ({_in_list(POS_VALUES)})),
    ipa TEXT NOT NULL,
    example TEXT,
    synonym_group TEXT,
    tier TEXT NOT NULL CHECK (tier IN ({_in_list(TIERS)}))
);
CREATE TABLE translations (
    entry_id INTEGER NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
    lang TEXT NOT NULL,
    ord INTEGER NOT NULL,
    text TEXT NOT NULL,
    PRIMARY KEY (entry_id, lang, ord)
);
CREATE INDEX translations_text ON translations(lang, text);
CREATE TABLE quiz_exclusions (
    headword TEXT PRIMARY KEY REFERENCES entries(headword)
);
CREATE TABLE meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
PRAGMA user_version = {SCHEMA_VERSION};
"""


def write_dictionary(
    entries: Sequence[LoadedEntry], meta: Sequence[tuple], out: Path, quiz_exclusions: Sequence[str] = ()
) -> None:
    """Writes to a temporary file first so a failed build never leaves a half-written dictionary."""
    out.parent.mkdir(parents=True, exist_ok=True)
    temporary = out.with_name(out.name + ".tmp")
    if temporary.exists():
        temporary.unlink()
    connection = sqlite3.connect(temporary)
    try:
        with connection:
            connection.executescript(SCHEMA)
            ordered = sorted(entries, key=lambda item: item.rank)
            connection.executemany(
                "INSERT INTO entries (id, headword, rank, pos, ipa, example, synonym_group, tier)"
                " VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                [_entry_row(item) for item in ordered],
            )
            connection.executemany(
                "INSERT INTO translations (entry_id, lang, ord, text) VALUES (?, ?, ?, ?)",
                [
                    (item.rank, TRANSLATION_LANG, index, text)
                    for item in ordered
                    for index, text in enumerate(item.data["translations"])
                ],
            )
            # A partial build (--through 1000) holds only some ranks; skip exclusions of words it lacks.
            built = {item.headword for item in ordered}
            connection.executemany(
                "INSERT INTO quiz_exclusions (headword) VALUES (?)",
                [(headword,) for headword in sorted(quiz_exclusions) if headword in built],
            )
            connection.executemany("INSERT INTO meta (key, value) VALUES (?, ?)", list(meta))
        # The app opens the file read-only inside its signed bundle, where SQLite
        # cannot create -wal/-shm files, so the file must stay in rollback-journal mode.
        connection.execute("PRAGMA journal_mode=DELETE")
        connection.execute("VACUUM")
    finally:
        connection.close()
    os.replace(temporary, out)


def _entry_row(item: LoadedEntry) -> tuple:
    data = item.data
    return (
        item.rank,  # id equals rank so ids stay stable when batches are rebuilt
        item.headword,
        item.rank,
        data["pos"],
        data["ipa"],
        data.get("example"),
        data.get("synonym_group"),
        data["tier"],
    )


def build_meta(word_list: WordList, word_list_path: Path, paths: Sequence[Path], entries: Sequence[LoadedEntry]) -> List[tuple]:
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


def main(argv: List[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    add_selection_arguments(parser)
    parser.add_argument("--out", type=Path, default=DEFAULT_DICTIONARY, help="SQLite file to write")
    args = parser.parse_args(argv)

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
