# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Regresiones geométricas con snapshots de malla y tolerancia ``1e-6``."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import pytest

from axonbim.geometry.meshing import Mesh, wall_box_mesh
from axonbim.geometry.wall_extrude import extrude_wall_face
from axonbim.geometry.wall_spec import WallSpec


def _mesh_payload(mesh: Mesh) -> dict[str, list[float] | list[int] | list[str]]:
    return mesh.to_dict()


def _load_snapshot(fixtures_dir: Path, name: str) -> dict[str, Any]:
    raw = (fixtures_dir / "geometry" / "snapshots" / name).read_text(encoding="utf-8")
    return json.loads(raw)  # Any: JSON fixture schema is asserted by comparisons below.


def _assert_float_sequence_close(
    actual: list[float], expected: list[float], tolerance: float
) -> None:
    assert len(actual) == len(expected)
    for actual_value, expected_value in zip(actual, expected, strict=True):
        assert actual_value == pytest.approx(expected_value, abs=tolerance)


def _assert_mesh_matches_snapshot(mesh: Mesh, snapshot: dict[str, Any]) -> None:
    payload = _mesh_payload(mesh)
    expected = snapshot["mesh"]
    tolerance = float(snapshot["tolerance_m"])
    assert tolerance == pytest.approx(1e-6)
    _assert_float_sequence_close(payload["vertices"], expected["vertices"], tolerance)
    _assert_float_sequence_close(payload["normals"], expected["normals"], tolerance)
    assert payload["indices"] == expected["indices"]
    assert payload["topo_ids"] == expected["topo_ids"]


def test_wall_box_mesh_matches_snapshot(fixtures_dir: Path) -> None:
    mesh = wall_box_mesh((0.0, 0.0, 0.0), (4.0, 0.0, 0.0), height=3.0, thickness=0.2)

    _assert_mesh_matches_snapshot(
        mesh,
        _load_snapshot(fixtures_dir, "wall_box_4m_x_3m_h_0_2m_t.json"),
    )


def test_top_face_extrusion_mesh_matches_snapshot(fixtures_dir: Path) -> None:
    spec = WallSpec(p1=(0.0, 0.0, 0.0), p2=(4.0, 0.0, 0.0), height=3.0, thickness=0.2)
    mesh = wall_box_mesh(spec.p1, spec.p2, spec.height, spec.thickness)
    top_face_topo_id = mesh.topo_ids[2]

    _new_spec, new_mesh, _topo_map = extrude_wall_face(
        spec,
        mesh,
        top_face_topo_id,
        (0.0, 0.0, 0.5),
    )

    _assert_mesh_matches_snapshot(
        new_mesh,
        _load_snapshot(fixtures_dir, "wall_box_top_extruded_0_5m.json"),
    )
