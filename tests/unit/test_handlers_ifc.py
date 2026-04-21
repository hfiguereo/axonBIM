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
    assert "ifc.create_wall" in disp.registered_methods()


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
