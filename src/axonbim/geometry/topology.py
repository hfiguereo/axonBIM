# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""IDs topológicos persistentes sobre una firma geométrica canónica.

Fase 2 empieza con caras de muros caja analíticos, pero el formato del hash ya
incluye tipo de entidad, GUID padre y firma de operación como define
``docs/architecture/topological-naming.md``. Para geometría heredada sin
contexto, los campos opcionales conservan el comportamiento determinista.
"""

from __future__ import annotations

import hashlib
from collections.abc import Sequence

Vec3 = tuple[float, float, float]

_PRECISION: float = 1e-6


def compute_topo_id(
    centroid: Vec3,
    area: float,
    normal: Vec3,
    *,
    entity_type: str = "FACE",
    parent_guid: str = "",
    op_signature: str = "",
) -> str:
    """Devuelve un ``topo_id`` de 16 hex sobre una firma canónica.

    Args:
        centroid: Centroide de la entidad en metros.
        area: Área de la cara en metros cuadrados.
        normal: Normal canónica de la entidad.
        entity_type: Tipo topológico (`FACE`, `EDGE`, `VERTEX`). Por ahora la
            malla analítica de muros usa `FACE`.
        parent_guid: GUID IFC del producto dueño. Vacío para geometría temporal
            sin entidad persistida.
        op_signature: Firma estable de la operación/convención que creó la cara.

    Returns:
        Primeros 16 hex de SHA-1, suficientes como ID de 64 bits para Fase 2.
    """
    if parent_guid and not op_signature:
        raise ValueError("persistent topology requires parent_guid and op_signature")
    canonical = "|".join(
        [
            entity_type.upper(),
            _format_vec(centroid),
            _format_scalar(area),
            _format_vec(normal),
            parent_guid,
            op_signature,
        ]
    )
    return hashlib.sha1(canonical.encode("utf-8"), usedforsecurity=False).hexdigest()[:16]


def _format_vec(v: Sequence[float]) -> str:
    return ",".join(_format_scalar(x) for x in v)


def _format_scalar(x: float) -> str:
    """Redondea a precision canonica y normaliza ``-0`` a ``0``."""
    rounded = round(x / _PRECISION) * _PRECISION
    if rounded == 0.0:
        rounded = 0.0
    return f"{rounded:.9f}"
