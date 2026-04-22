# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Tests unitarios de handlers ``geom.*``."""

from __future__ import annotations

import pytest
from pydantic import ValidationError

from axonbim.handlers import geom as geom_handlers
from axonbim.rpc.dispatcher import Dispatcher, RpcError
from axonbim.rpc.models import ErrorCode


async def test_extrude_face_happy_path_returns_mesh_and_topo_map() -> None:
    result = await geom_handlers.extrude_face(
        {
            "topo_id": "face.001",
            "vector": [0.2, 0.0, 0.0],
        }
    )
    assert "mesh" in result
    assert "topo_map" in result
    assert result["topo_map"]["face.001"] == "face.001:extruded"
    assert result["mesh"]["indices"]


async def test_extrude_face_rejects_zero_vector_with_rpc_error() -> None:
    with pytest.raises(RpcError) as exc_info:
        await geom_handlers.extrude_face({"topo_id": "face.001", "vector": [0.0, 0.0, 0.0]})
    assert exc_info.value.code == ErrorCode.INVALID_PARAMS


async def test_extrude_face_rejects_invalid_vector_shape() -> None:
    with pytest.raises(ValidationError):
        await geom_handlers.extrude_face({"topo_id": "face.001", "vector": [0.2, 0.0]})


async def test_register_geom_handlers_exposes_extrude_face() -> None:
    disp = Dispatcher()
    geom_handlers.register(disp)
    assert "geom.extrude_face" in disp.registered_methods()
