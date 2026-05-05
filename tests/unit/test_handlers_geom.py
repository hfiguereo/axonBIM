# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Tests unitarios de handlers ``geom.*``."""

from __future__ import annotations

import pytest
from pydantic import ValidationError

from axonbim.geometry.meshing import Mesh
from axonbim.geometry.wall_extrude import face_index_for_topo_id, outward_normals
from axonbim.geometry.wall_spec import WallSpec
from axonbim.handlers import geom as geom_handlers
from axonbim.handlers import ifc as ifc_handlers
from axonbim.history import sqlite_store
from axonbim.ifc.session import reset_session
from axonbim.rpc.dispatcher import Dispatcher, RpcError
from axonbim.rpc.models import ErrorCode


@pytest.fixture(autouse=True)
def _fresh_undo_db(tmp_path, monkeypatch) -> None:  # type: ignore[no-untyped-def]
    """Base de historial aislada y sesion limpia (``geom`` muta IFC + SQLite)."""
    monkeypatch.setenv("AXONBIM_HISTORY_DB", str(tmp_path / "undo.sqlite"))
    sqlite_store.close_for_tests()
    reset_session()
    yield
    sqlite_store.close_for_tests()


async def test_extrude_face_happy_path_returns_mesh_and_topo_map() -> None:
    wall = await ifc_handlers.create_wall(
        {
            "p1": {"x": 0.0, "y": 0.0},
            "p2": {"x": 4.0, "y": 0.0},
            "height": 3.0,
            "thickness": 0.2,
        }
    )
    guid = wall["guid"]
    mesh = Mesh.from_dict(wall["mesh"])
    topo_id = mesh.topo_ids[0]
    spec = WallSpec((0.0, 0.0, 0.0), (4.0, 0.0, 0.0), 3.0, 0.2)
    fi = face_index_for_topo_id(mesh, topo_id)
    assert fi >= 0
    nx, ny, nz = outward_normals(spec)[fi]
    distance = 0.25
    vec = [distance * nx, distance * ny, distance * nz]

    result = await geom_handlers.extrude_face({"topo_id": topo_id, "vector": vec})

    assert result["guid"] == guid
    assert "mesh" in result
    assert "topo_map" in result
    assert result["mesh"]["indices"]
    assert isinstance(result["topo_map"], dict)


async def test_extrude_face_rejects_zero_vector_with_rpc_error() -> None:
    with pytest.raises(RpcError) as exc_info:
        await geom_handlers.extrude_face({"topo_id": "face.001", "vector": [0.0, 0.0, 0.0]})
    assert exc_info.value.code == ErrorCode.INVALID_PARAMS


async def test_extrude_face_raises_topo_not_found() -> None:
    with pytest.raises(RpcError) as exc_info:
        await geom_handlers.extrude_face({"topo_id": "unknown.face", "vector": [0.2, 0.0, 0.0]})
    assert exc_info.value.code == ErrorCode.TOPO_ID_NOT_FOUND


async def test_extrude_face_rejects_invalid_vector_shape() -> None:
    with pytest.raises(ValidationError):
        await geom_handlers.extrude_face({"topo_id": "face.001", "vector": [0.2, 0.0]})


async def test_register_geom_handlers_exposes_extrude_face() -> None:
    disp = Dispatcher()
    geom_handlers.register(disp)
    assert "geom.extrude_face" in disp.registered_methods()
