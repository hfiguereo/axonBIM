# © 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Export DXF mínimo de proyecciones de muros (ezdxf). Fase 3-4: base para planos."""

from __future__ import annotations

from pathlib import Path

import ezdxf
from ezdxf.lldxf import const as ezdxf_const


def write_wall_projection_dxf(
    path: Path,
    view: str,
    lines_world: list[tuple[float, float, float, float]],
) -> None:
    """Escribe segmentos 2D proyectados en el espacio modelo DXF (metros).

    Args:
        path: Ruta absoluta ``.dxf``.
        view: ``top`` → XY; ``front`` → XZ; ``right`` → YZ.
        lines_world: Cada tupla ``(u1, v1, u2, v2)`` en metros del plano proyectado.
    """
    # Los stubs de ezdxf no exponen ``new``; existe en runtime.
    doc = ezdxf.new("R2010", setup=True)  # type: ignore[attr-defined]
    msp = doc.modelspace()
    try:
        doc.layers.get("WALLS")
    except ezdxf_const.DXFTableEntryError:
        doc.layers.add("WALLS", color=7)
    for u1, v1, u2, v2 in lines_world:
        if view == "top":
            msp.add_line((u1, v1, 0.0), (u2, v2, 0.0), dxfattribs={"layer": "WALLS"})
        elif view == "front":
            msp.add_line((u1, 0.0, v1), (u2, 0.0, v2), dxfattribs={"layer": "WALLS"})
        else:
            msp.add_line((0.0, u1, v1), (0.0, u2, v2), dxfattribs={"layer": "WALLS"})
    doc.saveas(str(path))
