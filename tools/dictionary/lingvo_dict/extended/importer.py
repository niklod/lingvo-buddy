"""The manual import: kaikki.org extracts in, the cleaned and merged text source out.

Run it by hand to refresh the data; `make dictionary` never touches the network.
"""

from __future__ import annotations

import argparse
import gzip
import shutil
import sys
import urllib.parse
import urllib.request
from collections.abc import Callable, Iterable, Iterator
from contextlib import ExitStack, contextmanager
from pathlib import Path
from typing import IO, Any, TypeVar

from lingvo_dict.extended.bundled import Bundled, load_bundled
from lingvo_dict.extended.merge import merge_english, merge_russian
from lingvo_dict.extended.paths import EXTENDED_SOURCE_FILE
from lingvo_dict.extended.records import english_records, russian_wiktionary_records, russian_word_records
from lingvo_dict.extended.source import default_meta, parse_source, render_source
from lingvo_dict.extended.validate import print_errors, validate_extended
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
# Seconds without data before a stalled download fails; the whole file may take much longer.
DOWNLOAD_TIMEOUT = 60

T = TypeVar("T")
Opener = Callable[..., Any]


class DownloadError(OSError):
    pass


@contextmanager
def open_lines(path: Path) -> Iterator[IO[str]]:
    opener = gzip.open if path.suffix == ".gz" else open
    with opener(path, "rt", encoding="utf-8") as lines:
        yield lines


def download(folder: Path, opener: Opener = urllib.request.urlopen) -> dict[str, Path]:
    """Fetches the extracts that the folder does not have yet (about 700 MB: keep the folder outside the repository)."""
    if REPO_ROOT in folder.resolve().parents or folder.resolve() == REPO_ROOT:
        raise ValueError(f"{folder} is inside the repository; downloads belong outside it")
    folder.mkdir(parents=True, exist_ok=True)
    paths = {}
    for key, (url, name) in DOWNLOADS.items():
        paths[key] = folder / name
        if not paths[key].exists():
            print(f"downloading {url}", file=sys.stderr)
            fetch(url, paths[key], opener)
    return paths


def fetch(url: str, target: Path, opener: Opener = urllib.request.urlopen) -> None:
    """Downloads into a .part file first: a stopped download must not look like a finished one on the next run."""
    partial = target.with_name(target.name + ".part")
    try:
        with opener(url, timeout=DOWNLOAD_TIMEOUT) as response:
            final_url = response.geturl()
            if urllib.parse.urlsplit(final_url).scheme != "https":
                raise DownloadError(f"{url} redirected to {final_url}, which is not https")
            expected = response.headers.get("Content-Length")
            with open(partial, "wb") as out:
                shutil.copyfileobj(response, out)
        size = partial.stat().st_size
        if expected is not None and str(size) != expected.strip():
            raise DownloadError(f"{url} stopped after {size} of {expected} bytes")
        partial.replace(target)
    except BaseException:
        partial.unlink(missing_ok=True)
        raise


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--download-dir", type=Path, help="fetch the three extracts here (outside the repository)")
    parser.add_argument("--en", type=Path, help="English Wiktionary extract of English words (.jsonl or .jsonl.gz)")
    parser.add_argument("--ruwikt", type=Path, help="Russian Wiktionary extract of English entries")
    parser.add_argument("--ruword", type=Path, help="English Wiktionary extract of Russian words")
    parser.add_argument("--batches", type=Path, default=BATCHES_DIR)
    parser.add_argument("--out", type=Path, default=EXTENDED_SOURCE_FILE)
    args = parser.parse_args(argv)
    try:
        return _run(parser, args)
    except (OSError, EOFError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2


def _run(parser: argparse.ArgumentParser, args: argparse.Namespace) -> int:
    downloaded = download(args.download_dir) if args.download_dir else {}
    given: dict[str, Path | None] = {key: getattr(args, key) or downloaded.get(key) for key in DOWNLOADS}
    missing = [f"--{key}" for key, path in given.items() if path is None]
    if missing:
        parser.error(f"pass --download-dir, or {', '.join(missing)}")
    sources = {key: path for key, path in given.items() if path is not None}

    bundled = load_bundled(args.batches)
    if not bundled.headwords:
        parser.error(f"no bundled batches in {args.batches}: the extended dictionary only holds words outside them")
    text, english_count, russian_count = _import(sources, bundled)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(text, encoding="utf-8")
    print(f"wrote {args.out}: {english_count} English and {russian_count} Russian entries, {len(text.encode())} bytes")
    errors = validate_extended(parse_source(text), bundled)
    if errors:
        print_errors(errors, f"the imported source has {len(errors)} validation errors")
        return 1
    return 0


def _import(sources: dict[str, Path], bundled: Bundled) -> tuple[str, int, int]:
    """Streams the records of all three extracts into the merge, so only the merged groups stay in memory."""
    with ExitStack() as stack:

        def read(key: str, records: Callable[[Iterable[str]], Iterator[T]]) -> Iterator[T]:
            path = sources[key]
            return _naming_errors(path, records(stack.enter_context(open_lines(path))))

        english = merge_english(
            read("en", lambda lines: english_records(lines, bundled.headwords)),
            read("ruwikt", lambda lines: russian_wiktionary_records(lines, bundled.headwords)),
        )
        russian = merge_russian(read("ruword", russian_word_records), bundled.russian_keys)
    return render_source(english, russian, default_meta()), len(english), len(russian)


def _naming_errors(path: Path, records: Iterator[T]) -> Iterator[T]:
    """A broken line or a cut gzip stream shows up while the merge reads; the message must name the file."""
    try:
        yield from records
    except (OSError, EOFError, ValueError) as error:
        raise ValueError(f"{path}: {error}") from error
