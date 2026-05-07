# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Identificadores de capa para entrega 2D (DXF/PDF) — Fase 3.

Incluye la convención **interna AxonBIM** (prefijo lógico de capas) documentada en
``docs/architecture/draw-delivery-layers.md``. Los nombres **CCRD** definitivos
quedan pendientes de extracción operativa (ver ``docs/normativa/mived/ccrd-vol-i.md``
§4.1); no se copian valores normativos literales aquí.

La tupla :data:`DXF_ARCH_LAYER_SPECS` es la fuente única para **registrar** capas
en exports que usen esta convención (p. ej. :mod:`axonbim.drawing.dxf_walls`).
"""

from __future__ import annotations

from typing import Final, TypedDict

#: Proyección analítica de eje de muro (tronco).
DXF_LAYER_WALLS: Final[str] = "WALLS"
#: Ejes de referencia / rejilla (reservado; sin geometría en export mínimo actual).
DXF_LAYER_AXES: Final[str] = "AXON_AXES"
#: Cotas y líneas auxiliares de medición (reservado).
DXF_LAYER_DIM: Final[str] = "AXON_DIM"
#: Texto y rotulación (reservado).
DXF_LAYER_TEXT: Final[str] = "AXON_TEXT"
#: Sombras / recintos (reservado).
DXF_LAYER_HATCH: Final[str] = "AXON_HATCH"
#: Aperturas: huella simbólica (reservado; SH-F3-04+).
DXF_LAYER_OPENINGS: Final[str] = "AXON_OPENINGS"


class DxfLayerSpec(TypedDict):
    """Definición mínima de capa para plantillas DXF (nombre + índice de color AutoCAD)."""

    name: str
    color: int


#: Capas arquitectónicas previstas en el pipeline MIVED (registro en DXF aun sin entidades).
DXF_ARCH_LAYER_SPECS: Final[tuple[DxfLayerSpec, ...]] = (
    {"name": DXF_LAYER_WALLS, "color": 7},
    {"name": DXF_LAYER_AXES, "color": 1},
    {"name": DXF_LAYER_DIM, "color": 3},
    {"name": DXF_LAYER_TEXT, "color": 7},
    {"name": DXF_LAYER_HATCH, "color": 8},
    {"name": DXF_LAYER_OPENINGS, "color": 4},
)


def arch_layer_names() -> tuple[str, ...]:
    """Devuelve los nombres de capa en el orden canónico de entrega arquitectónica.

    Returns:
        Tupla inmutable con identificadores registrados en exports DXF base.
    """
    return tuple(spec["name"] for spec in DXF_ARCH_LAYER_SPECS)
