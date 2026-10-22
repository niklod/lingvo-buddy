"""Refreshes data/extended/extended-dictionary.txt from the kaikki.org Wiktionary extracts (manual, needs network).

Usage: python3 -I tools/dictionary/import_wiktionary.py --download-dir /tmp/lingvo-wikt
"""

import sys

from lingvo_dict.extended.importer import main

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
