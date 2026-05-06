# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Tests unitarios de los handlers ``ifc.*`` y ``project.*``."""

from __future__ import annotations

import pytest
from pydantic import ValidationError

from axonbim.handlers import ifc as ifc_handlers
from axonbim.handlers import project as project_handlers
from axonbim.ifc.session import reset_session
from axonbim.rpc.dispatcher import Dispatcher, RpcError
from axonbim.rpc.models import ErrorCode


@pytest.fixture(autouse=True)
def _fresh_session() -> None:
    reset_session()


async def test_create_wall_happy_path() -> None:
    result = await ifc_handlers.create_wall(
        {
            "p1": {"x": 0.0, "y": 0.0},
            "p2": {"x": 4.0, "y": 0.0},
            "height": 3.0,
            "thickness": 0.2,
        }
    )
    assert "guid" in result
    assert result["mesh"]["indices"]
    assert "workspace_xy_half_m" in result
    assert len(result["workspace_xy_half_m"]) == 2


async def test_create_wall_expands_workspace_xy_half_extents() -> None:
    result = await ifc_handlers.create_wall(
        {
            "p1": {"x": 0.0, "y": 0.0},
            "p2": {"x": 100.0, "y": 0.0},
            "height": 3.0,
            "thickness": 0.2,
        }
    )
    hx: float = float(result["workspace_xy_half_m"][0])
    hy: float = float(result["workspace_xy_half_m"][1])
    assert hx >= 100.0 * 1.12 - 1e-5
    assert hy >= 50.0 - 1e-5


async def test_create_wall_chain_join_adjusts_p1_on_perpendicular_corner() -> None:
    first = await ifc_handlers.create_wall(
        {
            "p1": {"x": 0.0, "y": 0.0},
            "p2": {"x": 4.0, "y": 0.0},
            "height": 3.0,
            "thickness": 0.20,
        }
    )
    first_guid = str(first["guid"])
    second = await ifc_handlers.create_wall(
        {
            "p1": {"x": 4.0, "y": 0.0},
            "p2": {"x": 4.0, "y": 3.0},
            "height": 3.0,
            "thickness": 0.20,
            "join_with_guid": first_guid,
        }
    )
    second_guid = str(second["guid"])
    spec = await ifc_handlers.get_wall_spec({"guid": second_guid})
    ws = spec["wall_spec"]
    # Con cierre de esquina de 90°, el inicio se retrocede ~t/2 sobre el eje nuevo.
    assert abs(float(ws["p1"]["x"]) - 4.0) < 1e-6
    assert abs(float(ws["p1"]["y"]) + 0.1) < 1e-6


async def test_create_wall_rejects_unknown_fields() -> None:
    with pytest.raises(ValidationError):
        await ifc_handlers.create_wall(
            {
                "p1": {"x": 0.0, "y": 0.0},
                "p2": {"x": 4.0, "y": 0.0},
                "height": 3.0,
                "thickness": 0.2,
                "extra": "nope",
            }
        )


async def test_create_wall_rejects_non_positive_height() -> None:
    with pytest.raises(ValidationError):
        await ifc_handlers.create_wall(
            {
                "p1": {"x": 0.0, "y": 0.0},
                "p2": {"x": 4.0, "y": 0.0},
                "height": -1.0,
                "thickness": 0.2,
            }
        )


async def test_create_wall_rejects_coincident_points_with_rpc_error() -> None:
    with pytest.raises(RpcError) as exc_info:
        await ifc_handlers.create_wall(
            {
                "p1": {"x": 0.0, "y": 0.0},
                "p2": {"x": 0.0, "y": 0.0},
                "height": 3.0,
                "thickness": 0.2,
            }
        )
    assert exc_info.value.code == ErrorCode.INVALID_PARAMS


async def test_register_ifc_handlers_exposes_create_wall() -> None:
    disp = Dispatcher()
    ifc_handlers.register(disp)
    methods = disp.registered_methods()
    assert "ifc.create_wall" in methods
    assert "ifc.get_wall_spec" in methods
    assert "ifc.set_wall_typology" in methods
    assert "ifc.delete" in methods


async def test_get_wall_spec_after_create() -> None:
    created = await ifc_handlers.create_wall(
        {
            "p1": {"x": 0.0, "y": 0.0},
            "p2": {"x": 2.0, "y": 0.0},
            "height": 3.0,
            "thickness": 0.2,
        }
    )
    guid = str(created["guid"])
    spec = await ifc_handlers.get_wall_spec({"guid": guid})
    assert spec["wall_spec"]["height"] == 3.0
    assert spec["wall_spec"]["thickness"] == 0.2


async def test_delete_wall_removes_from_session() -> None:
    created = await ifc_handlers.create_wall(
        {
            "p1": {"x": 0.0, "y": 0.0},
            "p2": {"x": 2.0, "y": 0.0},
            "height": 3.0,
            "thickness": 0.2,
        }
    )
    guid = str(created["guid"])
    out = await ifc_handlers.delete_product({"guid": guid})
    assert out["ok"] is True
    with pytest.raises(RpcError):
        await ifc_handlers.get_wall_spec({"guid": guid})


async def test_delete_unknown_wall_rpc_error() -> None:
    with pytest.raises(RpcError) as exc_info:
        await ifc_handlers.delete_product({"guid": "0" * 22})
    assert exc_info.value.code == ErrorCode.INVALID_PARAMS


async def test_set_wall_typology_updates_mesh() -> None:
    created = await ifc_handlers.create_wall(
        {
            "p1": {"x": 0.0, "y": 0.0},
            "p2": {"x": 2.0, "y": 0.0},
            "height": 3.0,
            "thickness": 0.2,
        }
    )
    guid = str(created["guid"])
    out = await ifc_handlers.set_wall_typology(
        {"guid": guid, "height": 3.5, "thickness": 0.15, "typology_id": "M-TEST"}
    )
    assert out["guid"] == guid
    assert "mesh" in out
    spec = await ifc_handlers.get_wall_spec({"guid": guid})
    assert spec["wall_spec"]["height"] == 3.5
    assert spec["wall_spec"]["thickness"] == 0.15


async def test_project_save_writes_file(tmp_path) -> None:  # type: ignore[no-untyped-def]
    await ifc_handlers.create_wall(
        {
            "p1": {"x": 0.0, "y": 0.0},
            "p2": {"x": 4.0, "y": 0.0},
            "height": 3.0,
            "thickness": 0.2,
        }
    )
    target = tmp_path / "project.ifc"
    result = await project_handlers.save({"path": str(target)})
    assert result["path"] == str(target)
    assert target.stat().st_size == result["bytes"]


async def test_project_save_rejects_unknown_fields(tmp_path) -> None:  # type: ignore[no-untyped-def]
    with pytest.raises(ValidationError):
        await project_handlers.save({"path": str(tmp_path / "x.ifc"), "foo": 1})


async def test_register_project_handlers_exposes_save() -> None:
    disp = Dispatcher()
    project_handlers.register(disp)
    assert "project.save" in disp.registered_methods()
