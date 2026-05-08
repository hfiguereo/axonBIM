# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Tests unitarios de handlers ``geom.*``."""

from __future__ import annotations

import pytest

from axonbim.handlers import geom as geom_handlers
from axonbim.handlers import ifc as ifc_handlers
from axonbim.ifc.session import reset_session


@pytest.fixture(autouse=True)
def _fresh_session() -> None:
    reset_session()


async def test_extrude_face_debug_mesh_stats_matches_mesh_payload() -> None:
    """``debug_mesh_stats`` resume la misma malla que ``mesh`` en el resultado."""
    wall = await ifc_handlers.create_wall(
        {
            "p1": {"x": 0.0, "y": 0.0},
            "p2": {"x": 6.0, "y": 0.0},
            "height": 3.0,
            "thickness": 0.2,
        }
    )
    mesh_before = wall["mesh"]
    top_face_topo_id = str(mesh_before["topo_ids"][2])

    out = await geom_handlers.extrude_face(
        {"topo_id": top_face_topo_id, "vector": [0.0, 0.0, 0.5]}
    )
    mesh_after = out["mesh"]
    stats = out["debug_mesh_stats"]

    verts = mesh_after["vertices"]
    indices = mesh_after["indices"]
    topo_ids = mesh_after["topo_ids"]

    assert stats["vertices"] == len(verts) // 3
    assert stats["triangles"] == len(indices) // 3
    assert stats["faces"] == len(set(topo_ids))
