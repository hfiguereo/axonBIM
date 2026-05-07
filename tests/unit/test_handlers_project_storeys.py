# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Tests de ``project.list_storeys`` / ``create_storey`` / ``set_active_storey``."""

from __future__ import annotations

import ifcopenshell
import pytest
from pydantic import ValidationError

from axonbim.handlers import ifc as ifc_handlers
from axonbim.handlers import project as project_handlers
from axonbim.ifc.session import get_session, reset_session


@pytest.fixture(autouse=True)
def _fresh_session() -> None:
    reset_session()


async def test_list_storeys_default_one_level() -> None:
    out = await project_handlers.list_storeys({})
    assert "storeys" in out
    assert len(out["storeys"]) == 1
    row = out["storeys"][0]
    assert row["is_active"] is True
    assert row["elevation_m"] == 0.0
    assert row["name"] == "Planta baja"


async def test_list_storeys_rejects_extra_params() -> None:
    with pytest.raises(ValidationError):
        await project_handlers.list_storeys({"x": 1})


async def test_create_set_active_and_wall_container() -> None:
    await project_handlers.create_storey({"name": "Piso tipo", "elevation_m": 3.15})
    lst = await project_handlers.list_storeys({})
    assert len(lst["storeys"]) == 2
    upper = next(s for s in lst["storeys"] if s["name"] == "Piso tipo")
    assert upper["elevation_m"] == 3.15
    assert upper["is_active"] is False

    await project_handlers.set_active_storey({"guid": upper["guid"]})
    lst2 = await project_handlers.list_storeys({})
    assert sum(1 for s in lst2["storeys"] if s["is_active"]) == 1
    active = next(s for s in lst2["storeys"] if s["is_active"])
    assert active["guid"] == upper["guid"]

    wall = await ifc_handlers.create_wall(
        {
            "p1": {"x": 0.0, "y": 0.0, "z": 3.15},
            "p2": {"x": 2.0, "y": 0.0, "z": 3.15},
            "height": 3.0,
            "thickness": 0.2,
        }
    )
    guid = str(wall["guid"])
    session = get_session()
    w = next(x for x in session.file.by_type("IfcWall") if str(x.GlobalId) == guid)
    rels = w.ContainedInStructure or []
    assert rels
    assert rels[0].RelatingStructure == session.storey
    assert float(session.storey.Elevation) == 3.15


async def test_storeys_survive_ifc_roundtrip_on_disk(tmp_path) -> None:  # type: ignore[no-untyped-def]
    await project_handlers.create_storey({"name": "Alto", "elevation_m": 6.0})
    p = tmp_path / "levels.ifc"
    await project_handlers.save({"path": str(p)})
    f = ifcopenshell.open(str(p))
    storeys = sorted(
        f.by_type("IfcBuildingStorey"),
        key=lambda s: float(s.Elevation or 0.0),
    )
    assert len(storeys) == 2
    assert abs(float(storeys[0].Elevation or 0.0)) < 1e-6
    assert abs(float(storeys[1].Elevation or 0.0) - 6.0) < 1e-6
