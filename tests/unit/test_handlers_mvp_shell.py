# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Contrato RPC para huecos en muro y losas (SH-F2-12 / SH-F2-13)."""

from __future__ import annotations

import pytest

from axonbim.geometry import topo_registry
from axonbim.handlers import ifc as ifc_handlers
from axonbim.ifc.session import reset_session


@pytest.fixture(autouse=True)
def _fresh() -> None:
    reset_session()


@pytest.mark.asyncio
async def test_create_wall_opening_updates_mesh_and_spec() -> None:
    out = await ifc_handlers.create_wall(
        {
            "p1": {"x": 0.0, "y": 0.0},
            "p2": {"x": 5.0, "y": 0.0},
            "height": 3.0,
            "thickness": 0.2,
        }
    )
    guid = str(out["guid"])
    n0 = topo_registry.mesh_for_guid(guid)
    assert n0 is not None
    t0 = n0.triangle_count
    op = await ifc_handlers.create_wall_opening(
        {
            "wall_guid": guid,
            "along_start_m": 1.0,
            "width_m": 1.0,
            "sill_height_m": 0.5,
            "height_m": 2.0,
        }
    )
    assert op.get("opening_guid")
    spec = topo_registry.get_wall_spec(guid)
    assert spec is not None
    assert len(spec.openings) == 1
    n1 = topo_registry.mesh_for_guid(guid)
    assert n1 is not None
    assert n1.triangle_count > t0


@pytest.mark.asyncio
async def test_create_slab_registers_mesh() -> None:
    out = await ifc_handlers.create_slab(
        {
            "polygon_xy": [
                {"x": 0.0, "y": 0.0},
                {"x": 3.0, "y": 0.0},
                {"x": 3.0, "y": 2.0},
                {"x": 0.0, "y": 2.0},
            ],
            "thickness_m": 0.25,
            "z_top_m": 0.0,
        }
    )
    guid = str(out["guid"])
    assert topo_registry.get_slab_spec(guid) is not None
    assert topo_registry.mesh_for_guid(guid) is not None


@pytest.mark.asyncio
async def test_delete_slab_removes_registry() -> None:
    out = await ifc_handlers.create_slab(
        {
            "polygon_xy": [
                {"x": 0.0, "y": 0.0},
                {"x": 2.0, "y": 0.0},
                {"x": 2.0, "y": 2.0},
                {"x": 0.0, "y": 2.0},
            ],
            "thickness_m": 0.2,
            "z_top_m": 1.0,
        }
    )
    guid = str(out["guid"])
    await ifc_handlers.delete_product({"guid": guid})
    assert topo_registry.get_slab_spec(guid) is None
