# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""End-to-end: cliente RPC -> create_wall -> save -> reopen valida."""

from __future__ import annotations

import asyncio
import contextlib
import json
from collections.abc import AsyncIterator
from pathlib import Path

import ifcopenshell
import pytest
import pytest_asyncio

from axonbim.handlers import geom as geom_handlers
from axonbim.handlers import history as history_handlers
from axonbim.handlers import ifc as ifc_handlers
from axonbim.handlers import project as project_handlers
from axonbim.handlers import system as system_handlers
from axonbim.ifc.session import reset_session
from axonbim.rpc.dispatcher import Dispatcher
from axonbim.rpc.framing import read_message, write_message
from axonbim.rpc.models import ErrorCode
from axonbim.rpc.server import serve


@pytest_asyncio.fixture
async def running_server(tmp_path: Path) -> AsyncIterator[Path]:
    reset_session()
    sock = tmp_path / "axonbim.sock"
    dispatcher = Dispatcher()
    system_handlers.register(dispatcher)
    ifc_handlers.register(dispatcher)
    project_handlers.register(dispatcher)
    geom_handlers.register(dispatcher)
    history_handlers.register(dispatcher)

    task = asyncio.create_task(serve(dispatcher, sock, install_signal_handlers=False))
    for _ in range(100):
        if sock.exists():
            break
        await asyncio.sleep(0.01)

    try:
        yield sock
    finally:
        dispatcher.shutdown_event.set()
        try:
            await asyncio.wait_for(task, timeout=2.0)
        except TimeoutError:
            task.cancel()
            with pytest.raises(asyncio.CancelledError):
                await task


async def _call(sock: Path, method: str, params: dict) -> dict:  # type: ignore[type-arg]
    reader, writer = await asyncio.open_unix_connection(str(sock))
    try:
        payload = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
        await write_message(writer, json.dumps(payload).encode("utf-8"))
        raw = await read_message(reader)
        assert raw is not None
        return json.loads(raw)  # type: ignore[no-any-return]
    finally:
        writer.close()
        with contextlib.suppress(ConnectionError, BrokenPipeError):
            await writer.wait_closed()


async def test_create_wall_and_save_roundtrip(running_server: Path, tmp_path: Path) -> None:
    wall_resp = await _call(
        running_server,
        "ifc.create_wall",
        {
            "p1": {"x": 0.0, "y": 0.0},
            "p2": {"x": 5.0, "y": 0.0},
            "height": 2.8,
            "thickness": 0.15,
        },
    )
    assert "result" in wall_resp, wall_resp
    guid = wall_resp["result"]["guid"]
    assert len(guid) == 22
    assert wall_resp["result"]["mesh"]["indices"]

    target = tmp_path / "demo.ifc"
    save_resp = await _call(running_server, "project.save", {"path": str(target)})
    assert save_resp["result"]["bytes"] > 0

    reopened = ifcopenshell.open(str(target))
    walls = reopened.by_type("IfcWall")
    assert len(walls) == 1
    assert walls[0].GlobalId == guid


async def test_two_walls_preserve_both_in_file(running_server: Path, tmp_path: Path) -> None:
    for y in (0.0, 2.0):
        resp = await _call(
            running_server,
            "ifc.create_wall",
            {
                "p1": {"x": 0.0, "y": y},
                "p2": {"x": 4.0, "y": y},
                "height": 3.0,
                "thickness": 0.2,
            },
        )
        assert "result" in resp

    out = tmp_path / "two_walls.ifc"
    await _call(running_server, "project.save", {"path": str(out)})

    reopened = ifcopenshell.open(str(out))
    assert len(reopened.by_type("IfcWall")) == 2


async def test_extrude_face_and_undo_over_rpc(running_server: Path) -> None:
    wall_resp = await _call(
        running_server,
        "ifc.create_wall",
        {
            "p1": {"x": 0.0, "y": 0.0},
            "p2": {"x": 4.0, "y": 0.0},
            "height": 3.0,
            "thickness": 0.2,
        },
    )
    assert "result" in wall_resp, wall_resp
    guid = wall_resp["result"]["guid"]
    mesh = wall_resp["result"]["mesh"]
    top_face_topo_id = mesh["topo_ids"][2]

    extrude_resp = await _call(
        running_server,
        "geom.extrude_face",
        {"topo_id": top_face_topo_id, "vector": [0.0, 0.0, 0.5]},
    )
    assert "result" in extrude_resp, extrude_resp
    assert extrude_resp["result"]["guid"] == guid
    extruded_mesh = extrude_resp["result"]["mesh"]
    assert max(extruded_mesh["vertices"][2::3]) == pytest.approx(3.5)
    assert extrude_resp["result"]["topo_map"][top_face_topo_id] == extruded_mesh["topo_ids"][2]

    undo_resp = await _call(running_server, "history.undo", {})
    assert "result" in undo_resp, undo_resp
    assert undo_resp["result"]["applied"] is True
    undo_mesh = undo_resp["result"]["mesh"]
    assert undo_resp["result"]["guid"] == guid
    assert max(undo_mesh["vertices"][2::3]) == pytest.approx(3.0)
    assert undo_mesh["topo_ids"][2] == top_face_topo_id


async def test_extrude_face_rejects_stale_topo_id_over_rpc(running_server: Path) -> None:
    wall_resp = await _call(
        running_server,
        "ifc.create_wall",
        {
            "p1": {"x": 0.0, "y": 0.0},
            "p2": {"x": 4.0, "y": 0.0},
            "height": 3.0,
            "thickness": 0.2,
        },
    )
    assert "result" in wall_resp, wall_resp
    old_top_face_topo_id = wall_resp["result"]["mesh"]["topo_ids"][2]

    extrude_resp = await _call(
        running_server,
        "geom.extrude_face",
        {"topo_id": old_top_face_topo_id, "vector": [0.0, 0.0, 0.5]},
    )
    assert "result" in extrude_resp, extrude_resp
    assert old_top_face_topo_id not in extrude_resp["result"]["mesh"]["topo_ids"]

    stale_resp = await _call(
        running_server,
        "geom.extrude_face",
        {"topo_id": old_top_face_topo_id, "vector": [0.0, 0.0, 0.5]},
    )
    assert "error" in stale_resp
    assert stale_resp["error"]["code"] == ErrorCode.TOPO_ID_NOT_FOUND
    assert stale_resp["error"]["data"]["topo_id"] == old_top_face_topo_id


async def test_invalid_params_returns_structured_error(running_server: Path) -> None:
    resp = await _call(
        running_server,
        "ifc.create_wall",
        {
            "p1": {"x": 0.0, "y": 0.0},
            "p2": {"x": 0.0, "y": 0.0},
            "height": 3.0,
            "thickness": 0.2,
        },
    )
    assert "error" in resp
    assert resp["error"]["code"] == -32602
