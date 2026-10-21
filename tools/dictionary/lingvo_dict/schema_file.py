"""The committed JSON schema file, rendered from the contract."""

import json
from pathlib import Path

from lingvo_dict.contract import json_schema

SCHEMA_FILE = Path(__file__).resolve().parents[1] / "batch.schema.json"


def render_schema() -> str:
    return json.dumps(json_schema(), ensure_ascii=False, indent=2) + "\n"
