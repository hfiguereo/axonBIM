# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Extrusion analitica de una cara de muro caja (Fase 2, previo a booleanas B-Rep)."""

from __future__ import annotations

import math
from typing import Final

from axonbim.geometry.meshing import Mesh, wall_box_mesh, wall_mesh_for_spec
from axonbim.geometry.topology import Vec3
from axonbim.geometry.wall_spec import WallSpec

_MIN_DIM: Final[float] = 1e-4
# Indices de cara logica para ``wall_box_mesh`` (6 caras, 0..5).
_MAX_BOX_FACE_INDEX: Final[int] = 5
_FACE_END_P2: Final[int] = 4
_FACE_END_P1: Final[int] = 5


def face_index_for_topo_id(mesh: Mesh, topo_id: str) -> int:
    """Indice de cara lógica 0..5 (orden ``wall_box_mesh``) o ``-1``."""
    for tri_i, tid in enumerate(mesh.topo_ids):
        if tid != topo_id:
            continue
        if mesh.tri_logical_face and tri_i < len(mesh.tri_logical_face):
            return mesh.tri_logical_face[tri_i]
        return tri_i // 2
    return -1


def _wall_frame(spec: WallSpec) -> tuple[float, float, float, float, float, float, float]:
    """Retorna ``ux, uy, nx, ny, length, z0, z1_top``."""
    x1, y1, z1 = spec.p1
    x2, y2, z2 = spec.p2
    dx, dy = x2 - x1, y2 - y1
    length = math.hypot(dx, dy)
    if length < _MIN_DIM:
        return 1.0, 0.0, 0.0, 1.0, length, min(z1, z2), min(z1, z2) + spec.height
    ux, uy = dx / length, dy / length
    nx, ny = -uy, ux
    z0 = min(z1, z2)
    z1_top = z0 + spec.height
    return ux, uy, nx, ny, length, z0, z1_top


def outward_normals(spec: WallSpec) -> list[Vec3]:
    """Normales exteriores por cara (orden identico a ``wall_box_mesh``)."""
    ux, uy, nx, ny, _length, _z0, _z1 = _wall_frame(spec)
    return [
        (0.0, 0.0, -1.0),
        (0.0, 0.0, 1.0),
        (nx, ny, 0.0),
        (-nx, -ny, 0.0),
        (ux, uy, 0.0),
        (-ux, -uy, 0.0),
    ]


def face_topo_id_table(spec: WallSpec, *, parent_guid: str) -> list[str]:
    """Un ``topo_id`` por cara lógica (orden ``wall_box_mesh``).

    Args:
        spec: Especificación del muro en el instante considerado.
        parent_guid: GUID IFC del muro; debe coincidir con ``wall_mesh_for_spec``.
    """
    mesh = wall_box_mesh(
        spec.p1,
        spec.p2,
        spec.height,
        spec.thickness,
        parent_guid=parent_guid,
    )
    return [mesh.topo_ids[i * 2] for i in range(6)]


def apply_extrusion(spec: WallSpec, face_index: int, distance_m: float) -> WallSpec:
    """Aplica extrusion de ``distance_m`` a lo largo de la normal exterior de la cara.

    Raises:
        ValueError: si dimensiones resultantes serian invalidas.
    """
    if face_index < 0 or face_index > _MAX_BOX_FACE_INDEX:
        raise ValueError(f"cara invalida: {face_index}")
    if abs(distance_m) < _MIN_DIM:
        return spec

    ux, uy, _nx, _ny, _length, z0, _z1 = _wall_frame(spec)
    p1 = list(spec.p1)
    p2 = list(spec.p2)
    h = spec.height
    t = spec.thickness

    if face_index == 0:
        z0 -= distance_m
        h += distance_m
        p1[2] = z0
        p2[2] = z0
    elif face_index == 1:
        h += distance_m
    elif face_index in (2, 3):
        t += 2.0 * distance_m
    elif face_index == _FACE_END_P2:
        p2[0] += distance_m * ux
        p2[1] += distance_m * uy
    elif face_index == _FACE_END_P1:
        p1[0] -= distance_m * ux
        p1[1] -= distance_m * uy

    if h < _MIN_DIM or t < _MIN_DIM:
        raise ValueError("altura o grosor quedarian por debajo del minimo")
    new_len = math.hypot(p2[0] - p1[0], p2[1] - p1[1])
    if new_len < _MIN_DIM:
        raise ValueError("longitud del muro invalida tras extrusion")

    return WallSpec(
        p1=(float(p1[0]), float(p1[1]), float(p1[2])),
        p2=(float(p2[0]), float(p2[1]), float(p2[2])),
        height=float(h),
        thickness=float(t),
        openings=(),
    )


def extrude_wall_face(
    spec: WallSpec,
    mesh: Mesh,
    topo_id: str,
    vector: Vec3,
    *,
    parent_guid: str,
) -> tuple[WallSpec, Mesh, dict[str, str]]:
    """Calcula nueva especificacion y malla; ``topo_map`` por cara logica.

    Tras extruir, los huecos previos se descartan (la caja cambia de forma global).
    """
    fi = face_index_for_topo_id(mesh, topo_id)
    if fi < 0:
        raise ValueError(f"topo_id no pertenece a la malla: {topo_id!r}")
    normals = outward_normals(spec)
    nx, ny, nz = normals[fi]
    d = vector[0] * nx + vector[1] * ny + vector[2] * nz
    old_table = face_topo_id_table(spec, parent_guid=parent_guid)
    new_base = apply_extrusion(spec, fi, d)
    new_spec = WallSpec(
        p1=new_base.p1,
        p2=new_base.p2,
        height=new_base.height,
        thickness=new_base.thickness,
        openings=(),
    )
    new_mesh = wall_mesh_for_spec(new_spec, parent_guid=parent_guid)
    new_table = face_topo_id_table(new_spec, parent_guid=parent_guid)
    topo_map: dict[str, str] = {}
    for old_id, new_id in zip(old_table, new_table, strict=True):
        if old_id != new_id:
            topo_map[old_id] = new_id
    return new_spec, new_mesh, topo_map
