"""Line-oriented data files where '#' starts a comment, also after a value."""

from __future__ import annotations

from typing import Iterator, Tuple


def content_lines(text: str) -> Iterator[Tuple[int, str]]:
    """Yields (1-based line number, text without the comment) for each line that is not blank."""
    for number, raw in enumerate(text.splitlines(), start=1):
        content = raw.split("#", 1)[0].strip()
        if content:
            yield number, content
