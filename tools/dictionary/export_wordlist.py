"""Writes data/wordlist/wordlist.tsv and excluded.tsv from wordfreq. Run with the export venv."""

import sys

from lingvo_dict.export import main

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
