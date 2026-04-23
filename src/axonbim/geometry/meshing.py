# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Representacion de meshes que viajan por RPC hacia Godot.

Sprint 1.4: generacion analitica de cajas (muros).

La estructura ``Mesh`` esta diseñada para ser convertida directamente a
``ArrayMesh`` de Godot:

- ``vertices``: lista plana ``[x0, y0, z0, x1, y1, z1, ...]``
- ``indices``: lista de enteros, 3 por triangulo
- ``normals``: misma cardinalidad que ``vertices``, una normal por vertice
- ``topo_ids``: ID topologico por cara (len == len(indices) / 3 / 2 para cajas
  con 2 triangulos por cara -- se duplica para que lookup por triangulo sea O(1))

En Fase 2 esta funcionalidad se extiende con ``brep_to_mesh(shape)`` usando
``BRepMesh_IncrementalMesh`` de OCP.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import Any

from axonbim.geometry.topology import Vec3, compute_topo_id

_MIN_WALL_LENGTH_M: float = 1e-6


@dataclass(slots=True)
class Mesh:
    """Mesh canonico del proyecto. Compatible con Godot ``ArrayMesh``."""

    vertices: list[float] = field(default_factory=list)
    indices: list[int] = field(default_factory=list)
    normals: list[float] = field(default_factory=list)
    topo_ids: list[str] = field(default_factory=list)

    @property
    def vertex_count(self) -> int:
        """Numero de vertices (``len(vertices) / 3``)."""
        return len(self.vertices) // 3

    @property
    def triangle_count(self) -> int:
        """Numero de triangulos (``len(indices) / 3``)."""
        return len(self.indices) // 3

    def to_dict(self) -> dict[str, Any]:
        """Serializa en un dict JSON-friendly para RPC."""
        return {
            "vertices": list(self.vertices),
            "indices": list(self.indices),
            "normals": list(self.normals),
            "topo_ids": list(self.topo_ids),
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> Mesh:
        """Deserializa desde RPC o historial SQLite."""
        return cls(
            vertices=[float(x) for x in data.get("vertices", [])],
            indices=[int(x) for x in data.get("indices", [])],
            normals=[float(x) for x in data.get("normals", [])],
            topo_ids=[str(x) for x in data.get("topo_ids", [])],
        )


def wall_box_mesh(
    p1: Vec3,
    p2: Vec3,
    height: float,
    thickness: float,
) -> Mesh:
    """Genera la mesh de un muro recto entre ``p1`` y ``p2``.

    Convencion:
    - El muro va del punto ``p1`` al ``p2`` en planta (plano XY, Z=altura).
    - El grosor se extiende simetricamente a ambos lados del eje p1-p2.
    - La altura se extrude en +Z a partir de ``z = min(p1.z, p2.z)``.

    Raises:
        ValueError: si ``height <= 0``, ``thickness <= 0`` o ``|p2 - p1| < epsilon``.
    """
    _validate_wall_dimensions(p1, p2, height, thickness)

    x1, y1, z1 = p1
    x2, y2, z2 = p2
    dx = x2 - x1
    dy = y2 - y1
    length = math.hypot(dx, dy)

    ux, uy = dx / length, dy / length
    nx, ny = -uy, ux
    offset = thickness / 2.0
    z0 = min(z1, z2)
    z1_top = z0 + height

    corner_a = (x1 + nx * offset, y1 + ny * offset)
    corner_b = (x1 - nx * offset, y1 - ny * offset)
    corner_c = (x2 - nx * offset, y2 - ny * offset)
    corner_d = (x2 + nx * offset, y2 + ny * offset)

    bottom = [(*corner_a, z0), (*corner_b, z0), (*corner_c, z0), (*corner_d, z0)]
    top = [(*corner_a, z1_top), (*corner_b, z1_top), (*corner_c, z1_top), (*corner_d, z1_top)]

    faces: list[tuple[Vec3, Vec3, Vec3, Vec3, Vec3]] = [
        (bottom[0], bottom[1], bottom[2], bottom[3], (0.0, 0.0, -1.0)),
        (top[3], top[2], top[1], top[0], (0.0, 0.0, 1.0)),
        (bottom[0], bottom[3], top[3], top[0], (nx, ny, 0.0)),
        (bottom[2], bottom[1], top[1], top[2], (-nx, -ny, 0.0)),
        (bottom[3], bottom[2], top[2], top[3], (ux, uy, 0.0)),
        (bottom[1], bottom[0], top[0], top[1], (-ux, -uy, 0.0)),
    ]

    mesh = Mesh()
    for v0, v1, v2, v3, normal in faces:
        _append_quad(mesh, v0, v1, v2, v3, normal)
    return mesh


def _append_quad(
    mesh: Mesh,
    v0: Vec3,
    v1: Vec3,
    v2: Vec3,
    v3: Vec3,
    normal: Vec3,
) -> None:
    base_index = mesh.vertex_count
    for v in (v0, v1, v2, v3):
        mesh.vertices.extend(v)
        mesh.normals.extend(normal)
    mesh.indices.extend(
        [
            base_index,
            base_index + 1,
            base_index + 2,
            base_index,
            base_index + 2,
            base_index + 3,
        ]
    )

    centroid: Vec3 = (
        (v0[0] + v1[0] + v2[0] + v3[0]) / 4.0,
        (v0[1] + v1[1] + v2[1] + v3[1]) / 4.0,
        (v0[2] + v1[2] + v2[2] + v3[2]) / 4.0,
    )
    area = _quad_area(v0, v1, v2, v3)
    topo_id = compute_topo_id(centroid, area, normal)
    mesh.topo_ids.extend([topo_id, topo_id])


def _quad_area(v0: Vec3, v1: Vec3, v2: Vec3, v3: Vec3) -> float:
    return _triangle_area(v0, v1, v2) + _triangle_area(v0, v2, v3)


def _triangle_area(a: Vec3, b: Vec3, c: Vec3) -> float:
    abx, aby, abz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
    acx, acy, acz = c[0] - a[0], c[1] - a[1], c[2] - a[2]
    cx = aby * acz - abz * acy
    cy = abz * acx - abx * acz
    cz = abx * acy - aby * acx
    return 0.5 * math.sqrt(cx * cx + cy * cy + cz * cz)


def _validate_wall_dimensions(p1: Vec3, p2: Vec3, height: float, thickness: float) -> None:
    if height <= 0.0:
        raise ValueError(f"Wall height debe ser > 0, recibi {height}")
    if thickness <= 0.0:
        raise ValueError(f"Wall thickness debe ser > 0, recibi {thickness}")
    length = math.hypot(p2[0] - p1[0], p2[1] - p1[1])
    if length < _MIN_WALL_LENGTH_M:
        raise ValueError(
            f"Longitud del muro |p2-p1| < {_MIN_WALL_LENGTH_M} (puntos coincidentes): {p1}, {p2}"
        )
