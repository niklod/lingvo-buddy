"""One batch entry after the file-level checks, as the cross-entry checks and the build see it."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class LoadedEntry:
    file: str
    rank: int
    headword: str
    synonym_group: str | None  # None for lookup-tier entries
    data: dict[str, Any]
