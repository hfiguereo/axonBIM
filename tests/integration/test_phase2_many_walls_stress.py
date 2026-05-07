# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Estrés de modelo multi-muro: criterio de salida operativo de la Fase 2 del ROADMAP."""

from __future__ import annotations

import pytest

from axonbim.geometry import topo_registry
from axonbim.geometry.meshing import Mesh
from axonbim.handlers import geom as geom_handlers
from axonbim.handlers import ifc as ifc_handlers
from axonbim.ifc.session import reset_session


def _top_face_topo_id(mesh: Mesh) -> str:
    """Índice de cara superior (1) en convención de malla caja."""
    return str(mesh.topo_ids[1 * 2])


@pytest.fixture(autouse=True)
def _fresh_session() -> None:
    reset_session()


@pytest.mark.asyncio
async def test_fifty_five_walls_extrude_subset_stable() -> None:
    """55 muros + extrusiones dispersas: sesión y registro topológico permanecen coherentes."""
    guids: list[str] = []
    n = 55
    for i in range(n):
        y = float(i) * 0.35
        result = await ifc_handlers.create_wall(
            {
                "p1": {"x": 0.0, "y": y},
                "p2": {"x": 3.0, "y": y},
                "height": 3.0,
                "thickness": 0.2,
            }
        )
        guids.append(str(result["guid"]))

    assert len(topo_registry.all_wall_specs()) == n

    for idx in (0, 17, 54):
        mesh = topo_registry.mesh_for_guid(guids[idx])
        assert mesh is not None
        tid = _top_face_topo_id(mesh)
        out = await geom_handlers.extrude_face({"topo_id": tid, "vector": [0.0, 0.0, 0.12]})
        assert out["guid"] == guids[idx]
        assert out["topo_map"]

    assert len(topo_registry.all_wall_specs()) == n
    for i in (0, 17, 54):
        spec = topo_registry.get_wall_spec(guids[i])
        assert spec is not None
        assert spec.height >= 3.12 - 1e-5
