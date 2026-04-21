# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""IDs topologicos persistentes (hash SHA-1 sobre representacion canonica).

Sprint 1.4 -- **implementacion stub**:

- Hashea (centroide, area, normal) redondeados a 1e-6.
- Suficiente para muros simples (caras ortogonales, sin booleanas).
- Sera reemplazada en Fase 2 (``docs/architecture/topological-naming.md`` §3).

El objetivo del ID es sobrevivir modificaciones no-topologicas: mover el muro,
cambiar su material, re-exportar... NO sobrevive cambios que reconstruyen la
topologia (booleanas, extrusiones nuevas); para eso esta el ``topo_map`` en
las respuestas RPC.
"""

from __future__ import annotations

import hashlib
from collections.abc import Sequence

Vec3 = tuple[float, float, float]

_PRECISION: float = 1e-6


def compute_topo_id(centroid: Vec3, area: float, normal: Vec3) -> str:
    """Devuelve un SHA-1 hex (40 chars) sobre la terna (centroide, area, normal)."""
    canonical = "|".join(
        [
            _format_vec(centroid),
            _format_scalar(area),
            _format_vec(normal),
        ]
    )
    return hashlib.sha1(canonical.encode("utf-8"), usedforsecurity=False).hexdigest()


def _format_vec(v: Sequence[float]) -> str:
    return ",".join(_format_scalar(x) for x in v)


def _format_scalar(x: float) -> str:
    """Redondea a precision canonica y normaliza ``-0`` a ``0``."""
    rounded = round(x / _PRECISION) * _PRECISION
    if rounded == 0.0:
        rounded = 0.0
    return f"{rounded:.9f}"
