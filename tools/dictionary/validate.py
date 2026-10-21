"""Validates batch files. Usage: python3 tools/dictionary/validate.py [batch files] [--through N | --full]."""

import sys

from lingvo_dict.validate import main

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
