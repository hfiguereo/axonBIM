# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Reconstrucción de ``WallSpec`` y malla analítica desde ``IfcWall`` existentes.

Soporta muros creados por AxonBIM (extrusión vertical, perfil rectangular en
planta). Si la geometría no encaja en ese patrón, el muro se omite (retorna
``None``) en lugar de inventar parámetros.
"""

from __future__ import annotations

import logging
import math
from typing import Any, cast

import ifcopenshell
import ifcopenshell.util.placement as placement_util
import ifcopenshell.util.unit as unit_util
import numpy as np

from axonbim.geometry.meshing import Mesh, wall_box_mesh
from axonbim.geometry.topology import Vec3
from axonbim.geometry.wall_spec import WallSpec

_log = logging.getLogger(__name__)

_EXTRUSION_DIR_DOT_MIN: float = 0.99
_MIN_LENGTH_M: float = 1e-4
_EPS_CMP: float = 1e-9
_HEURISTIC_SI_TOO_SMALL_M: float = 0.01
_MIN_RAW_ASSUME_METRES: float = 0.005
_MIN_LOOP_VERTICES: int = 3
_MIN_COORD_COMPONENTS: int = 2
_EXTRUSION_DIR_COMPONENTS: int = 3
_VEC_NORM_EPS: float = 1e-12
_PLACEMENT_UX_EPS: float = 1e-9
_MIN_THICKNESS_FACTOR: float = 0.5


def _to_metres_length(value: float, unit_scale: float) -> float:
    """Convierte una longitud IFC del proyecto a metros.

    Algunos archivos AxonBIM guardan perfiles en metros aunque el proyecto
    declare ``MILLI_METRE`` para coordenadas de colocación; si el valor en SI
    quedaría ridículamente pequeño pero el número bruto parece una cota en metros
    (p. ej. grosor 0,2 con proyecto en mm), se devuelve ``raw`` tal cual.
    """
    raw = float(value)
    si = raw * float(unit_scale)
    if si + _EPS_CMP < _HEURISTIC_SI_TOO_SMALL_M and abs(raw) >= _MIN_RAW_ASSUME_METRES:
        return raw
    return si


def _first_body_extrusion(wall: Any) -> Any | None:
    """Devuelve el primer ``IfcExtrudedAreaSolid`` de la representación Body."""
    rep = getattr(wall, "Representation", None)
    if rep is None:
        return None
    for r in rep.Representations or []:
        if getattr(r, "RepresentationIdentifier", None) != "Body":
            continue
        for item in r.Items or []:
            if item.is_a("IfcExtrudedAreaSolid"):
                return item
    return None


def _profile_xy_loop(swept_area: Any) -> list[tuple[float, float]] | None:
    """Extrae un polígono 2D del perfil (solo casos soportados)."""
    if swept_area.is_a("IfcRectangleProfileDef"):
        xdim = float(swept_area.XDim)
        ydim = float(swept_area.YDim)
        return [(0.0, 0.0), (xdim, 0.0), (xdim, ydim), (0.0, ydim)]
    if swept_area.is_a("IfcArbitraryClosedProfileDef"):
        curve = swept_area.OuterCurve
        if curve.is_a("IfcIndexedPolyCurve"):
            pts = curve.Points
            if pts.is_a("IfcCartesianPointList2D"):
                raw = pts.CoordList
                rows = getattr(raw, "CoordList", raw)
                out: list[tuple[float, float]] = []
                for row in rows:
                    if isinstance(row, (list, tuple)) and len(row) >= _MIN_COORD_COMPONENTS:
                        out.append((float(row[0]), float(row[1])))
                return out if len(out) >= _MIN_LOOP_VERTICES else None
    return None


def _loop_length_thickness_m(
    loop_xy: list[tuple[float, float]],
    unit_scale: float,
) -> tuple[float, float] | None:
    """Obtiene largo y grosor en metros a partir de un rectángulo en planta."""
    n = len(loop_xy)
    if n < _MIN_LOOP_VERTICES:
        return None
    pts = [
        (
            _to_metres_length(x, unit_scale),
            _to_metres_length(y, unit_scale),
        )
        for x, y in loop_xy
    ]
    lengths: list[float] = []
    for i in range(n):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % n]
        lengths.append(math.hypot(x2 - x1, y2 - y1))
    if not lengths:
        return None
    lo = min(lengths)
    hi = max(lengths)
    if hi < _MIN_LENGTH_M or lo < _MIN_LENGTH_M * _MIN_THICKNESS_FACTOR:
        return None
    return hi, lo


def _extrusion_local_z(solid: Any) -> np.ndarray | None:
    """Vector unitario de extrusión en coordenadas locales del producto."""
    ed = getattr(solid, "ExtrudedDirection", None)
    if ed is None:
        return None
    dr = getattr(ed, "DirectionRatios", None)
    if dr is None or len(dr) < _EXTRUSION_DIR_COMPONENTS:
        return None
    v = np.array([float(dr[0]), float(dr[1]), float(dr[2])], dtype=float)
    nrm = np.linalg.norm(v)
    if nrm < _VEC_NORM_EPS:
        return None
    return cast(np.ndarray, v / nrm)


def wall_spec_mesh_from_ifc_wall(  # noqa: PLR0911
    ifc_file: ifcopenshell.file,
    wall: Any,
) -> tuple[WallSpec, Mesh] | None:
    """Intenta deducir ``WallSpec`` y la malla caja equivalente a un ``IfcWall``.

    Args:
        ifc_file: Archivo IFC que contiene ``wall``.
        wall: Instancia ``IfcWall``.

    Returns:
        ``(WallSpec, Mesh)`` si la geometría es compatible; ``None`` si no se
        puede interpretar de forma fiable.
    """
    solid = _first_body_extrusion(wall)
    if solid is None:
        return None
    swept = solid.SweptArea
    if swept is None:
        return None
    loop = _profile_xy_loop(swept)
    if loop is None:
        return None
    unit_scale = float(unit_util.calculate_unit_scale(ifc_file))
    lt = _loop_length_thickness_m(loop, unit_scale)
    if lt is None:
        return None
    length_m, thickness_m = lt

    depth_raw = float(solid.Depth)
    height_m = _to_metres_length(depth_raw, unit_scale)
    if height_m < _MIN_LENGTH_M:
        return None

    loc_z = _extrusion_local_z(solid)
    if loc_z is None:
        return None
    world_z = np.array([0.0, 0.0, 1.0], dtype=float)
    if float(np.dot(loc_z, world_z)) < _EXTRUSION_DIR_DOT_MIN:
        return None

    m_w = placement_util.get_local_placement(wall.ObjectPlacement).astype(float)
    m_w[:3, 3] *= unit_scale

    ux = m_w[:3, 0].astype(float)
    u_len = float(np.linalg.norm(ux))
    if u_len < _PLACEMENT_UX_EPS:
        return None
    ux = ux / u_len

    tvec = m_w[:3, 3]
    p1: Vec3 = (float(tvec[0]), float(tvec[1]), float(tvec[2]))
    p2: Vec3 = (
        float(tvec[0] + ux[0] * length_m),
        float(tvec[1] + ux[1] * length_m),
        float(tvec[2] + ux[2] * length_m),
    )

    spec = WallSpec(p1=p1, p2=p2, height=height_m, thickness=thickness_m)
    mesh = wall_box_mesh(p1, p2, height_m, thickness_m)
    return spec, mesh
