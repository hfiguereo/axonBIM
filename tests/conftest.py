# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Fixtures y configuracion compartida de pytest.

Convenciones:
- ``tests/unit/`` son puros (sin I/O, sin subprocesos).
- ``tests/integration/`` pueden arrancar el servidor RPC como subproceso.
- ``tests/fixtures/`` almacena archivos de datos (IFC, DXF, SQL).
"""

from __future__ import annotations

from collections.abc import Iterator
from pathlib import Path

import pytest

from axonbim.history import sqlite_store as history_store

TESTS_DIR = Path(__file__).resolve().parent
FIXTURES_DIR = TESTS_DIR / "fixtures"


@pytest.fixture(scope="session")
def fixtures_dir() -> Path:
    """Directorio con archivos de prueba (IFC, DXF, etc.)."""
    return FIXTURES_DIR


@pytest.fixture(autouse=True)
def isolated_history_db(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Iterator[None]:
    """Usa una base SQLite temporal para la pila de deshacer en cada test."""
    history_store.close_for_tests()
    monkeypatch.setenv("AXONBIM_HISTORY_DB", str(tmp_path / "history.db"))
    yield
    history_store.close_for_tests()
