"""One batch entry after the file-level checks, as the cross-entry checks and the build see it."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict, Optional


@dataclass(frozen=True)
class LoadedEntry:
    file: str
    rank: int
    headword: str
    synonym_group: Optional[str]  # None for lookup-tier entries
    data: Dict[str, Any]
