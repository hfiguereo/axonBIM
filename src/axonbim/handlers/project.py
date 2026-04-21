# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Handlers del dominio ``project.*``: save, load, y en el futuro
estados ISO 19650 / undo / redo.
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
    model_config = ConfigDict(extra="forbid")

    path: str


async def save(params: dict[str, Any]) -> dict[str, Any]:
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
