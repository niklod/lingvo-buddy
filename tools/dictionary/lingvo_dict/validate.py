"""Validates dictionary batch files against the word list and the batch contract."""

from __future__ import annotations

import argparse
import json
import sys
from collections.abc import Iterable, Sequence
from dataclasses import dataclass, replace
from pathlib import Path
from typing import Any

from lingvo_dict.contract import BATCH_COUNT, batch_ranks, is_quiz_rank, parse_batch_id
from lingvo_dict.entry_rules import check_entry, is_rank
from lingvo_dict.exclusions import read_exclusions
from lingvo_dict.loaded_entry import LoadedEntry
from lingvo_dict.paths import BATCHES_DIR, QUIZ_EXCLUSIONS_FILE, WORDLIST_FILE
from lingvo_dict.shared_translations import shared_translation_report
from lingvo_dict.synonym_groups import check_synonym_groups
from lingvo_dict.wordlist_file import WordList, WordListError, read_word_list


@dataclass(frozen=True)
class ValidationOptions:
    allow_partial: bool = False  # a batch may miss ranks of its range (work in progress)
    through_rank: int | None = None  # every rank 1..N must be present
    full: bool = False  # every rank of the word list must be present


@dataclass(frozen=True)
class ValidationReport:
    errors: tuple[str, ...]
    entries: tuple[LoadedEntry, ...]
    batch_count: int
    quiz_exclusions: tuple[str, ...] = ()  # lookup-tier headwords that never become quiz cards

    @property
    def entry_count(self) -> int:
        return len(self.entries)


def validate_batches(paths: Sequence[Path], word_list: WordList, options: ValidationOptions) -> ValidationReport:
    errors: list[str] = []
    entries: list[LoadedEntry] = []
    for path in paths:
        batch_errors, batch_entries = _validate_file(path, word_list, options)
        errors += batch_errors
        entries += batch_entries
    errors += _check_duplicates(entries)
    errors += check_synonym_groups(entries, word_list, options.allow_partial)
    errors += _check_coverage(entries, word_list, options)
    return ValidationReport(
        errors=tuple(errors),
        entries=tuple(entries),
        batch_count=len(paths),
    )


def _validate_file(path: Path, word_list: WordList, options: ValidationOptions) -> tuple[list[str], list[LoadedEntry]]:
    """Returns the errors and the loadable entries."""
    name = path.name
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except OSError as error:
        return [f"{name}: cannot read file: {error}"], []
    except (json.JSONDecodeError, UnicodeDecodeError) as error:
        return [f"{name}: invalid JSON: {error}"], []

    header_errors, number = _check_header(document, name)
    if number is None:
        return header_errors, []

    ranks = batch_ranks(number)
    batch = document["batch"]
    errors = list(header_errors)
    loaded: list[LoadedEntry] = []
    for entry in document["entries"]:
        label = _label(name, entry)
        errors += [f"{label}: {message}" for message in check_entry(entry, word_list, ranks, batch)]
        if _is_loadable(entry):
            group = entry.get("synonym_group") if is_quiz_rank(entry["rank"]) else None
            loaded.append(LoadedEntry(name, entry["rank"], entry["headword"], group, entry))

    errors += _check_order(name, [item.rank for item in loaded])
    if not options.allow_partial:
        missing = _missing_ranks(ranks[0], min(ranks[1], word_list.size), loaded)
        if missing:
            errors.append(
                f"{name}: missing ranks {format_ranges(missing)} (use --allow-partial while the batch is in progress)"
            )
    return errors, loaded


def _is_loadable(entry: Any) -> bool:
    return isinstance(entry, dict) and is_rank(entry.get("rank")) and isinstance(entry.get("headword"), str)


def _missing_ranks(first: int, last: int, entries: Iterable[LoadedEntry]) -> list[int]:
    return sorted(set(range(first, last + 1)) - {item.rank for item in entries})


def _check_header(document: Any, name: str) -> tuple[list[str], int | None]:
    if not isinstance(document, dict):
        return [f"{name}: top level must be an object with 'batch' and 'entries'"], None
    unknown = sorted(set(document) - {"batch", "entries"})
    errors = [f"{name}: unknown top-level field '{key}'" for key in unknown]
    batch = document.get("batch")
    number = parse_batch_id(batch)
    if number is None:
        return errors + [f"{name}: 'batch' must be batch-01 to batch-{BATCH_COUNT:02d}, got {batch!r}"], None
    if not isinstance(document.get("entries"), list):
        return errors + [f"{name}: 'entries' must be a list"], None
    if name != f"{batch}.json":
        errors.append(f"{name}: file name must be {batch}.json")
    return errors, number


def _label(name: str, entry: Any) -> str:
    if isinstance(entry, dict):
        return f"{name}: rank {entry.get('rank')!r} {entry.get('headword')!r}"
    return f"{name}: entry {entry!r}"


def _check_order(name: str, ranks: list[int]) -> list[str]:
    for previous, current in zip(ranks, ranks[1:]):
        if current <= previous:
            return [f"{name}: entries must be sorted by rank (rank {current} after {previous})"]
    return []


def _check_duplicates(entries: Iterable[LoadedEntry]) -> list[str]:
    errors = []
    seen_ranks: dict[int, str] = {}
    seen_headwords: dict[str, str] = {}
    for item in entries:
        if item.rank in seen_ranks:
            errors.append(f"{item.file}: duplicate rank {item.rank} (also in {seen_ranks[item.rank]})")
        if item.headword in seen_headwords:
            first_file = seen_headwords[item.headword]
            errors.append(f"{item.file}: duplicate headword '{item.headword}' (also in {first_file})")
        seen_ranks.setdefault(item.rank, item.file)
        seen_headwords.setdefault(item.headword, item.file)
    return errors


def _check_coverage(entries: Sequence[LoadedEntry], word_list: WordList, options: ValidationOptions) -> list[str]:
    through = word_list.size if options.full else options.through_rank
    if through is None:
        return []
    if through > word_list.size:
        return [f"coverage: --through {through} is beyond the word list ({word_list.size} words)"]
    missing = _missing_ranks(1, through, entries)
    if missing:
        return [f"coverage: missing ranks {format_ranges(missing)} of 1-{through}"]
    return []


def format_ranges(numbers: Sequence[int], limit: int = 10) -> str:
    ranges: list[str] = []
    start = previous = numbers[0]
    for number in list(numbers[1:]) + [None]:
        if number is not None and number == previous + 1:
            previous = number
            continue
        ranges.append(str(start) if start == previous else f"{start}-{previous}")
        if number is not None:
            start = previous = number
    shown = ", ".join(ranges[:limit])
    return shown + (f" and {len(ranges) - limit} more" if len(ranges) > limit else "")


def plural(count: int, noun: str) -> str:
    if count == 1:
        return f"1 {noun}"
    if noun.endswith("y"):
        return f"{count} {noun[:-1]}ies"
    return f"{count} {noun}{'es' if noun.endswith('h') else 's'}"


def batch_files(folder: Path) -> list[Path]:
    return sorted(folder.glob("batch-*.json"))


def add_selection_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--batches", type=Path, default=BATCHES_DIR, help="folder with batch-NN.json files")
    parser.add_argument("--word-list", type=Path, default=WORDLIST_FILE, help="ranked word list (TSV)")
    parser.add_argument(
        "--quiz-exclusions", type=Path, default=QUIZ_EXCLUSIONS_FILE, help="headwords that never become quiz cards"
    )
    parser.add_argument("--allow-partial", action="store_true", help="accept batches that miss ranks")
    coverage = parser.add_mutually_exclusive_group()
    coverage.add_argument("--through", type=int, metavar="RANK", help="require every rank from 1 to RANK")
    coverage.add_argument(
        "--full",
        action="store_true",
        help="require every rank of the word list, so all batches must exist",
    )


def options_from(args: argparse.Namespace) -> ValidationOptions:
    return ValidationOptions(allow_partial=args.allow_partial, through_rank=args.through, full=args.full)


def load_and_validate(args: argparse.Namespace, files: Sequence[Path]) -> tuple[WordList | None, ValidationReport]:
    """Returns (None, report) when the word list cannot be read."""
    try:
        word_list = read_word_list(args.word_list)
    except WordListError as error:
        return None, ValidationReport(errors=(str(error),), entries=(), batch_count=0)
    paths = list(files) or batch_files(args.batches)
    if not paths:
        no_batches = (f"no batch-*.json files in {args.batches}",)
        return word_list, ValidationReport(errors=no_batches, entries=(), batch_count=0)
    report = validate_batches(paths, word_list, options_from(args))
    exclusions, exclusion_errors = read_exclusions(args.quiz_exclusions, word_list)
    return word_list, replace(report, errors=report.errors + tuple(exclusion_errors), quiz_exclusions=exclusions)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("files", nargs="*", type=Path, help="batch files (default: every batch in --batches)")
    add_selection_arguments(parser)
    parser.add_argument(
        "--report-shared-translations",
        action="store_true",
        help="also list first translations shared across synonym groups or split inside one (review only)",
    )
    args = parser.parse_args(argv)

    word_list, report = load_and_validate(args, args.files)
    if word_list is None:
        print(f"error: {report.errors[0]}", file=sys.stderr)
        return 2
    if args.report_shared_translations:
        print("\n".join(shared_translation_report(report.entries, report.quiz_exclusions)))
    if report.errors:
        for error in report.errors:
            print(error, file=sys.stderr)
        print(f"FAILED: {plural(len(report.errors), 'error')}", file=sys.stderr)
        return 1
    print(
        f"OK: {plural(report.entry_count, 'entry')} in {plural(report.batch_count, 'batch')}, "
        f"{plural(len(report.quiz_exclusions), 'quiz exclusion')}"
    )
    return 0
