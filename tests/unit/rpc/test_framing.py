# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Tests del framing LSP Content-Length."""

from __future__ import annotations

import asyncio

import pytest

from axonbim.rpc.framing import FramingError, read_message, write_message


async def _reader_from(data: bytes) -> asyncio.StreamReader:
    reader = asyncio.StreamReader()
    reader.feed_data(data)
    reader.feed_eof()
    return reader


async def test_read_single_message() -> None:
    body = b'{"jsonrpc":"2.0","id":1,"method":"system.ping"}'
    raw = f"Content-Length: {len(body)}\r\n\r\n".encode() + body
    reader = await _reader_from(raw)
    got = await read_message(reader)
    assert got == body


async def test_read_two_messages_in_sequence() -> None:
    b1 = b'{"a":1}'
    b2 = b'{"b":2}'
    raw = (
        f"Content-Length: {len(b1)}\r\n\r\n".encode()
        + b1
        + f"Content-Length: {len(b2)}\r\n\r\n".encode()
        + b2
    )
    reader = await _reader_from(raw)
    assert await read_message(reader) == b1
    assert await read_message(reader) == b2


async def test_read_with_content_type_header_ignored() -> None:
    body = b'{"ok":true}'
    raw = (
        b"Content-Type: application/vscode-jsonrpc; charset=utf-8\r\n"
        + f"Content-Length: {len(body)}\r\n\r\n".encode()
        + body
    )
    reader = await _reader_from(raw)
    assert await read_message(reader) == body


async def test_read_eof_before_any_header_returns_none() -> None:
    reader = await _reader_from(b"")
    assert await read_message(reader) is None


async def test_read_missing_content_length_raises() -> None:
    reader = await _reader_from(b"X-Other: 1\r\n\r\nbody")
    with pytest.raises(FramingError):
        await read_message(reader)


async def test_read_invalid_content_length_raises() -> None:
    reader = await _reader_from(b"Content-Length: abc\r\n\r\n")
    with pytest.raises(FramingError):
        await read_message(reader)


async def test_read_empty_body_zero_length() -> None:
    reader = await _reader_from(b"Content-Length: 0\r\n\r\n")
    assert await read_message(reader) == b""


async def test_read_fragmented_body_reassembled() -> None:
    body = b'{"jsonrpc":"2.0","id":42,"method":"ping"}'
    header = f"Content-Length: {len(body)}\r\n\r\n".encode()
    reader = asyncio.StreamReader()
    reader.feed_data(header)
    for i in range(0, len(body), 4):
        reader.feed_data(body[i : i + 4])
    reader.feed_eof()
    assert await read_message(reader) == body


async def test_read_header_too_large_raises() -> None:
    big = b"X-Pad: " + b"a" * (16 * 1024) + b"\r\n\r\n"
    reader = await _reader_from(big)
    with pytest.raises(FramingError):
        await read_message(reader)


async def test_read_eof_during_headers_raises() -> None:
    reader = await _reader_from(b"Content-Length: 10\r\n")
    with pytest.raises(FramingError):
        await read_message(reader)


async def test_write_roundtrip() -> None:
    server_read, client_write = asyncio.Queue[bytes](), None
    body = b'{"result":1}'

    class _FakeWriter:
        def __init__(self) -> None:
            self.buf = bytearray()

        def write(self, data: bytes) -> None:
            self.buf.extend(data)

        async def drain(self) -> None:
            return None

    writer = _FakeWriter()
    await write_message(writer, body)  # type: ignore[arg-type]
    del server_read, client_write

    assert writer.buf.endswith(body)
    header = bytes(writer.buf[: len(writer.buf) - len(body)])
    assert header == f"Content-Length: {len(body)}\r\n\r\n".encode()


async def test_write_empty_body() -> None:
    class _FakeWriter:
        def __init__(self) -> None:
            self.buf = bytearray()

        def write(self, data: bytes) -> None:
            self.buf.extend(data)

        async def drain(self) -> None:
            return None

    writer = _FakeWriter()
    await write_message(writer, b"")  # type: ignore[arg-type]
    assert bytes(writer.buf) == b"Content-Length: 0\r\n\r\n"
