# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Tests unitarios de los handlers del dominio ``system.*``."""

from __future__ import annotations

from axonbim import __version__
from axonbim.handlers import system
from axonbim.rpc.dispatcher import Dispatcher
from axonbim.rpc.models import PROTOCOL_VERSION


async def test_ping_returns_pong_and_timestamp() -> None:
    resp = await system.ping({})
    assert resp["pong"] is True
    assert isinstance(resp["ts"], int)
    assert resp["ts"] > 0


async def test_version_returns_protocol_and_backend() -> None:
    resp = await system.version({})
    assert resp["protocol"] == PROTOCOL_VERSION
    assert resp["backend"] == __version__


async def test_register_populates_all_system_methods() -> None:
    disp = Dispatcher()
    system.register(disp)
    assert disp.registered_methods() == ["system.ping", "system.shutdown", "system.version"]


async def test_shutdown_sets_event() -> None:
    disp = Dispatcher()
    system.register(disp)
    assert not disp.shutdown_event.is_set()

    handlers = disp._handlers  # type: ignore[attr-defined]
    result = await handlers["system.shutdown"]({})
    assert result == {"ok": True}
    assert disp.shutdown_event.is_set()
