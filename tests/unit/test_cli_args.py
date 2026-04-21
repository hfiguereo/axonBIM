# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Tests del parser CLI de ``python -m axonbim`` (Sprint 1.0)."""

from __future__ import annotations

import pytest

from axonbim.__main__ import DEFAULT_TCP_PORT, _build_parser, _resolve_tcp_port


def test_parser_no_args_disables_tcp() -> None:
    args = _build_parser().parse_args([])
    assert args.tcp is False
    assert args.tcp_port is None
    assert _resolve_tcp_port(tcp_flag=args.tcp, tcp_port=args.tcp_port) is None


def test_parser_tcp_flag_uses_default_port() -> None:
    args = _build_parser().parse_args(["--tcp"])
    assert args.tcp is True
    assert args.tcp_port is None
    assert _resolve_tcp_port(tcp_flag=args.tcp, tcp_port=args.tcp_port) == DEFAULT_TCP_PORT


def test_parser_tcp_port_overrides_default() -> None:
    args = _build_parser().parse_args(["--tcp-port", "9000"])
    assert args.tcp is False
    assert args.tcp_port == 9000
    assert _resolve_tcp_port(tcp_flag=args.tcp, tcp_port=args.tcp_port) == 9000


def test_parser_tcp_and_tcp_port_combine() -> None:
    args = _build_parser().parse_args(["--tcp", "--tcp-port", "9001"])
    assert _resolve_tcp_port(tcp_flag=args.tcp, tcp_port=args.tcp_port) == 9001


def test_parser_rejects_ambiguous_abbreviations() -> None:
    """``--tcp`` debe ser literal: argparse no debe expandir a ``--tcp-host``/``--tcp-port``."""
    parser = _build_parser()
    with pytest.raises(SystemExit):
        parser.parse_args(["--tc", "5799"])
