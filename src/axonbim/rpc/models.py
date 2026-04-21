# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Modelos Pydantic v2 para mensajes JSON-RPC 2.0.

Spec: ``docs/architecture/jsonrpc-protocol.md``.

Los mensajes llegan desde Godot como bytes UTF-8; estos modelos son la
frontera de validacion: cualquier payload malformado rebota con
``INVALID_REQUEST`` o ``PARSE_ERROR`` antes de tocar logica de dominio.
"""

from __future__ import annotations

from typing import Any, Final, Literal

from pydantic import BaseModel, ConfigDict, Field

JsonValue = int | float | str | bool | None | list["JsonValue"] | dict[str, "JsonValue"]
RpcId = int | str | None

PROTOCOL_VERSION: Final[str] = "0.1.0"


# --------------------------------------------------------------------------- #
# Codigos de error (alineados con docs/architecture/jsonrpc-protocol.md §4).
# --------------------------------------------------------------------------- #


class ErrorCode:
    """Constantes de codigos de error JSON-RPC usados por AxonBIM."""

    # Standard JSON-RPC 2.0.
    PARSE_ERROR: Final[int] = -32700
    INVALID_REQUEST: Final[int] = -32600
    METHOD_NOT_FOUND: Final[int] = -32601
    INVALID_PARAMS: Final[int] = -32602
    INTERNAL_ERROR: Final[int] = -32603

    # AxonBIM (-32000 a -32099).
    IFC_PARSE_ERROR: Final[int] = -32000
    BOOLEAN_FAILED: Final[int] = -32001
    TOPO_ID_NOT_FOUND: Final[int] = -32002
    STATE_TRANSITION_INVALID: Final[int] = -32003
    MIVED_SPEC_MISSING: Final[int] = -32004
    OPERATION_TIMEOUT: Final[int] = -32005
    BUSY: Final[int] = -32006
    LOIN_INCOMPLETE: Final[int] = -32007
    CONTAINER_IMMUTABLE: Final[int] = -32008


# --------------------------------------------------------------------------- #
# Modelos de mensaje.
# --------------------------------------------------------------------------- #


class Request(BaseModel):
    """JSON-RPC request. ``id is None`` => notificacion (sin respuesta)."""

    model_config = ConfigDict(extra="forbid")

    jsonrpc: Literal["2.0"]
    method: str
    id: RpcId = None
    params: dict[str, Any] = Field(default_factory=dict)

    @property
    def is_notification(self) -> bool:
        return self.id is None


class ErrorObject(BaseModel):
    """Cuerpo del campo ``error`` en respuestas fallidas."""

    model_config = ConfigDict(extra="forbid")

    code: int
    message: str
    data: dict[str, Any] | None = None


class SuccessResponse(BaseModel):
    """Respuesta con ``result`` (siempre dict por convencion del protocolo)."""

    model_config = ConfigDict(extra="forbid")

    jsonrpc: Literal["2.0"] = "2.0"
    id: RpcId
    result: dict[str, Any]


class ErrorResponse(BaseModel):
    """Respuesta con ``error`` poblado."""

    model_config = ConfigDict(extra="forbid")

    jsonrpc: Literal["2.0"] = "2.0"
    id: RpcId
    error: ErrorObject


class Notification(BaseModel):
    """Notificacion backend -> frontend (sin ``id``, sin respuesta esperada)."""

    model_config = ConfigDict(extra="forbid")

    jsonrpc: Literal["2.0"] = "2.0"
    method: str
    params: dict[str, Any] | None = None


# --------------------------------------------------------------------------- #
# Helpers.
# --------------------------------------------------------------------------- #


def make_error(
    request_id: RpcId,
    code: int,
    message: str,
    data: dict[str, Any] | None = None,
) -> ErrorResponse:
    """Construye un ``ErrorResponse`` sin exponer la clase ``ErrorObject``."""
    return ErrorResponse(id=request_id, error=ErrorObject(code=code, message=message, data=data))


def make_success(request_id: RpcId, result: dict[str, Any]) -> SuccessResponse:
    return SuccessResponse(id=request_id, result=result)
