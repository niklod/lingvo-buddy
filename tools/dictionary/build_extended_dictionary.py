"""Builds the bundled extended-dictionary SQLite from data/extended/extended-dictionary.txt.

Usage: python3 tools/dictionary/build_extended_dictionary.py [--out PATH]
"""

import sys

from lingvo_dict.extended.build import main

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
