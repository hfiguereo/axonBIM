# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Control de grabación en la pila de historial (evitar re-entrada al aplicar undo/redo)."""

from __future__ import annotations

from collections.abc import Iterator
from contextlib import contextmanager

_depth: int = 0


@contextmanager
def suppressed() -> Iterator[None]:
    """Anula ``push_undo`` / ``push_redo`` mientras se aplica historial o se compone una operación."""
    global _depth  # noqa: PLW0603
    _depth += 1
    try:
        yield
    finally:
        _depth -= 1


def is_suppressed() -> bool:
    """True si no se deben apilar nuevas entradas de historial."""
    return _depth > 0
