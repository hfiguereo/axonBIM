# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Servidor asyncio sobre socket Unix (preferido) o TCP loopback (para Godot).

Decision de transporte (Sprint 1.3 spike):

* **Unix socket** (``AF_UNIX``): transporte primario. Cliente: tests Python,
  herramientas CLI, futuros clientes nativos.
* **TCP loopback** (``127.0.0.1:<port>``): transporte para Godot 4.x, que no
  expone Unix sockets nativamente via ``StreamPeer``. El server puede escuchar
  en ambos simultaneamente si se especifican los dos.

Lifecycle:

1. Se eliminan sockets Unix stale.
2. ``asyncio.start_unix_server`` y/o ``asyncio.start_server``.
3. Por cada conexion, un coroutine lee-mensaje / dispatch / escribe-respuesta
   en loop hasta EOF.
4. SIGTERM o ``Dispatcher.shutdown_event`` paran todos los servidores limpiamente.
"""

from __future__ import annotations

import asyncio
import contextlib
import logging
import os
import signal
import tempfile
from pathlib import Path

from axonbim.rpc.dispatcher import Dispatcher
from axonbim.rpc.framing import FramingError, read_message, write_message

_log = logging.getLogger(__name__)


def default_socket_path() -> Path:
    """Devuelve ``$XDG_RUNTIME_DIR/axonbim.sock`` con fallback a tmpdir.

    En sistemas sin ``XDG_RUNTIME_DIR``, el nombre bajo el directorio temporal
    incluye un sufijo estable por usuario en Unix (``getuid``) y por proceso en
    Windows (``getpid``), donde ``getuid`` no existe.
    """
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    if runtime:
        return Path(runtime) / "axonbim.sock"
    unique = os.getuid() if hasattr(os, "getuid") else os.getpid()
    return Path(tempfile.gettempdir()) / f"axonbim-{unique}.sock"


async def _handle_connection(
    dispatcher: Dispatcher,
    reader: asyncio.StreamReader,
    writer: asyncio.StreamWriter,
) -> None:
    peer = writer.get_extra_info("peername") or "unix"
    _log.info("Cliente conectado: %s", peer)

    try:
        while True:
            try:
                body = await read_message(reader)
            except asyncio.IncompleteReadError:
                _log.info("Cliente %s cerro la conexion (incomplete read)", peer)
                return
            except FramingError as exc:
                _log.warning("FramingError: %s", exc)
                return

            if body is None:
                _log.info("Cliente %s cerro la conexion (EOF limpio)", peer)
                return

            response = await dispatcher.dispatch_bytes(body)
            if response is not None:
                try:
                    await write_message(writer, response)
                except (ConnectionError, BrokenPipeError):
                    _log.info("Cliente %s desconectado durante escritura", peer)
                    return
    finally:
        writer.close()
        with contextlib.suppress(ConnectionError, BrokenPipeError):
            await writer.wait_closed()


async def serve(
    dispatcher: Dispatcher,
    socket_path: Path | None = None,
    *,
    tcp_host: str | None = None,
    tcp_port: int | None = None,
    install_signal_handlers: bool = True,
) -> None:
    """Arranca servidor(es) RPC. Bloquea hasta ``shutdown_event`` o senal.

    Parametros
    ----------
    socket_path
        Path Unix. Si es ``None`` se usa :func:`default_socket_path`. Para
        deshabilitar Unix socket, pasar ``socket_path`` y ``tcp_port`` donde
        ``socket_path == Path()`` (se interpreta como sentinel no usable)
        -- en practica, usar :func:`serve_tcp` directamente o pasar
        ``tcp_port`` cuando ``socket_path`` es ``None`` es suficiente porque
        ambos pueden coexistir.
    tcp_host, tcp_port
        Si ``tcp_port`` se especifica, se abre tambien un listener TCP en
        ``tcp_host:tcp_port`` (default host: ``127.0.0.1``).

    En plataformas sin ``asyncio.start_unix_server`` (p. ej. Windows), solo
    se arranca TCP; hace falta ``tcp_port`` no nulo.
    """
    servers: list[asyncio.base_events.Server] = []
    unix_capable = hasattr(asyncio, "start_unix_server")
    unix_path: Path | None = None
    if unix_capable:
        candidate = socket_path if socket_path is not None else default_socket_path()
        if candidate != Path():
            unix_path = candidate

    if unix_path is not None:
        _prepare_unix_socket_path(unix_path)
        servers.append(
            await asyncio.start_unix_server(
                lambda r, w: _handle_connection(dispatcher, r, w),
                path=str(unix_path),
            )
        )
        _log.info("Servidor RPC Unix escuchando en %s", unix_path)

    if tcp_port is not None:
        host = tcp_host or "127.0.0.1"
        servers.append(
            await asyncio.start_server(
                lambda r, w: _handle_connection(dispatcher, r, w),
                host=host,
                port=tcp_port,
            )
        )
        _log.info("Servidor RPC TCP escuchando en %s:%d", host, tcp_port)

    if not servers:
        raise RuntimeError(
            "No hay transporte RPC activo: en esta plataforma use TCP "
            "(p. ej. `python -m axonbim --tcp` o `--tcp-port 5799`)."
        )

    _install_signal_handlers_if_requested(dispatcher, install_signal_handlers)

    try:
        await _wait_servers(servers, dispatcher.shutdown_event)
    finally:
        if unix_path is not None:
            try:
                unix_path.unlink(missing_ok=True)
            except OSError as exc:
                _log.warning("No pude eliminar socket %s: %s", unix_path, exc)
        _log.info("Servidor RPC detenido")


def _prepare_unix_socket_path(path: Path) -> None:
    if path.exists() or path.is_symlink():
        _log.warning("Socket existente eliminado: %s", path)
        path.unlink()
    path.parent.mkdir(parents=True, exist_ok=True)


def _install_signal_handlers_if_requested(dispatcher: Dispatcher, install: bool) -> None:
    if not install:
        return
    loop = asyncio.get_running_loop()
    for sig in (signal.SIGTERM, signal.SIGINT):
        try:
            loop.add_signal_handler(sig, dispatcher.shutdown_event.set)
        except NotImplementedError:
            _log.debug("Signal handler %s no soportado en esta plataforma", sig)


async def _wait_servers(
    servers: list[asyncio.base_events.Server],
    shutdown_event: asyncio.Event,
) -> None:
    async with contextlib.AsyncExitStack() as stack:
        for server in servers:
            await stack.enter_async_context(server)

        wait_shutdown = asyncio.create_task(shutdown_event.wait())
        wait_close = [asyncio.create_task(server.serve_forever()) for server in servers]
        _, pending = await asyncio.wait(
            {wait_shutdown, *wait_close},
            return_when=asyncio.FIRST_COMPLETED,
        )
        for task in pending:
            task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await task
