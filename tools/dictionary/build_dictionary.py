"""Builds the bundled SQLite dictionary.

Usage: python3 tools/dictionary/build_dictionary.py [--out PATH] (--full | --through N | --allow-partial)
"""

import sys

from lingvo_dict.build import main

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
