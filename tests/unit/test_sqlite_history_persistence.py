# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Comprueba que la pila undo/redo sobrevive al cierre de la conexión SQLite."""

from __future__ import annotations

from axonbim.history import sqlite_store as history_store


def test_undo_stack_survives_connection_close_and_reopen(monkeypatch, tmp_path) -> None:
    """Tras ``close_for_tests`` la misma ruta conserva entradas (simula reinicio de proceso)."""
    db = tmp_path / "persist.db"
    monkeypatch.setenv("AXONBIM_HISTORY_DB", str(db))
    history_store.close_for_tests()

    payload = {"guid": "abc", "wall_spec": {"k": 1}, "mesh": {"v": []}}
    history_store.push_undo("extrude_face", payload, clear_redo=True)
    history_store.close_for_tests()

    popped = history_store.pop_undo()
    assert popped is not None
    kind, data = popped
    assert kind == "extrude_face"
    assert data["guid"] == "abc"
