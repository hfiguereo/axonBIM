# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Tests del Dispatcher (parsing + ruteo + manejo de errores)."""

from __future__ import annotations

import json
from typing import Any

import pytest

from axonbim.rpc.dispatcher import Dispatcher, RpcError
from axonbim.rpc.models import ErrorCode


async def _echo(params: dict[str, Any]) -> dict[str, Any]:
    return {"echo": params}


async def _fail_rpc(_params: dict[str, Any]) -> dict[str, Any]:
    raise RpcError(ErrorCode.BOOLEAN_FAILED, "nope", {"reason": "degenerate"})


async def _boom(_params: dict[str, Any]) -> dict[str, Any]:
    raise RuntimeError("boom")


def _decode(raw: bytes | None) -> dict[str, Any]:
    assert raw is not None
    return json.loads(raw)


async def test_register_and_dispatch_success() -> None:
    disp = Dispatcher()
    disp.register("demo.echo", _echo)

    resp = _decode(
        await disp.dispatch_bytes(b'{"jsonrpc":"2.0","id":1,"method":"demo.echo","params":{"x":1}}')
    )
    assert resp == {"jsonrpc": "2.0", "id": 1, "result": {"echo": {"x": 1}}}


async def test_register_duplicate_raises() -> None:
    disp = Dispatcher()
    disp.register("demo.echo", _echo)
    with pytest.raises(ValueError, match="ya registrado"):
        disp.register("demo.echo", _echo)


async def test_parse_error_on_invalid_json() -> None:
    disp = Dispatcher()
    resp = _decode(await disp.dispatch_bytes(b"not json"))
    assert resp["error"]["code"] == ErrorCode.PARSE_ERROR


async def test_invalid_request_when_not_object() -> None:
    disp = Dispatcher()
    resp = _decode(await disp.dispatch_bytes(b"[1,2,3]"))
    assert resp["error"]["code"] == ErrorCode.INVALID_REQUEST


async def test_invalid_request_on_missing_jsonrpc() -> None:
    disp = Dispatcher()
    resp = _decode(await disp.dispatch_bytes(b'{"id":1,"method":"x"}'))
    assert resp["error"]["code"] == ErrorCode.INVALID_REQUEST


async def test_method_not_found_for_request() -> None:
    disp = Dispatcher()
    resp = _decode(await disp.dispatch_bytes(b'{"jsonrpc":"2.0","id":9,"method":"nope"}'))
    assert resp["error"]["code"] == ErrorCode.METHOD_NOT_FOUND
    assert resp["id"] == 9


async def test_method_not_found_notification_silenced() -> None:
    disp = Dispatcher()
    result = await disp.dispatch_bytes(b'{"jsonrpc":"2.0","method":"nope"}')
    assert result is None


async def test_handler_rpc_error_maps_to_coded_response() -> None:
    disp = Dispatcher()
    disp.register("demo.fail", _fail_rpc)
    resp = _decode(await disp.dispatch_bytes(b'{"jsonrpc":"2.0","id":5,"method":"demo.fail"}'))
    assert resp["error"]["code"] == ErrorCode.BOOLEAN_FAILED
    assert resp["error"]["data"] == {"reason": "degenerate"}


async def test_handler_unhandled_exception_becomes_internal_error() -> None:
    disp = Dispatcher()
    disp.register("demo.boom", _boom)
    resp = _decode(await disp.dispatch_bytes(b'{"jsonrpc":"2.0","id":1,"method":"demo.boom"}'))
    assert resp["error"]["code"] == ErrorCode.INTERNAL_ERROR
    assert resp["error"]["data"]["type"] == "RuntimeError"


async def test_notification_to_valid_handler_returns_none() -> None:
    disp = Dispatcher()
    disp.register("demo.echo", _echo)
    assert await disp.dispatch_bytes(b'{"jsonrpc":"2.0","method":"demo.echo","params":{}}') is None


async def test_registered_methods_sorted() -> None:
    disp = Dispatcher()
    disp.register("b", _echo)
    disp.register("a", _echo)
    assert disp.registered_methods() == ["a", "b"]


async def test_notification_in_failing_handler_returns_none() -> None:
    disp = Dispatcher()
    disp.register("demo.boom", _boom)
    assert await disp.dispatch_bytes(b'{"jsonrpc":"2.0","method":"demo.boom"}') is None
