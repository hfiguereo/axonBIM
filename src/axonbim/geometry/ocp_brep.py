# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Wrappers mínimos OCP/OpenCASCADE para sólidos B-Rep de Fase 2."""

from __future__ import annotations

import math
from collections.abc import Iterable

from OCP.BRep import BRep_Tool
from OCP.BRepBuilderAPI import BRepBuilderAPI_Transform
from OCP.BRepMesh import BRepMesh_IncrementalMesh
from OCP.BRepPrimAPI import BRepPrimAPI_MakeBox
from OCP.gp import gp_Pnt, gp_Trsf
from OCP.TopAbs import TopAbs_FACE, TopAbs_REVERSED
from OCP.TopExp import TopExp_Explorer
from OCP.TopLoc import TopLoc_Location
from OCP.TopoDS import TopoDS, TopoDS_Face, TopoDS_Shape

from axonbim.geometry.meshing import Mesh
from axonbim.geometry.topology import Vec3, compute_topo_id
from axonbim.geometry.wall_spec import WallSpec

_DEFAULT_LINEAR_DEFLECTION_M = 0.01
_MIN_WALL_LENGTH_M = 1e-6


def wall_box_shape(spec: WallSpec) -> TopoDS_Shape:
    """Construye un sólido OCP para un muro caja en coordenadas de mundo.

    Args:
        spec: Parámetros del muro analítico en metros.

    Returns:
        ``TopoDS_Shape`` sólido equivalente al ``WallSpec``.

    Raises:
        ValueError: Si la longitud, altura o grosor son degenerados.
    """
    if spec.height <= 0.0 or spec.thickness <= 0.0:
        raise ValueError("altura y grosor deben ser positivos")
    x1, y1, z1 = spec.p1
    x2, y2, z2 = spec.p2
    dx, dy = x2 - x1, y2 - y1
    length = math.hypot(dx, dy)
    if length < _MIN_WALL_LENGTH_M:
        raise ValueError("longitud del muro invalida para OCP")

    ux, uy = dx / length, dy / length
    nx, ny = -uy, ux
    z0 = min(z1, z2)
    half_thickness = spec.thickness / 2.0

    local_box = BRepPrimAPI_MakeBox(
        gp_Pnt(0.0, -half_thickness, 0.0),
        gp_Pnt(length, half_thickness, spec.height),
    ).Shape()
    transform = gp_Trsf()
    transform.SetValues(
        ux,
        nx,
        0.0,
        x1,
        uy,
        ny,
        0.0,
        y1,
        0.0,
        0.0,
        1.0,
        z0,
    )
    return BRepBuilderAPI_Transform(local_box, transform, True).Shape()


def mesh_shape(
    shape: TopoDS_Shape,
    *,
    linear_deflection_m: float = _DEFAULT_LINEAR_DEFLECTION_M,
    parent_guid: str = "",
    op_signature: str = "ocp_shape:v1",
) -> Mesh:
    """Triangula un ``TopoDS_Shape`` OCP y devuelve un ``Mesh`` RPC-friendly.

    Args:
        shape: Sólido/shell/cara OCP a triangular.
        linear_deflection_m: Deflexión lineal para ``BRepMesh_IncrementalMesh`` en metros.
        parent_guid: GUID IFC propietario para el cálculo de ``topo_id``.
        op_signature: Firma estable de la operación que generó el shape.

    Returns:
        ``Mesh`` con vértices, índices, normales y ``topo_ids`` por triángulo.
    """
    BRepMesh_IncrementalMesh(shape, linear_deflection_m)
    mesh = Mesh()
    explorer = TopExp_Explorer(shape, TopAbs_FACE)
    face_index = 0
    while explorer.More():
        face = TopoDS.Face_s(explorer.Current())
        _append_face_triangles(mesh, face, parent_guid, f"{op_signature}:face:{face_index}")
        face_index += 1
        explorer.Next()
    return mesh


def wall_box_mesh_ocp(
    spec: WallSpec,
    *,
    parent_guid: str = "",
    op_signature: str = "wall_box_ocp:v1",
    linear_deflection_m: float = _DEFAULT_LINEAR_DEFLECTION_M,
) -> Mesh:
    """Construye y triangula con OCP un muro caja equivalente al ``WallSpec``."""
    shape = wall_box_shape(spec)
    return mesh_shape(
        shape,
        linear_deflection_m=linear_deflection_m,
        parent_guid=parent_guid,
        op_signature=op_signature,
    )


def _append_face_triangles(
    mesh: Mesh, face: TopoDS_Face, parent_guid: str, op_signature: str
) -> None:
    location = TopLoc_Location()
    triangulation = BRep_Tool.Triangulation_s(face, location)
    if triangulation is None:
        return

    transform = location.Transformation()
    vertices: list[Vec3] = []
    triangles: list[tuple[int, int, int]] = []
    for node_index in range(1, triangulation.NbNodes() + 1):
        point = triangulation.Node(node_index).Transformed(transform)
        vertices.append((float(point.X()), float(point.Y()), float(point.Z())))
    for triangle_index in range(1, triangulation.NbTriangles() + 1):
        a, b, c = triangulation.Triangle(triangle_index).Get()
        if face.Orientation() == TopAbs_REVERSED:
            triangles.append((a - 1, c - 1, b - 1))
        else:
            triangles.append((a - 1, b - 1, c - 1))

    topo_id = _face_topo_id(vertices, triangles, parent_guid, op_signature)
    for a, b, c in triangles:
        v0, v1, v2 = vertices[a], vertices[b], vertices[c]
        normal = _triangle_normal(v0, v1, v2)
        base_index = mesh.vertex_count
        for vertex in (v0, v1, v2):
            mesh.vertices.extend(vertex)
            mesh.normals.extend(normal)
        mesh.indices.extend([base_index, base_index + 1, base_index + 2])
        mesh.topo_ids.append(topo_id)


def _face_topo_id(
    vertices: list[Vec3],
    triangles: Iterable[tuple[int, int, int]],
    parent_guid: str,
    op_signature: str,
) -> str:
    tri_list = list(triangles)
    area_total = 0.0
    weighted_centroid = (0.0, 0.0, 0.0)
    normal = (0.0, 0.0, 1.0)
    for a, b, c in tri_list:
        v0, v1, v2 = vertices[a], vertices[b], vertices[c]
        area = _triangle_area(v0, v1, v2)
        if area <= 0.0:
            continue
        centroid = (
            (v0[0] + v1[0] + v2[0]) / 3.0,
            (v0[1] + v1[1] + v2[1]) / 3.0,
            (v0[2] + v1[2] + v2[2]) / 3.0,
        )
        weighted_centroid = (
            weighted_centroid[0] + centroid[0] * area,
            weighted_centroid[1] + centroid[1] * area,
            weighted_centroid[2] + centroid[2] * area,
        )
        area_total += area
        normal = _triangle_normal(v0, v1, v2)
    if area_total > 0.0:
        weighted_centroid = (
            weighted_centroid[0] / area_total,
            weighted_centroid[1] / area_total,
            weighted_centroid[2] / area_total,
        )
    return compute_topo_id(
        weighted_centroid,
        area_total,
        normal,
        entity_type="FACE",
        parent_guid=parent_guid,
        op_signature=op_signature,
    )


def _triangle_normal(a: Vec3, b: Vec3, c: Vec3) -> Vec3:
    abx, aby, abz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
    acx, acy, acz = c[0] - a[0], c[1] - a[1], c[2] - a[2]
    nx = aby * acz - abz * acy
    ny = abz * acx - abx * acz
    nz = abx * acy - aby * acx
    length = math.sqrt(nx * nx + ny * ny + nz * nz)
    if length <= 0.0:
        return (0.0, 0.0, 1.0)
    return (nx / length, ny / length, nz / length)


def _triangle_area(a: Vec3, b: Vec3, c: Vec3) -> float:
    abx, aby, abz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
    acx, acy, acz = c[0] - a[0], c[1] - a[1], c[2] - a[2]
    cx = aby * acz - abz * acy
    cy = abz * acx - abx * acz
    cz = abx * acy - aby * acx
    return 0.5 * math.sqrt(cx * cx + cy * cy + cz * cz)
