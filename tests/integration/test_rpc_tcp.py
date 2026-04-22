# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Integracion TCP loopback: transporte real que usara Godot.

Justificacion: Godot 4.x no expone ``StreamPeerUnix``; comprobamos que el
mismo backend responde identico via TCP para que el cliente GDScript funcione.
"""

from __future__ import annotations

import asyncio
import contextlib
import json
import socket
from collections.abc import AsyncIterator

import pytest
import pytest_asyncio

from axonbim.handlers import system as system_handlers
from axonbim.rpc.dispatcher import Dispatcher
from axonbim.rpc.framing import read_message, write_message
from axonbim.rpc.server import serve
from tests.unix_socket_path import short_unix_socket_path


def _free_tcp_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return int(s.getsockname()[1])


@pytest_asyncio.fixture
async def tcp_server() -> AsyncIterator[int]:
    port = _free_tcp_port()
    unix_sock = short_unix_socket_path("tcp-dual")

    dispatcher = Dispatcher()
    system_handlers.register(dispatcher)

    task = asyncio.create_task(
        serve(
            dispatcher,
            unix_sock,
            tcp_host="127.0.0.1",
            tcp_port=port,
            install_signal_handlers=False,
        )
    )

    # Esperar a que ambos listeners esten listos.
    for _ in range(100):
        try:
            with socket.create_connection(("127.0.0.1", port), timeout=0.05):
                break
        except OSError:
            await asyncio.sleep(0.01)
    else:
        task.cancel()
        raise RuntimeError("Puerto TCP no disponible a tiempo")

    try:
        yield port
    finally:
        dispatcher.shutdown_event.set()
        try:
            await asyncio.wait_for(task, timeout=2.0)
        except TimeoutError:
            task.cancel()
            with pytest.raises(asyncio.CancelledError):
                await task


async def test_tcp_ping_roundtrip(tcp_server: int) -> None:
    reader, writer = await asyncio.open_connection("127.0.0.1", tcp_server)
    try:
        payload = {"jsonrpc": "2.0", "id": 1, "method": "system.ping", "params": {}}
        await write_message(writer, json.dumps(payload).encode("utf-8"))
        raw = await read_message(reader)
        assert raw is not None
        resp = json.loads(raw)
        assert resp["result"]["pong"] is True
    finally:
        writer.close()
        with contextlib.suppress(ConnectionError, BrokenPipeError):
            await writer.wait_closed()


async def test_tcp_version(tcp_server: int) -> None:
    reader, writer = await asyncio.open_connection("127.0.0.1", tcp_server)
    try:
        payload = {"jsonrpc": "2.0", "id": 2, "method": "system.version"}
        await write_message(writer, json.dumps(payload).encode("utf-8"))
        raw = await read_message(reader)
        assert raw is not None
        resp = json.loads(raw)
        assert "protocol" in resp["result"]
        assert "backend" in resp["result"]
    finally:
        writer.close()
        with contextlib.suppress(ConnectionError, BrokenPipeError):
            await writer.wait_closed()
