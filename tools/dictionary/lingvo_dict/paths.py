"""Default repository locations, resolved from this file so the tools run from any folder."""

from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
WORDLIST_DIR = REPO_ROOT / "data" / "wordlist"
WORDLIST_FILE = WORDLIST_DIR / "wordlist.tsv"
BATCHES_DIR = REPO_ROOT / "data" / "batches"
DEFAULT_DICTIONARY = REPO_ROOT / "build" / "dictionary" / "dictionary.sqlite"
