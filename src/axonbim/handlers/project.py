# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Handlers del dominio ``project.*``.

Expone ``project.save`` hoy; ``project.open`` y transiciones de estado ISO 19650
(WIP/Shared/Published) quedan para Fase 2/4.
"""

from __future__ import annotations

import logging
from pathlib import Path
from typing import Any

from pydantic import BaseModel, ConfigDict

from axonbim.ifc.session import get_session
from axonbim.rpc.dispatcher import Dispatcher, RpcError
from axonbim.rpc.models import ErrorCode

_log = logging.getLogger(__name__)


class SaveParams(BaseModel):
    """Parametros de ``project.save``: ruta destino en el filesystem local."""

    model_config = ConfigDict(extra="forbid")

    path: str


async def save(params: dict[str, Any]) -> dict[str, Any]:
    """Handler de ``project.save``: serializa la sesion IFC activa a ``path``.

    Raises:
        RpcError: con ``INTERNAL_ERROR`` si el filesystem rechaza la escritura.
    """
    args = SaveParams.model_validate(params)
    target = Path(args.path).expanduser()

    session = get_session()
    try:
        session.save(target)
    except OSError as exc:
        raise RpcError(
            ErrorCode.INTERNAL_ERROR, f"No pude escribir IFC: {exc}", {"path": str(target)}
        ) from exc

    size = target.stat().st_size
    _log.info("Proyecto guardado: %s (%d bytes)", target, size)
    return {"path": str(target), "bytes": size}


def register(dispatcher: Dispatcher) -> None:
    """Registra todos los metodos ``project.*``."""
    dispatcher.register("project.save", save)
