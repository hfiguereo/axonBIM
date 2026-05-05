# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Tests del puente OCP/B-Rep para geometría de muros."""

from __future__ import annotations

import pytest

from axonbim.geometry.ocp_brep import mesh_shape, wall_box_shape
from axonbim.geometry.wall_spec import WallSpec


def _extent(values: list[float]) -> float:
    return max(values) - min(values)


def test_wall_spec_to_shape_mesh_matches_wall_extents() -> None:
    spec = WallSpec(p1=(0.0, 0.0, 0.0), p2=(4.0, 0.0, 0.0), height=3.0, thickness=0.2)
    shape = wall_box_shape(spec)
    mesh = mesh_shape(shape, parent_guid="wall-001", op_signature="ocp_wall_box:v1")

    assert mesh.vertex_count == 36
    assert mesh.triangle_count == 12
    assert len(set(mesh.topo_ids)) == 6
    assert _extent(mesh.vertices[0::3]) == pytest.approx(4.0, abs=1e-6)
    assert _extent(mesh.vertices[1::3]) == pytest.approx(0.2, abs=1e-6)
    assert _extent(mesh.vertices[2::3]) == pytest.approx(3.0, abs=1e-6)


def test_wall_spec_to_shape_mesh_supports_rotated_wall() -> None:
    spec = WallSpec(p1=(2.0, 3.0, 0.0), p2=(2.0, 7.0, 0.0), height=2.5, thickness=0.4)
    shape = wall_box_shape(spec)
    mesh = mesh_shape(shape, parent_guid="wall-rotated", op_signature="ocp_wall_box:v1")

    assert mesh.triangle_count == 12
    assert _extent(mesh.vertices[0::3]) == pytest.approx(0.4, abs=1e-6)
    assert _extent(mesh.vertices[1::3]) == pytest.approx(4.0, abs=1e-6)
    assert _extent(mesh.vertices[2::3]) == pytest.approx(2.5, abs=1e-6)
