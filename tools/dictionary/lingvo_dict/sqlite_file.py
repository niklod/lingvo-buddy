"""Shared helpers of the SQLite builds: the bundled dictionary and the extended dictionary."""

from __future__ import annotations

import sqlite3
from collections.abc import Iterator, Sequence
from contextlib import closing, contextmanager
from pathlib import Path


def sql_in_list(values: Sequence[str]) -> str:
    """The values of a CHECK (column IN (...)) clause; they are our own constants, never user input."""
    return ", ".join(f"'{value}'" for value in values)


@contextmanager
def atomic_database(out: Path) -> Iterator[sqlite3.Connection]:
    """Yields a connection inside one transaction and moves the finished file to `out`.

    The build writes a temporary file first so a failed build never leaves a half-written dictionary.
    """
    out.parent.mkdir(parents=True, exist_ok=True)
    temporary = out.with_name(out.name + ".tmp")
    temporary.unlink(missing_ok=True)
    try:
        with closing(sqlite3.connect(temporary)) as connection:
            with connection:
                yield connection
            # The app opens the file read-only inside its signed bundle, where SQLite
            # cannot create -wal/-shm files, so the file must stay in rollback-journal mode.
            connection.execute("PRAGMA journal_mode=DELETE")
            connection.execute("VACUUM")
        temporary.replace(out)
    except BaseException:
        temporary.unlink(missing_ok=True)
        raise
