# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Integracion RPC: cliente asyncio habla con el servidor real sobre Unix socket."""

from __future__ import annotations

import asyncio
import contextlib
import json
from collections.abc import AsyncIterator
from pathlib import Path
from typing import Any

import pytest
import pytest_asyncio

from axonbim import __version__
from axonbim.handlers import system as system_handlers
from axonbim.rpc.dispatcher import Dispatcher
from axonbim.rpc.framing import read_message, write_message
from axonbim.rpc.models import PROTOCOL_VERSION, ErrorCode
from axonbim.rpc.server import serve

pytestmark = pytest.mark.skipif(
    not hasattr(asyncio, "start_unix_server"),
    reason="RPC sobre socket Unix no disponible en esta plataforma.",
)


class RpcClient:
    """Cliente asyncio minimo (equivalente conceptual al que usara Godot)."""

    def __init__(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        self._reader = reader
        self._writer = writer
        self._next_id = 0

    @classmethod
    async def connect(cls, path: Path) -> RpcClient:
        reader, writer = await asyncio.open_unix_connection(str(path))
        return cls(reader, writer)

    async def close(self) -> None:
        self._writer.close()
        with contextlib.suppress(ConnectionError, BrokenPipeError):
            await self._writer.wait_closed()

    async def call(self, method: str, params: dict[str, Any] | None = None) -> dict[str, Any]:
        self._next_id += 1
        payload = {
            "jsonrpc": "2.0",
            "id": self._next_id,
            "method": method,
            "params": params or {},
        }
        await write_message(self._writer, json.dumps(payload).encode("utf-8"))
        raw = await read_message(self._reader)
        assert raw is not None
        return json.loads(raw)  # type: ignore[no-any-return]

    async def notify(self, method: str, params: dict[str, Any] | None = None) -> None:
        payload = {"jsonrpc": "2.0", "method": method, "params": params or {}}
        await write_message(self._writer, json.dumps(payload).encode("utf-8"))

    async def send_raw(self, raw: bytes) -> dict[str, Any] | None:
        await write_message(self._writer, raw)
        reply = await read_message(self._reader)
        if reply is None:
            return None
        return json.loads(reply)  # type: ignore[no-any-return]


@pytest_asyncio.fixture
async def running_server(tmp_path: Path) -> AsyncIterator[Path]:
    sock = tmp_path / "axonbim-test.sock"
    dispatcher = Dispatcher()
    system_handlers.register(dispatcher)

    task = asyncio.create_task(serve(dispatcher, sock, install_signal_handlers=False))

    for _ in range(100):
        if sock.exists():
            break
        await asyncio.sleep(0.01)
    else:
        task.cancel()
        raise RuntimeError("Socket no aparecio a tiempo")

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


async def test_ping_roundtrip(running_server: Path) -> None:
    client = await RpcClient.connect(running_server)
    try:
        resp = await client.call("system.ping")
        assert resp["jsonrpc"] == "2.0"
        assert resp["id"] == 1
        assert resp["result"]["pong"] is True
        assert isinstance(resp["result"]["ts"], int)
    finally:
        await client.close()


async def test_version_returns_protocol_and_backend(running_server: Path) -> None:
    client = await RpcClient.connect(running_server)
    try:
        resp = await client.call("system.version")
        assert resp["result"] == {
            "protocol": PROTOCOL_VERSION,
            "backend": __version__,
        }
    finally:
        await client.close()


async def test_method_not_found(running_server: Path) -> None:
    client = await RpcClient.connect(running_server)
    try:
        resp = await client.call("system.does_not_exist")
        assert resp["error"]["code"] == ErrorCode.METHOD_NOT_FOUND
    finally:
        await client.close()


async def test_parse_error_on_invalid_json(running_server: Path) -> None:
    client = await RpcClient.connect(running_server)
    try:
        resp = await client.send_raw(b"not json at all")
        assert resp is not None
        assert resp["error"]["code"] == ErrorCode.PARSE_ERROR
    finally:
        await client.close()


async def test_invalid_request_missing_jsonrpc(running_server: Path) -> None:
    client = await RpcClient.connect(running_server)
    try:
        resp = await client.send_raw(b'{"id":1,"method":"system.ping"}')
        assert resp is not None
        assert resp["error"]["code"] == ErrorCode.INVALID_REQUEST
    finally:
        await client.close()


async def test_notification_produces_no_response(running_server: Path) -> None:
    client = await RpcClient.connect(running_server)
    try:
        await client.notify("system.ping")
        follow_up = await client.call("system.ping")
        assert follow_up["result"]["pong"] is True
    finally:
        await client.close()


async def test_multiple_sequential_calls_share_connection(running_server: Path) -> None:
    client = await RpcClient.connect(running_server)
    try:
        ids = []
        for _ in range(5):
            resp = await client.call("system.ping")
            ids.append(resp["id"])
        assert ids == [1, 2, 3, 4, 5]
    finally:
        await client.close()


async def test_shutdown_stops_server(tmp_path: Path) -> None:
    sock = tmp_path / "axonbim-shutdown.sock"
    dispatcher = Dispatcher()
    system_handlers.register(dispatcher)

    task = asyncio.create_task(serve(dispatcher, sock, install_signal_handlers=False))
    for _ in range(100):
        if sock.exists():
            break
        await asyncio.sleep(0.01)

    client = await RpcClient.connect(sock)
    try:
        resp = await client.call("system.shutdown")
        assert resp["result"] == {"ok": True}
    finally:
        await client.close()

    await asyncio.wait_for(task, timeout=2.0)
    assert not sock.exists()
