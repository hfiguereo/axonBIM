# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Representacion de meshes que viajan por RPC hacia Godot.

Sprint 1.4: generacion analitica de cajas (muros).

La estructura ``Mesh`` esta diseñada para ser convertida directamente a
``ArrayMesh`` de Godot:

- ``vertices``: lista plana ``[x0, y0, z0, x1, y1, z1, ...]``
- ``indices``: lista de enteros, 3 por triangulo
- ``normals``: misma cardinalidad que ``vertices``, una normal por vertice
- ``topo_ids``: ID topologico por triangulo (un id por triangulo; duplicado
  cuando dos triangulos comparten la misma cara logica)
- ``tri_logical_face``: indice de cara logica 0..5 (muro caja) por triangulo;
  vacio en mallas legacy (se infiere ``i//2`` para mallas de exactamente 12
  triangulos de caja sin huecos)

En Fase 2 esta estructura puede extenderse con triangulación B-Rep cuando entre
un kernel sólido en el tronco; hoy la malla es **analítica** y coincide con Godot.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from itertools import pairwise
from typing import Any

from axonbim.geometry.topology import Vec3, compute_topo_id
from axonbim.geometry.wall_spec import WallSpec

_MIN_WALL_LENGTH_M: float = 1e-6
_OPENING_MARGIN_M: float = 1e-3
_SLAB_MIN_EDGE_M: float = 1e-6
_MIN_SLAB_POLYGON_VERTICES: int = 3
_SLAB_CCW_AREA_EPS: float = 1e-12
_SLAB_TURN_EPS: float = 1e-12


@dataclass(slots=True)
class Mesh:
    """Mesh canonico del proyecto. Compatible con Godot ``ArrayMesh``."""

    vertices: list[float] = field(default_factory=list)
    indices: list[int] = field(default_factory=list)
    normals: list[float] = field(default_factory=list)
    topo_ids: list[str] = field(default_factory=list)
    tri_logical_face: list[int] = field(default_factory=list)

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
            "tri_logical_face": list(self.tri_logical_face),
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> Mesh:
        """Deserializa desde RPC o historial SQLite."""
        raw_faces = data.get("tri_logical_face")
        faces: list[int] = [int(x) for x in raw_faces] if raw_faces is not None else []
        return cls(
            vertices=[float(x) for x in data.get("vertices", [])],
            indices=[int(x) for x in data.get("indices", [])],
            normals=[float(x) for x in data.get("normals", [])],
            topo_ids=[str(x) for x in data.get("topo_ids", [])],
            tri_logical_face=faces,
        )


def wall_mesh_for_spec(spec: WallSpec, *, parent_guid: str) -> Mesh:
    """Malla analítica del muro según ``spec`` (caja o caja con huecos en ±n)."""
    if spec.openings:
        return wall_box_mesh_with_openings(spec, parent_guid=parent_guid)
    return wall_box_mesh(
        spec.p1,
        spec.p2,
        spec.height,
        spec.thickness,
        parent_guid=parent_guid,
    )


def wall_box_mesh(
    p1: Vec3,
    p2: Vec3,
    height: float,
    thickness: float,
    *,
    parent_guid: str = "",
    op_signature: str = "wall_box_mesh",
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

    faces: list[tuple[Vec3, Vec3, Vec3, Vec3, Vec3, int]] = [
        (bottom[0], bottom[1], bottom[2], bottom[3], (0.0, 0.0, -1.0), 0),
        (top[3], top[2], top[1], top[0], (0.0, 0.0, 1.0), 1),
        (bottom[0], bottom[3], top[3], top[0], (nx, ny, 0.0), 2),
        (bottom[2], bottom[1], top[1], top[2], (-nx, -ny, 0.0), 3),
        (bottom[3], bottom[2], top[2], top[3], (ux, uy, 0.0), 4),
        (bottom[1], bottom[0], top[0], top[1], (-ux, -uy, 0.0), 5),
    ]

    mesh = Mesh()
    for face_index, (v0, v1, v2, v3, normal, logical_face) in enumerate(faces):
        _append_quad(
            mesh,
            v0,
            v1,
            v2,
            v3,
            normal,
            parent_guid,
            f"{op_signature}:face:{face_index}",
            logical_face,
        )
    return mesh


def wall_box_mesh_with_openings(spec: WallSpec, *, parent_guid: str) -> Mesh:
    """Malla de muro caja con huecos rectangulares que atraviesan el grosor (caras ±n).

    Raises:
        ValueError: Si los huecos son inválidos o se solapan en el plano (s, z).
    """
    _validate_wall_dimensions(spec.p1, spec.p2, spec.height, spec.thickness)
    holes = _normalized_opening_rects(spec)
    if not holes:
        return wall_box_mesh(
            spec.p1,
            spec.p2,
            spec.height,
            spec.thickness,
            parent_guid=parent_guid,
        )

    p1, p2 = spec.p1, spec.p2
    x1, y1, z1 = p1
    x2, y2, z2 = p2
    dx, dy = x2 - x1, y2 - y1
    length = math.hypot(dx, dy)
    ux, uy = dx / length, dy / length
    nx, ny = -uy, ux
    offset = spec.thickness / 2.0
    z0 = min(z1, z2)
    z1_top = z0 + spec.height

    corner_a = (x1 + nx * offset, y1 + ny * offset)
    corner_b = (x1 - nx * offset, y1 - ny * offset)
    corner_c = (x2 - nx * offset, y2 - ny * offset)
    corner_d = (x2 + nx * offset, y2 + ny * offset)

    bottom = [(*corner_a, z0), (*corner_b, z0), (*corner_c, z0), (*corner_d, z0)]
    top = [(*corner_a, z1_top), (*corner_b, z1_top), (*corner_c, z1_top), (*corner_d, z1_top)]

    mesh = Mesh()
    # Caras 0,1,4,5 — sin huecos
    _append_quad(
        mesh,
        bottom[0],
        bottom[1],
        bottom[2],
        bottom[3],
        (0.0, 0.0, -1.0),
        parent_guid,
        "wall_box_openings:face:0",
        0,
    )
    _append_quad(
        mesh,
        top[3],
        top[2],
        top[1],
        top[0],
        (0.0, 0.0, 1.0),
        parent_guid,
        "wall_box_openings:face:1",
        1,
    )
    # +n (2): v_bl=bottom[0], v_br=bottom[3], v_tr=top[3], v_tl=top[0]
    _append_face_with_holes(
        mesh,
        bottom[0],
        bottom[3],
        top[3],
        top[0],
        (nx, ny, 0.0),
        length,
        z0,
        z1_top,
        holes,
        parent_guid,
        logical_face=2,
        face_tag="pos_n",
    )
    # -n (3): v_bl=bottom[1], v_br=bottom[2], v_tr=top[2], v_tl=top[1]
    _append_face_with_holes(
        mesh,
        bottom[1],
        bottom[2],
        top[2],
        top[1],
        (-nx, -ny, 0.0),
        length,
        z0,
        z1_top,
        holes,
        parent_guid,
        logical_face=3,
        face_tag="neg_n",
    )
    _append_quad(
        mesh,
        bottom[3],
        bottom[2],
        top[2],
        top[3],
        (ux, uy, 0.0),
        parent_guid,
        "wall_box_openings:face:4",
        4,
    )
    _append_quad(
        mesh,
        bottom[1],
        bottom[0],
        top[0],
        top[1],
        (-ux, -uy, 0.0),
        parent_guid,
        "wall_box_openings:face:5",
        5,
    )
    return mesh


def slab_prism_mesh(
    polygon_xy: tuple[tuple[float, float], ...],
    z_top_m: float,
    thickness_m: float,
    *,
    parent_guid: str = "",
    op_signature: str = "slab_prism_mesh",
) -> Mesh:
    """Prisma convexo: cara superior en ``z_top_m``, extrusión hacia ``-Z``.

    Raises:
        ValueError: Si el polígono no es convexo CCW en XY, ``thickness <= 0`` o
            hay menos de 3 vértices.
    """
    if thickness_m <= 0.0:
        raise ValueError(f"slab thickness debe ser > 0, recibí {thickness_m}")
    if len(polygon_xy) < _MIN_SLAB_POLYGON_VERTICES:
        raise ValueError("slab requiere al menos 3 vértices en planta")
    _validate_convex_ccw_polygon(polygon_xy)

    z_bot = z_top_m - thickness_m
    n = len(polygon_xy)
    top_verts: list[Vec3] = [(polygon_xy[i][0], polygon_xy[i][1], z_top_m) for i in range(n)]
    bot_verts: list[Vec3] = [(polygon_xy[i][0], polygon_xy[i][1], z_bot) for i in range(n)]

    mesh = Mesh()
    # Tapa superior (normal +Z)
    for i in range(1, n - 1):
        _append_triangle(
            mesh,
            top_verts[0],
            top_verts[i],
            top_verts[i + 1],
            (0.0, 0.0, 1.0),
            parent_guid,
            f"{op_signature}:top:tri:{i}",
            logical_face=0,
        )
    # Base inferior (normal -Z)
    for i in range(1, n - 1):
        _append_triangle(
            mesh,
            bot_verts[0],
            bot_verts[i + 1],
            bot_verts[i],
            (0.0, 0.0, -1.0),
            parent_guid,
            f"{op_signature}:bot:tri:{i}",
            logical_face=1,
        )
    # Costados (cara 2+i)
    for i in range(n):
        j = (i + 1) % n
        edge = (
            polygon_xy[j][0] - polygon_xy[i][0],
            polygon_xy[j][1] - polygon_xy[i][1],
        )
        elen = math.hypot(edge[0], edge[1])
        if elen < _SLAB_MIN_EDGE_M:
            raise ValueError("arista degenerada en polígono de losa")
        outward = (-edge[1] / elen, edge[0] / elen, 0.0)
        logical_side = 2 + i
        _append_quad(
            mesh,
            bot_verts[i],
            bot_verts[j],
            top_verts[j],
            top_verts[i],
            outward,
            parent_guid,
            f"{op_signature}:side:{i}",
            logical_side,
        )
    return mesh


def _validate_convex_ccw_polygon(poly: tuple[tuple[float, float], ...]) -> None:
    """Comprueba convexidad estricta y orden CCW en XY (giros siempre a la izquierda)."""
    n = len(poly)
    twice_area = 0.0
    for i in range(n):
        x0, y0 = poly[i]
        x1, y1 = poly[(i + 1) % n]
        twice_area += x0 * y1 - x1 * y0
    if twice_area <= _SLAB_CCW_AREA_EPS:
        raise ValueError("polígono de losa: área nula o orientación horaria")
    for i in range(n):
        x0, y0 = poly[i]
        x1, y1 = poly[(i + 1) % n]
        x2, y2 = poly[(i + 2) % n]
        ax, ay = x1 - x0, y1 - y0
        bx, by = x2 - x1, y2 - y1
        c = ax * by - ay * bx
        if c <= _SLAB_TURN_EPS:
            raise ValueError("polígono de losa debe ser estrictamente convexo CCW")


@dataclass(frozen=True, slots=True)
class _SzRect:
    s0: float
    s1: float
    z0: float
    z1: float


def _normalized_opening_rects(spec: WallSpec) -> list[_SzRect]:
    x1, y1, z1_ = spec.p1
    x2, y2, z2_ = spec.p2
    length = math.hypot(x2 - x1, y2 - y1)
    z0 = min(z1_, z2_)
    z1_top = z0 + spec.height
    holes: list[_SzRect] = []
    for op in spec.openings:
        zb = z0 + op.sill_height_m
        zt = zb + op.height_m
        s0 = op.along_start_m
        s1 = s0 + op.width_m
        if s0 < _OPENING_MARGIN_M or s1 > length - _OPENING_MARGIN_M:
            raise ValueError("hueco: rango horizontal fuera del muro")
        if zb < z0 + _OPENING_MARGIN_M or zt > z1_top - _OPENING_MARGIN_M:
            raise ValueError("hueco: rango vertical fuera del muro")
        if s1 <= s0 + _OPENING_MARGIN_M or zt <= zb + _OPENING_MARGIN_M:
            raise ValueError("hueco: dimensiones demasiado pequeñas")
        holes.append(_SzRect(s0=s0, s1=s1, z0=zb, z1=zt))
    for i, a in enumerate(holes):
        for b in holes[i + 1 :]:
            if not (a.s1 <= b.s0 or b.s1 <= a.s0 or a.z1 <= b.z0 or b.z1 <= a.z0):
                raise ValueError("huecos rectangulares no deben solaparse")
    return holes


def _point_on_face(
    v_bl: Vec3,
    v_br: Vec3,
    v_tr: Vec3,
    v_tl: Vec3,
    s: float,
    z: float,
    length: float,
    z0: float,
    z1_top: float,
) -> Vec3:
    h = z1_top - z0
    if h <= 0.0:
        return v_bl
    alpha = s / length
    beta = (z - z0) / h
    bx = v_bl[0] + alpha * (v_br[0] - v_bl[0])
    by = v_bl[1] + alpha * (v_br[1] - v_bl[1])
    tx = v_tl[0] + alpha * (v_tr[0] - v_tl[0])
    ty = v_tl[1] + alpha * (v_tr[1] - v_tl[1])
    return (bx + beta * (tx - bx), by + beta * (ty - by), z)


def _append_face_with_holes(
    mesh: Mesh,
    v_bl: Vec3,
    v_br: Vec3,
    v_tr: Vec3,
    v_tl: Vec3,
    normal: Vec3,
    length: float,
    z0: float,
    z1_top: float,
    holes: list[_SzRect],
    parent_guid: str,
    *,
    logical_face: int,
    face_tag: str,
) -> None:
    z_bounds = sorted({z0, z1_top, *[z for h in holes for z in (h.z0, h.z1)]})
    sub = 0
    for za, zb in pairwise(z_bounds):
        if zb - za < _OPENING_MARGIN_M * 0.5:
            continue
        intervals = _hole_s_intervals_for_band(za, zb, holes)
        free = _subtract_intervals(0.0, length, intervals)
        for s0, s1 in free:
            if s1 - s0 < _OPENING_MARGIN_M * 0.5:
                continue
            p00 = _point_on_face(v_bl, v_br, v_tr, v_tl, s0, za, length, z0, z1_top)
            p10 = _point_on_face(v_bl, v_br, v_tr, v_tl, s1, za, length, z0, z1_top)
            p11 = _point_on_face(v_bl, v_br, v_tr, v_tl, s1, zb, length, z0, z1_top)
            p01 = _point_on_face(v_bl, v_br, v_tr, v_tl, s0, zb, length, z0, z1_top)
            _append_quad(
                mesh,
                p00,
                p10,
                p11,
                p01,
                normal,
                parent_guid,
                f"wall_box_openings:{face_tag}:{sub}",
                logical_face,
            )
            sub += 1


def _hole_s_intervals_for_band(za: float, zb: float, holes: list[_SzRect]) -> list[tuple[float, float]]:
    out: list[tuple[float, float]] = []
    for h in holes:
        z0i = max(za, h.z0)
        z1i = min(zb, h.z1)
        if z1i > z0i + 1e-9:
            out.append((h.s0, h.s1))
    return out


def _subtract_intervals(lo: float, hi: float, blocked: list[tuple[float, float]]) -> list[tuple[float, float]]:
    if not blocked:
        return [(lo, hi)]
    blocked_sorted = sorted(blocked)
    merged: list[tuple[float, float]] = []
    for a, b in blocked_sorted:
        if not merged or a > merged[-1][1]:
            merged.append((a, b))
        else:
            merged[-1] = (merged[-1][0], max(merged[-1][1], b))
    free: list[tuple[float, float]] = []
    cursor = lo
    for a, b in merged:
        if a > cursor:
            free.append((cursor, min(a, hi)))
        cursor = max(cursor, b)
    if cursor < hi:
        free.append((cursor, hi))
    return [(x, y) for x, y in free if y - x > _OPENING_MARGIN_M * 0.5]


def _append_triangle(
    mesh: Mesh,
    a: Vec3,
    b: Vec3,
    c: Vec3,
    normal: Vec3,
    parent_guid: str,
    op_signature: str,
    *,
    logical_face: int,
) -> None:
    base_index = mesh.vertex_count
    for v in (a, b, c):
        mesh.vertices.extend(v)
        mesh.normals.extend(normal)
    mesh.indices.extend([base_index, base_index + 1, base_index + 2])
    mesh.tri_logical_face.append(logical_face)
    centroid: Vec3 = (
        (a[0] + b[0] + c[0]) / 3.0,
        (a[1] + b[1] + c[1]) / 3.0,
        (a[2] + b[2] + c[2]) / 3.0,
    )
    area = _triangle_area(a, b, c)
    topo_id = compute_topo_id(
        centroid,
        area,
        normal,
        entity_type="FACE",
        parent_guid=parent_guid,
        op_signature=op_signature,
    )
    mesh.topo_ids.append(topo_id)


def _append_quad(
    mesh: Mesh,
    v0: Vec3,
    v1: Vec3,
    v2: Vec3,
    v3: Vec3,
    normal: Vec3,
    parent_guid: str,
    op_signature: str,
    logical_face_index: int,
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
    mesh.tri_logical_face.extend([logical_face_index, logical_face_index])

    centroid: Vec3 = (
        (v0[0] + v1[0] + v2[0] + v3[0]) / 4.0,
        (v0[1] + v1[1] + v2[1] + v3[1]) / 4.0,
        (v0[2] + v1[2] + v2[2] + v3[2]) / 4.0,
    )
    area = _quad_area(v0, v1, v2, v3)
    topo_id = compute_topo_id(
        centroid,
        area,
        normal,
        entity_type="FACE",
        parent_guid=parent_guid,
        op_signature=op_signature,
    )
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
