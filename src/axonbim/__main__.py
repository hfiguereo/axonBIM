# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Entrypoint del backend: ``python -m axonbim``.

Arranca el servidor JSON-RPC. Flags:

* ``--socket-path PATH`` override del socket Unix (default ``$XDG_RUNTIME_DIR/axonbim.sock``).
* ``--tcp`` atajo: habilita TCP en el puerto default (``5799``) si no se da ``--tcp-port``.
* ``--tcp-host HOST`` direccion TCP (default ``127.0.0.1``).
* ``--tcp-port PORT`` puerto TCP. Implica ``--tcp``. Default: TCP deshabilitado.
* ``--log-level LEVEL`` ``DEBUG`` | ``INFO`` | ``WARNING`` | ``ERROR``.
"""

from __future__ import annotations

import argparse
import asyncio
import logging
import sys
from pathlib import Path

from axonbim import __version__
from axonbim.handlers import ifc as ifc_handlers
from axonbim.handlers import project as project_handlers
from axonbim.handlers import system as system_handlers
from axonbim.logging_config import configure as configure_logging
from axonbim.rpc.dispatcher import Dispatcher
from axonbim.rpc.server import default_socket_path, serve

_log = logging.getLogger(__name__)

DEFAULT_TCP_PORT: int = 5799


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="axonbim",
        description="AxonBIM backend RPC server.",
        allow_abbrev=False,
    )
    parser.add_argument(
        "--socket-path",
        type=Path,
        default=None,
        help="Ruta del socket Unix (default: $XDG_RUNTIME_DIR/axonbim.sock).",
    )
    parser.add_argument(
        "--tcp",
        action="store_true",
        help=(
            f"Habilita TCP en el puerto default ({DEFAULT_TCP_PORT}). "
            "Use --tcp-port para sobreescribir."
        ),
    )
    parser.add_argument(
        "--tcp-host",
        default="127.0.0.1",
        help="Host TCP para clientes Godot (default: 127.0.0.1).",
    )
    parser.add_argument(
        "--tcp-port",
        type=int,
        default=None,
        help=(
            "Puerto TCP. Implica --tcp. Si se omite y --tcp tampoco, solo se habilita Unix socket."
        ),
    )
    parser.add_argument(
        "--log-level",
        default=None,
        help="Nivel de logging (DEBUG/INFO/WARNING/ERROR).",
    )
    parser.add_argument("--version", action="version", version=f"axonbim {__version__}")
    return parser


def _resolve_tcp_port(*, tcp_flag: bool, tcp_port: int | None) -> int | None:
    """Resuelve el puerto TCP final segun los flags pasados.

    Reglas:
        - ``--tcp-port`` siempre gana.
        - ``--tcp`` solo activa el puerto default ``DEFAULT_TCP_PORT``.
        - Sin nada: devuelve ``None`` (TCP deshabilitado).
    """
    if tcp_port is not None:
        return tcp_port
    if tcp_flag:
        return DEFAULT_TCP_PORT
    return None


def _build_dispatcher() -> Dispatcher:
    dispatcher = Dispatcher()
    system_handlers.register(dispatcher)
    ifc_handlers.register(dispatcher)
    project_handlers.register(dispatcher)
    return dispatcher


def main(argv: list[str] | None = None) -> int:
    """Punto de entrada CLI. Devuelve codigo de salida."""
    args = _build_parser().parse_args(argv if argv is not None else sys.argv[1:])
    configure_logging(args.log_level)

    dispatcher = _build_dispatcher()
    socket_path = args.socket_path or default_socket_path()
    tcp_port = _resolve_tcp_port(tcp_flag=args.tcp, tcp_port=args.tcp_port)

    _log.info(
        "AxonBIM backend %s, metodos: %s",
        __version__,
        ", ".join(dispatcher.registered_methods()),
    )

    try:
        asyncio.run(
            serve(
                dispatcher,
                socket_path,
                tcp_host=args.tcp_host,
                tcp_port=tcp_port,
            )
        )
    except KeyboardInterrupt:
        _log.info("Interrumpido por el usuario")
        return 130
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
