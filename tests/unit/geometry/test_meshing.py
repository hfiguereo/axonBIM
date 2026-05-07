# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Tests de la mesh analitica del muro."""

from __future__ import annotations

import math

import pytest

from axonbim.geometry.meshing import Mesh, wall_box_mesh


def test_mesh_dimensions_for_simple_wall() -> None:
    mesh = wall_box_mesh((0.0, 0.0, 0.0), (4.0, 0.0, 0.0), height=3.0, thickness=0.2)
    assert mesh.vertex_count == 24
    assert mesh.triangle_count == 12
    assert len(mesh.normals) == len(mesh.vertices)
    assert len(mesh.topo_ids) == mesh.triangle_count


def test_topo_ids_repeat_per_face_pair() -> None:
    mesh = wall_box_mesh((0.0, 0.0, 0.0), (4.0, 0.0, 0.0), height=3.0, thickness=0.2)
    unique_topo_ids = set(mesh.topo_ids)
    assert len(unique_topo_ids) == 6


def test_each_face_triangle_pair_shares_topo_id() -> None:
    mesh = wall_box_mesh((0.0, 0.0, 0.0), (4.0, 0.0, 0.0), height=3.0, thickness=0.2)
    for i in range(0, mesh.triangle_count, 2):
        assert mesh.topo_ids[i] == mesh.topo_ids[i + 1]


def test_normals_are_unit_length() -> None:
    mesh = wall_box_mesh((0.0, 0.0, 0.0), (3.0, 4.0, 0.0), height=2.5, thickness=0.3)
    for i in range(0, len(mesh.normals), 3):
        nx, ny, nz = mesh.normals[i : i + 3]
        length = math.sqrt(nx * nx + ny * ny + nz * nz)
        assert abs(length - 1.0) < 1e-9


def test_mesh_to_dict_has_expected_keys() -> None:
    mesh = Mesh(
        vertices=[1.0],
        indices=[0],
        normals=[0.0],
        topo_ids=["x"],
        tri_logical_face=[0],
    )
    data = mesh.to_dict()
    assert set(data.keys()) == {
        "vertices",
        "indices",
        "normals",
        "topo_ids",
        "tri_logical_face",
    }
    assert data["indices"] == [0]


def test_rejects_zero_height() -> None:
    with pytest.raises(ValueError, match="height"):
        wall_box_mesh((0.0, 0.0, 0.0), (1.0, 0.0, 0.0), height=0.0, thickness=0.2)


def test_rejects_zero_thickness() -> None:
    with pytest.raises(ValueError, match="thickness"):
        wall_box_mesh((0.0, 0.0, 0.0), (1.0, 0.0, 0.0), height=3.0, thickness=0.0)


def test_rejects_coincident_points() -> None:
    with pytest.raises(ValueError, match="coincidentes"):
        wall_box_mesh((1.0, 2.0, 0.0), (1.0, 2.0, 0.0), height=3.0, thickness=0.2)


def test_volume_matches_dimensions() -> None:
    length = 4.0
    height = 3.0
    thickness = 0.2
    mesh = wall_box_mesh((0.0, 0.0, 0.0), (length, 0.0, 0.0), height, thickness)
    xs = mesh.vertices[0::3]
    ys = mesh.vertices[1::3]
    zs = mesh.vertices[2::3]
    dx = max(xs) - min(xs)
    dy = max(ys) - min(ys)
    dz = max(zs) - min(zs)
    assert abs(dx - length) < 1e-9
    assert abs(dy - thickness) < 1e-9
    assert abs(dz - height) < 1e-9
