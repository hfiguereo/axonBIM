# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Tests de la extrusión analítica de muros caja."""

from __future__ import annotations

import pytest

from axonbim.geometry.meshing import Mesh, wall_box_mesh
from axonbim.geometry.wall_extrude import apply_extrusion, extrude_wall_face
from axonbim.geometry.wall_spec import WallSpec


def _face_topo_id(mesh: Mesh, face_index: int) -> str:
    return mesh.topo_ids[face_index * 2]


def test_top_face_extrusion_increases_wall_height() -> None:
    spec = WallSpec(p1=(0.0, 0.0, 0.0), p2=(4.0, 0.0, 0.0), height=3.0, thickness=0.2)
    mesh = wall_box_mesh(spec.p1, spec.p2, spec.height, spec.thickness)
    topo_id = _face_topo_id(mesh, 1)

    new_spec, new_mesh, topo_map = extrude_wall_face(spec, mesh, topo_id, (0.0, 0.0, 0.5))

    assert new_spec.height == pytest.approx(3.5)
    assert new_spec.p1 == spec.p1
    assert new_spec.p2 == spec.p2
    assert max(new_mesh.vertices[2::3]) == pytest.approx(3.5)
    assert topo_map[topo_id] == _face_topo_id(new_mesh, 1)


def test_side_face_extrusion_updates_wall_thickness_symmetrically() -> None:
    spec = WallSpec(p1=(0.0, 0.0, 0.0), p2=(4.0, 0.0, 0.0), height=3.0, thickness=0.2)
    mesh = wall_box_mesh(spec.p1, spec.p2, spec.height, spec.thickness)
    positive_y_face = _face_topo_id(mesh, 2)

    new_spec, new_mesh, topo_map = extrude_wall_face(
        spec,
        mesh,
        positive_y_face,
        (0.0, 0.05, 0.0),
    )

    assert new_spec.thickness == pytest.approx(0.3)
    assert max(new_mesh.vertices[1::3]) - min(new_mesh.vertices[1::3]) == pytest.approx(0.3)
    assert topo_map[positive_y_face] == _face_topo_id(new_mesh, 2)


def test_end_face_extrusion_extends_wall_axis() -> None:
    spec = WallSpec(p1=(0.0, 0.0, 0.0), p2=(4.0, 0.0, 0.0), height=3.0, thickness=0.2)
    mesh = wall_box_mesh(spec.p1, spec.p2, spec.height, spec.thickness)
    p2_end_face = _face_topo_id(mesh, 4)

    new_spec, new_mesh, topo_map = extrude_wall_face(spec, mesh, p2_end_face, (1.0, 0.0, 0.0))

    assert new_spec.p1 == spec.p1
    assert new_spec.p2 == pytest.approx((5.0, 0.0, 0.0))
    assert max(new_mesh.vertices[0::3]) == pytest.approx(5.0)
    assert topo_map[p2_end_face] == _face_topo_id(new_mesh, 4)


def test_apply_extrusion_rejects_degenerate_thickness() -> None:
    spec = WallSpec(p1=(0.0, 0.0, 0.0), p2=(4.0, 0.0, 0.0), height=3.0, thickness=0.2)

    with pytest.raises(ValueError, match="altura o grosor"):
        apply_extrusion(spec, face_index=2, distance_m=-0.11)


def test_extrude_wall_face_rejects_unknown_topo_id() -> None:
    spec = WallSpec(p1=(0.0, 0.0, 0.0), p2=(4.0, 0.0, 0.0), height=3.0, thickness=0.2)
    mesh = wall_box_mesh(spec.p1, spec.p2, spec.height, spec.thickness)

    with pytest.raises(ValueError, match="topo_id no pertenece"):
        extrude_wall_face(spec, mesh, "missing-topo-id", (0.0, 0.0, 0.5))
