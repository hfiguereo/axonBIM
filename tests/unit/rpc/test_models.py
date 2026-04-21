# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Tests de los modelos Pydantic del protocolo."""

from __future__ import annotations

import pytest
from pydantic import ValidationError

from axonbim.rpc.models import (
    ErrorCode,
    Notification,
    Request,
    make_error,
    make_success,
)


def test_request_with_id_is_not_notification() -> None:
    req = Request(jsonrpc="2.0", id=1, method="system.ping", params={})
    assert not req.is_notification
    assert req.id == 1


def test_request_without_id_is_notification() -> None:
    req = Request(jsonrpc="2.0", method="project.autosave_done", params={})
    assert req.is_notification


def test_request_default_params_is_empty_dict() -> None:
    req = Request(jsonrpc="2.0", id="a", method="system.ping")
    assert req.params == {}


def test_request_rejects_unknown_fields() -> None:
    with pytest.raises(ValidationError):
        Request.model_validate({"jsonrpc": "2.0", "id": 1, "method": "x", "extra_field": True})


def test_request_rejects_wrong_jsonrpc_value() -> None:
    with pytest.raises(ValidationError):
        Request.model_validate({"jsonrpc": "1.0", "id": 1, "method": "x"})


def test_request_accepts_string_id() -> None:
    req = Request.model_validate({"jsonrpc": "2.0", "id": "abc", "method": "x"})
    assert req.id == "abc"


def test_make_error_helper() -> None:
    err = make_error(42, ErrorCode.METHOD_NOT_FOUND, "missing")
    payload = err.model_dump()
    assert payload["jsonrpc"] == "2.0"
    assert payload["id"] == 42
    assert payload["error"]["code"] == -32601
    assert payload["error"]["message"] == "missing"


def test_make_success_helper() -> None:
    ok = make_success(7, {"a": 1})
    payload = ok.model_dump()
    assert payload["id"] == 7
    assert payload["result"] == {"a": 1}


def test_error_codes_stable_values() -> None:
    assert ErrorCode.PARSE_ERROR == -32700
    assert ErrorCode.INVALID_REQUEST == -32600
    assert ErrorCode.METHOD_NOT_FOUND == -32601
    assert ErrorCode.INVALID_PARAMS == -32602
    assert ErrorCode.INTERNAL_ERROR == -32603
    assert ErrorCode.IFC_PARSE_ERROR == -32000
    assert ErrorCode.BOOLEAN_FAILED == -32001
    assert ErrorCode.TOPO_ID_NOT_FOUND == -32002
    assert ErrorCode.STATE_TRANSITION_INVALID == -32003
    assert ErrorCode.MIVED_SPEC_MISSING == -32004
    assert ErrorCode.OPERATION_TIMEOUT == -32005
    assert ErrorCode.BUSY == -32006
    assert ErrorCode.LOIN_INCOMPLETE == -32007
    assert ErrorCode.CONTAINER_IMMUTABLE == -32008


def test_notification_has_no_id() -> None:
    note = Notification(method="system.warning", params={"level": "info"})
    payload = note.model_dump(exclude_none=True)
    assert "id" not in payload
    assert payload["method"] == "system.warning"
