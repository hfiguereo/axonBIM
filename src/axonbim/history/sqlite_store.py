# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Cola de deshacer en SQLite (Fase 2): operaciones mutantes reversibles."""

from __future__ import annotations

import json
import os
import sqlite3
import threading
import time
from pathlib import Path
from typing import Any

_LOCK = threading.Lock()
_CONN: sqlite3.Connection | None = None


def _db_path() -> Path:
    override = os.environ.get("AXONBIM_HISTORY_DB")
    if override:
        p = Path(override)
        p.parent.mkdir(parents=True, exist_ok=True)
        return p
    base = os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local" / "share"))
    root = Path(base) / "axonbim"
    root.mkdir(parents=True, exist_ok=True)
    return root / "session_history.db"


def _conn() -> sqlite3.Connection:
    global _CONN  # noqa: PLW0603
    with _LOCK:
        if _CONN is None:
            path = _db_path()
            _CONN = sqlite3.connect(str(path), check_same_thread=False)
            _CONN.execute(
                """
                CREATE TABLE IF NOT EXISTS undo_stack (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    op_kind TEXT NOT NULL,
                    payload_json TEXT NOT NULL,
                    created_at REAL NOT NULL
                )
                """
            )
            _CONN.commit()
        return _CONN


def clear() -> None:
    """Vacía la pila (p. ej. al resetear sesion)."""
    c = _conn()
    with _LOCK:
        c.execute("DELETE FROM undo_stack")
        c.commit()


def push(kind: str, payload: dict[str, Any]) -> None:
    """Apila una operacion reversible."""
    c = _conn()
    with _LOCK:
        c.execute(
            "INSERT INTO undo_stack (op_kind, payload_json, created_at) VALUES (?, ?, ?)",
            (kind, json.dumps(payload, separators=(",", ":")), time.time()),
        )
        c.commit()


def pop_undo() -> tuple[str, dict[str, Any]] | None:
    """Extrae la ultima entrada LIFO. Devuelve ``(kind, payload)`` o ``None``."""
    c = _conn()
    with _LOCK:
        cur = c.execute("SELECT id, op_kind, payload_json FROM undo_stack ORDER BY id DESC LIMIT 1")
        row = cur.fetchone()
        if row is None:
            return None
        row_id, kind, raw = row
        c.execute("DELETE FROM undo_stack WHERE id = ?", (row_id,))
        c.commit()
        return kind, json.loads(raw)


def close_for_tests() -> None:
    """Cierra conexion (solo tests)."""
    global _CONN  # noqa: PLW0603
    with _LOCK:
        if _CONN is not None:
            _CONN.close()
            _CONN = None
