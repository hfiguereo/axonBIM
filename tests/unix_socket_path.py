# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Rutas de socket Unix cortas para tests de integracion."""

from __future__ import annotations

import os
import tempfile
import uuid
from pathlib import Path


def short_unix_socket_path(name: str) -> Path:
    """Devuelve una ruta de socket Unix corta bajo el directorio temporal del SO.

    macOS limita la longitud del path de ``AF_UNIX`` (tipicamente 104 bytes).
    Los ``tmp_path`` de pytest suelen exceder ese limite; usar ``/tmp`` (o
    equivalente vía ``tempfile.gettempdir()``) evita ``OSError: AF_UNIX path too long``.

    Args:
        name: sufijo legible para depuracion (solo caracteres seguros).

    Returns:
        Ruta absoluta unica por proceso e invocacion.
    """
    safe = name.replace("/", "_")
    leaf = f"axonbim-{os.getpid()}-{uuid.uuid4().hex[:12]}-{safe}.sock"
    return Path(tempfile.gettempdir()) / leaf
