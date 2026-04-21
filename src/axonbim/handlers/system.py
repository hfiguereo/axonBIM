# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Handlers del dominio ``system.*``: ping, version, shutdown.

Spec: ``docs/architecture/jsonrpc-protocol.md`` §5.1.
"""

from __future__ import annotations

import time
from typing import Any

from axonbim import __version__
from axonbim.rpc.dispatcher import Dispatcher
from axonbim.rpc.models import PROTOCOL_VERSION


async def ping(_params: dict[str, Any]) -> dict[str, Any]:
    """Handler de ``system.ping``. Devuelve ``{pong, ts}`` para medir RTT."""
    return {"pong": True, "ts": int(time.time() * 1000)}


async def version(_params: dict[str, Any]) -> dict[str, Any]:
    """Handler de ``system.version``. Devuelve version de protocolo y de backend."""
    return {"protocol": PROTOCOL_VERSION, "backend": __version__}


def register(dispatcher: Dispatcher) -> None:
    """Registra todos los metodos ``system.*`` en el dispatcher dado."""

    async def shutdown(_params: dict[str, Any]) -> dict[str, Any]:
        dispatcher.shutdown_event.set()
        return {"ok": True}

    dispatcher.register("system.ping", ping)
    dispatcher.register("system.version", version)
    dispatcher.register("system.shutdown", shutdown)
