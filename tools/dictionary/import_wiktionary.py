"""Refreshes data/extended/extended-dictionary.txt from the kaikki.org Wiktionary extracts (manual, needs network).

Usage: python3 tools/dictionary/import_wiktionary.py --download-dir /tmp/lingvo-wikt
(or `make import-wiktionary WIKT_DIR=/tmp/lingvo-wikt`). Not `python3 -I`: isolated mode drops this
script's folder from sys.path, so `lingvo_dict` does not import. The downloads are only read as data.
"""

import sys

from lingvo_dict.extended.importer import main

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
