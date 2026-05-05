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
            _ensure_stack_table(_CONN, "undo_stack")
            _ensure_stack_table(_CONN, "redo_stack")
            _CONN.commit()
        return _CONN


def _ensure_stack_table(conn: sqlite3.Connection, table_name: str) -> None:
    conn.execute(
        f"""
        CREATE TABLE IF NOT EXISTS {table_name} (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            op_kind TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            created_at REAL NOT NULL
        )
        """
    )


def clear() -> None:
    """Vacía la pila (p. ej. al resetear sesion)."""
    c = _conn()
    with _LOCK:
        c.execute("DELETE FROM undo_stack")
        c.execute("DELETE FROM redo_stack")
        c.commit()


def push(kind: str, payload: dict[str, Any], *, clear_redo: bool = True) -> None:
    """Apila una operacion reversible."""
    push_undo(kind, payload, clear_redo=clear_redo)


def push_undo(kind: str, payload: dict[str, Any], *, clear_redo: bool) -> None:
    """Apila una operación en undo y opcionalmente invalida redo."""
    c = _conn()
    with _LOCK:
        _push_locked(c, "undo_stack", kind, payload)
        if clear_redo:
            c.execute("DELETE FROM redo_stack")
        c.commit()


def push_redo(kind: str, payload: dict[str, Any]) -> None:
    """Apila una operación deshecha para permitir rehacerla."""
    c = _conn()
    with _LOCK:
        _push_locked(c, "redo_stack", kind, payload)
        c.commit()


def _push_locked(
    conn: sqlite3.Connection,
    table_name: str,
    kind: str,
    payload: dict[str, Any],
) -> None:
    conn.execute(
        f"INSERT INTO {table_name} (op_kind, payload_json, created_at) VALUES (?, ?, ?)",
        (kind, json.dumps(payload, separators=(",", ":")), time.time()),
    )


def pop_undo() -> tuple[str, dict[str, Any]] | None:
    """Extrae la ultima entrada LIFO. Devuelve ``(kind, payload)`` o ``None``."""
    return _pop_stack("undo_stack")


def pop_redo() -> tuple[str, dict[str, Any]] | None:
    """Extrae la ultima entrada de rehacer. Devuelve ``(kind, payload)`` o ``None``."""
    return _pop_stack("redo_stack")


def _pop_stack(table_name: str) -> tuple[str, dict[str, Any]] | None:
    c = _conn()
    with _LOCK:
        cur = c.execute(
            f"SELECT id, op_kind, payload_json FROM {table_name} ORDER BY id DESC LIMIT 1"
        )
        row = cur.fetchone()
        if row is None:
            return None
        row_id, kind, raw = row
        c.execute(f"DELETE FROM {table_name} WHERE id = ?", (row_id,))
        c.commit()
        return kind, json.loads(raw)


def close_for_tests() -> None:
    """Cierra conexion (solo tests)."""
    global _CONN  # noqa: PLW0603
    with _LOCK:
        if _CONN is not None:
            _CONN.close()
            _CONN = None
