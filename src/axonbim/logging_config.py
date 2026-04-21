# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Configuracion centralizada de logging del backend.

Usa la variable de entorno ``AXONBIM_LOG_LEVEL`` (default ``INFO``).
``configure`` es idempotente y segura de invocar mas de una vez.
"""

from __future__ import annotations

import logging
import os

_CONFIGURED = False
_DEFAULT_FORMAT = "%(asctime)s %(levelname)-7s %(name)s: %(message)s"
_DEFAULT_DATEFMT = "%H:%M:%S"


def configure(level: str | None = None) -> None:
    """Configura el root logger una sola vez por proceso."""
    global _CONFIGURED  # noqa: PLW0603
    if _CONFIGURED:
        if level is not None:
            logging.getLogger().setLevel(_resolve_level(level))
        return
    logging.basicConfig(
        level=_resolve_level(level),
        format=_DEFAULT_FORMAT,
        datefmt=_DEFAULT_DATEFMT,
    )
    _CONFIGURED = True


def _resolve_level(level: str | None) -> int:
    name = (level or os.environ.get("AXONBIM_LOG_LEVEL", "INFO")).upper()
    numeric = logging.getLevelNamesMapping().get(name)
    return numeric if numeric is not None else logging.INFO
