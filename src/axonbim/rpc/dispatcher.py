# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Dispatcher de metodos RPC: registra handlers, valida, rutea, serializa.

Un ``Handler`` es una corutina que recibe ``params: dict`` y devuelve ``dict``.
El dispatcher absorbe ``RpcError`` (para errores controlados) y cualquier otra
excepcion la convierte en ``INTERNAL_ERROR`` (mapea a ``-32603``).
"""

from __future__ import annotations

import asyncio
import json
import logging
from collections.abc import Awaitable, Callable
from typing import Any

from pydantic import ValidationError

from axonbim.rpc.models import (
    ErrorCode,
    ErrorResponse,
    Request,
    RpcId,
    SuccessResponse,
    make_error,
    make_success,
)

Handler = Callable[[dict[str, Any]], Awaitable[dict[str, Any]]]

_log = logging.getLogger(__name__)


class RpcError(Exception):
    """Excepcion que un handler puede lanzar para producir un error tipado."""

    def __init__(self, code: int, message: str, data: dict[str, Any] | None = None) -> None:
        """Crea el error con ``code`` JSON-RPC, mensaje y ``data`` opcional."""
        super().__init__(message)
        self.code = code
        self.message = message
        self.data = data


class Dispatcher:
    """Registro de handlers + parser/encoder del protocolo JSON-RPC 2.0."""

    def __init__(self) -> None:
        """Crea un dispatcher vacio, sin handlers y con ``shutdown_event`` no activado."""
        self._handlers: dict[str, Handler] = {}
        self._shutdown_event: asyncio.Event = asyncio.Event()

    @property
    def shutdown_event(self) -> asyncio.Event:
        """Event que los handlers pueden poner para pedir al server que cierre."""
        return self._shutdown_event

    def register(self, method: str, handler: Handler) -> None:
        """Registra ``handler`` bajo el nombre RPC ``method`` (debe ser unico)."""
        if method in self._handlers:
            raise ValueError(f"Metodo RPC ya registrado: {method!r}")
        self._handlers[method] = handler
        _log.debug("Handler registrado: %s", method)

    def registered_methods(self) -> list[str]:
        """Lista ordenada de nombres de metodos RPC actualmente registrados."""
        return sorted(self._handlers)

    async def dispatch_bytes(self, raw: bytes) -> bytes | None:
        """Procesa un mensaje crudo. Devuelve la respuesta serializada o ``None``.

        ``None`` se devuelve cuando el mensaje era una notificacion valida
        (sin ``id``), ya que JSON-RPC manda no responder en ese caso.
        """
        response = await self._dispatch(raw)
        return None if response is None else _encode(response)

    async def _dispatch(self, raw: bytes) -> SuccessResponse | ErrorResponse | None:
        parsed = _parse_request(raw)
        if isinstance(parsed, ErrorResponse):
            return parsed

        request = parsed
        handler = self._handlers.get(request.method)
        if handler is None:
            _log.info("Metodo no encontrado: %s", request.method)
            if request.is_notification:
                return None
            return make_error(
                request.id,
                ErrorCode.METHOD_NOT_FOUND,
                f"Method not found: {request.method}",
            )

        return await _invoke_handler(request, handler)


async def _invoke_handler(
    request: Request, handler: Handler
) -> SuccessResponse | ErrorResponse | None:
    try:
        result = await handler(request.params)
    except RpcError as exc:
        _log.info("Handler %s lanzo RpcError: %s", request.method, exc.message)
        return (
            None
            if request.is_notification
            else make_error(request.id, exc.code, exc.message, exc.data)
        )
    except ValidationError as exc:
        _log.info("Params invalidos para %s", request.method)
        return (
            None
            if request.is_notification
            else make_error(
                request.id,
                ErrorCode.INVALID_PARAMS,
                "Invalid params",
                {"errors": exc.errors(include_url=False)},
            )
        )
    except Exception as exc:
        _log.exception("Excepcion no controlada en handler %s", request.method)
        return (
            None
            if request.is_notification
            else make_error(
                request.id,
                ErrorCode.INTERNAL_ERROR,
                "Internal error",
                {"type": type(exc).__name__},
            )
        )

    if request.is_notification:
        return None
    return make_success(request.id, result)


def _parse_request(raw: bytes) -> Request | ErrorResponse:
    text = raw.decode("utf-8", errors="replace")
    try:
        payload = json.loads(text)
    except json.JSONDecodeError as exc:
        _log.warning("JSON invalido: %s", exc)
        return make_error(None, ErrorCode.PARSE_ERROR, "Parse error", {"detail": str(exc)})

    if not isinstance(payload, dict):
        return make_error(None, ErrorCode.INVALID_REQUEST, "Request debe ser objeto JSON")

    raw_id = payload.get("id")
    request_id: RpcId = raw_id if isinstance(raw_id, int | str) or raw_id is None else None

    try:
        return Request.model_validate(payload)
    except ValidationError as exc:
        _log.warning("Request invalido: %s", exc)
        return make_error(
            request_id,
            ErrorCode.INVALID_REQUEST,
            "Invalid Request",
            {"errors": exc.errors(include_url=False)},
        )


def _encode(response: SuccessResponse | ErrorResponse) -> bytes:
    return response.model_dump_json(exclude_none=True).encode("utf-8")
