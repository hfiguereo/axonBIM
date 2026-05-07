# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Tests de ``project.open`` (carga IFC + rehidratación de muros caja)."""

from __future__ import annotations

import pytest

from axonbim.geometry import topo_registry
from axonbim.handlers import ifc as ifc_handlers
from axonbim.handlers import project as project_handlers
from axonbim.ifc.session import reset_session
from axonbim.rpc.dispatcher import RpcError


@pytest.fixture(autouse=True)
def _fresh_session() -> None:
    reset_session()


async def test_project_open_rehydrates_axon_wall(tmp_path) -> None:  # type: ignore[no-untyped-def]
    await ifc_handlers.create_wall(
        {
            "p1": {"x": 1.0, "y": 2.0, "z": 0.5},
            "p2": {"x": 4.0, "y": 2.0, "z": 0.5},
            "height": 3.0,
            "thickness": 0.2,
        }
    )
    p = tmp_path / "roundtrip.ifc"
    await project_handlers.save({"path": str(p)})
    reset_session()
    assert topo_registry.all_wall_specs() == {}

    out = await project_handlers.open_ifc({"path": str(p)})
    assert out["wall_count"] == 1
    assert out["walls_skipped"] == 0
    assert len(out["storeys"]) >= 1
    guid = str(out["walls"][0]["guid"])
    spec = topo_registry.get_wall_spec(guid)
    assert spec is not None
    assert abs(spec.p1[0] - 1.0) < 1e-3
    assert abs(spec.p1[1] - 2.0) < 1e-3
    assert abs(spec.p2[0] - 4.0) < 1e-3
    assert abs(spec.height - 3.0) < 1e-3
    assert abs(spec.thickness - 0.2) < 1e-3


async def test_project_open_missing_file_raises(tmp_path) -> None:
    with pytest.raises(RpcError):
        await project_handlers.open_ifc({"path": str(tmp_path / "no_existe.ifc")})
