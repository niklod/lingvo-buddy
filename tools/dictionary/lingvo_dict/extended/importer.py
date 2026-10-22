"""The manual import: kaikki.org extracts in, the cleaned and merged text source out.

Run it by hand to refresh the data; `make dictionary` never touches the network.
"""

from __future__ import annotations

import argparse
import gzip
import shutil
import sys
import urllib.request
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path
from typing import IO

from lingvo_dict.extended.bundled import load_bundled
from lingvo_dict.extended.merge import merge_english, merge_russian
from lingvo_dict.extended.paths import EXTENDED_SOURCE_FILE
from lingvo_dict.extended.records import english_records, russian_wiktionary_records, russian_word_records
from lingvo_dict.extended.source import default_meta, parse_source, render_source
from lingvo_dict.extended.validate import validate_extended
from lingvo_dict.paths import BATCHES_DIR, REPO_ROOT

KAIKKI = "https://kaikki.org"
# English Wiktionary (English words, Russian translations), Russian Wiktionary (English entries),
# and English Wiktionary again (Russian words, English glosses).
DOWNLOADS = {
    "en": (f"{KAIKKI}/dictionary/English/kaikki.org-dictionary-English.jsonl.gz", "english.jsonl.gz"),
    "ruwikt": (
        f"{KAIKKI}/ruwiktionary/%D0%90%D0%BD%D0%B3%D0%BB%D0%B8%D0%B9%D1%81%D0%BA%D0%B8%D0%B9/"
        "kaikki.org-dictionary-%D0%90%D0%BD%D0%B3%D0%BB%D0%B8%D0%B9%D1%81%D0%BA%D0%B8%D0%B9.jsonl",
        "ruwiktionary-english.jsonl",
    ),
    "ruword": (f"{KAIKKI}/dictionary/Russian/kaikki.org-dictionary-Russian.jsonl.gz", "russian.jsonl.gz"),
}


@contextmanager
def open_lines(path: Path) -> Iterator[IO[str]]:
    opener = gzip.open if path.suffix == ".gz" else open
    with opener(path, "rt", encoding="utf-8") as lines:
        yield lines


def download(folder: Path) -> dict[str, Path]:
    """Fetches the extracts that the folder does not have yet (about 700 MB: keep the folder outside the repository)."""
    if REPO_ROOT in folder.resolve().parents or folder.resolve() == REPO_ROOT:
        raise ValueError(f"{folder} is inside the repository; downloads belong outside it")
    folder.mkdir(parents=True, exist_ok=True)
    paths = {}
    for key, (url, name) in DOWNLOADS.items():
        paths[key] = folder / name
        if not paths[key].exists():
            print(f"downloading {url}", file=sys.stderr)
            with urllib.request.urlopen(url) as response, open(paths[key], "wb") as target:  # noqa: S310
                shutil.copyfileobj(response, target)
    return paths


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--download-dir", type=Path, help="fetch the three extracts here (outside the repository)")
    parser.add_argument("--en", type=Path, help="English Wiktionary extract of English words (.jsonl or .jsonl.gz)")
    parser.add_argument("--ruwikt", type=Path, help="Russian Wiktionary extract of English entries")
    parser.add_argument("--ruword", type=Path, help="English Wiktionary extract of Russian words")
    parser.add_argument("--batches", type=Path, default=BATCHES_DIR)
    parser.add_argument("--out", type=Path, default=EXTENDED_SOURCE_FILE)
    args = parser.parse_args(argv)

    paths = download(args.download_dir) if args.download_dir else {}
    sources = {
        "en": args.en or paths.get("en"),
        "ruwikt": args.ruwikt or paths.get("ruwikt"),
        "ruword": args.ruword or paths.get("ruword"),
    }
    missing = [f"--{key}" for key, path in sources.items() if path is None]
    if missing:
        parser.error(f"pass --download-dir, or {', '.join(missing)}")

    bundled = load_bundled(args.batches)
    if not bundled.headwords:
        parser.error(f"no bundled batches in {args.batches}: the extended dictionary only holds words outside them")
    with open_lines(sources["en"]) as lines:
        english = list(english_records(lines, bundled.headwords))
    with open_lines(sources["ruwikt"]) as lines:
        russian_glosses = list(russian_wiktionary_records(lines, bundled.headwords))
    with open_lines(sources["ruword"]) as lines:
        russian_words = merge_russian(russian_word_records(lines), bundled.russian_keys)

    english_entries = merge_english(english, russian_glosses)
    text = render_source(english_entries, russian_words, default_meta())
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(text, encoding="utf-8")
    print(
        f"wrote {args.out}: {len(english_entries)} English and {len(russian_words)} Russian entries, "
        f"{len(text.encode())} bytes"
    )
    errors = validate_extended(parse_source(text), bundled)
    if errors:
        print("\n".join(errors[:50]), file=sys.stderr)
        print(f"the imported source has {len(errors)} validation errors", file=sys.stderr)
        return 1
    return 0
