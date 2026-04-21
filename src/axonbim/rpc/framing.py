# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
r"""Framing LSP-style sobre streams asyncio.

Formato:

.. code-block:: text

    Content-Length: <N>\r\n
    \r\n
    <N bytes de cuerpo JSON UTF-8>

``Content-Type`` es opcional y se ignora si esta presente.
"""

from __future__ import annotations

import asyncio
import logging
from typing import Final, Protocol

_HEADER_ENCODING: Final[str] = "ascii"
_BODY_ENCODING: Final[str] = "utf-8"
_MAX_HEADER_BYTES: Final[int] = 8 * 1024
_MAX_BODY_BYTES: Final[int] = 64 * 1024 * 1024

_log = logging.getLogger(__name__)


class FramingError(Exception):
    """Error irrecuperable de framing (header malformado, EOF prematuro)."""


class _Writer(Protocol):
    def write(self, data: bytes) -> None: ...

    async def drain(self) -> None: ...


async def read_message(reader: asyncio.StreamReader) -> bytes | None:
    """Lee un mensaje completo del stream. Devuelve ``None`` en EOF limpio."""
    header_result = await _read_headers(reader)
    if header_result is None:
        return None
    content_length = header_result

    if content_length == 0:
        return b""
    return await reader.readexactly(content_length)


async def _read_headers(reader: asyncio.StreamReader) -> int | None:
    content_length: int | None = None
    header_bytes = 0

    while True:
        line = await reader.readline()
        if not line:
            if content_length is None and header_bytes == 0:
                return None
            raise FramingError("EOF inesperado leyendo headers")

        header_bytes += len(line)
        if header_bytes > _MAX_HEADER_BYTES:
            raise FramingError("Bloque de headers excede el limite")

        stripped = line.rstrip(b"\r\n")
        if stripped == b"":
            break

        content_length = _parse_header_line(stripped, content_length)

    if content_length is None:
        raise FramingError("Mensaje sin Content-Length")
    if content_length < 0 or content_length > _MAX_BODY_BYTES:
        raise FramingError(f"Content-Length fuera de rango: {content_length}")
    return content_length


def _parse_header_line(line: bytes, current: int | None) -> int | None:
    try:
        name, _, value = line.decode(_HEADER_ENCODING).partition(":")
    except UnicodeDecodeError as exc:
        raise FramingError(f"Header no-ASCII: {exc}") from exc

    name_lower = name.strip().lower()
    value = value.strip()
    if name_lower == "content-length":
        try:
            return int(value)
        except ValueError as exc:
            raise FramingError(f"Content-Length invalido: {value!r}") from exc
    if name_lower != "content-type":
        _log.debug("Header RPC ignorado: %r", name_lower)
    return current


async def write_message(writer: _Writer, body: bytes) -> None:
    """Escribe un mensaje enmarcado. No agrega nueva linea al body."""
    header = f"Content-Length: {len(body)}\r\n\r\n".encode(_HEADER_ENCODING)
    writer.write(header)
    if body:
        writer.write(body)
    await writer.drain()


def encode_body(text: str) -> bytes:
    """Codifica un cuerpo JSON UTF-8."""
    return text.encode(_BODY_ENCODING)


def decode_body(body: bytes) -> str:
    """Decodifica bytes UTF-8 a string (con error descriptivo)."""
    try:
        return body.decode(_BODY_ENCODING)
    except UnicodeDecodeError as exc:
        raise FramingError(f"Body no es UTF-8 valido: {exc}") from exc
