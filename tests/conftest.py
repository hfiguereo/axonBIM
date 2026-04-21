# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Fixtures y configuracion compartida de pytest.

Convenciones:
- ``tests/unit/`` son puros (sin I/O, sin subprocesos).
- ``tests/integration/`` pueden arrancar el servidor RPC como subproceso.
- ``tests/fixtures/`` almacena archivos de datos (IFC, DXF, SQL).
"""

from __future__ import annotations

from pathlib import Path

import pytest

TESTS_DIR = Path(__file__).resolve().parent
FIXTURES_DIR = TESTS_DIR / "fixtures"


@pytest.fixture(scope="session")
def fixtures_dir() -> Path:
    """Directorio con archivos de prueba (IFC, DXF, etc.)."""
    return FIXTURES_DIR
