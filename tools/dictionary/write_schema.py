"""Regenerates tools/dictionary/batch.schema.json from lingvo_dict/contract.py."""

import sys

from lingvo_dict.schema_file import SCHEMA_FILE, render_schema

if __name__ == "__main__":
    SCHEMA_FILE.write_text(render_schema(), encoding="utf-8")
    print(f"wrote {SCHEMA_FILE}")
    sys.exit(0)
