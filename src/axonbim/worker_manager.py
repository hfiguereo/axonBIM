# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Gestión del subproceso Godot headless (worker JSON-RPC auxiliar).

El worker escucha en TCP loopback (puerto default ``5800``) y expone métodos
``worker.*`` documentados en ``docs/architecture/jsonrpc-protocol.md``. Python
actúa como cliente; ver ADR-0003.
"""

from __future__ import annotations

import asyncio
import contextlib
import json
import logging
import os
import shutil
from pathlib import Path
from typing import Any, Final, cast

from axonbim.rpc.framing import FramingError, read_message, write_message

_log = logging.getLogger(__name__)

DEFAULT_WORKER_PORT: Final[int] = 5800


def resolve_godot_binary() -> str | None:
    """Resuelve la ruta del ejecutable Godot 4.x.

    Orden: ``AXONBIM_GODOT_BIN``, luego ``godot4``, luego ``godot`` en ``PATH``.

    Returns:
        Ruta absoluta o ``None`` si no hay binario utilizable.
    """
    env_bin = os.environ.get("AXONBIM_GODOT_BIN", "").strip()
    if env_bin:
        p = Path(env_bin)
        if p.is_file():
            return str(p.resolve())
    for name in ("godot4", "godot"):
        found = shutil.which(name)
        if found:
            return found
    return None


def resolve_worker_port() -> int:
    """Lee ``AXONBIM_WORKER_PORT`` o devuelve ``DEFAULT_WORKER_PORT``."""
    raw = os.environ.get("AXONBIM_WORKER_PORT", "").strip()
    if not raw:
        return DEFAULT_WORKER_PORT
    try:
        port = int(raw)
    except ValueError:
        return DEFAULT_WORKER_PORT
    return port if port > 0 else DEFAULT_WORKER_PORT


class WorkerManager:
    """Arranca y detiene el proceso Godot worker (headless)."""

    def __init__(
        self,
        *,
        frontend_dir: Path,
        port: int | None = None,
        godot_bin: str | None = None,
    ) -> None:
        """Inicializa el gestor sin arrancar el subproceso aún.

        Args:
            frontend_dir: Directorio del proyecto Godot (contiene ``project.godot``).
            port: Puerto TCP del worker; default desde :func:`resolve_worker_port`.
            godot_bin: Ejecutable explícito; si es ``None`` se usa :func:`resolve_godot_binary`.
        """
        self._frontend_dir = frontend_dir.resolve()
        self._port = port if port is not None else resolve_worker_port()
        self._godot_bin = godot_bin or resolve_godot_binary()
        self._proc: asyncio.subprocess.Process | None = None

    @property
    def port(self) -> int:
        """Puerto TCP en el que escucha el worker una vez arrancado."""
        return self._port

    async def start(self) -> None:
        """Arranca ``godot --headless`` con la escena ``worker_host.tscn``.

        Raises:
            RuntimeError: Si no hay binario Godot o el proceso termina al iniciar.
        """
        if self._proc is not None:
            return
        if self._godot_bin is None:
            msg = "No hay binario Godot (fije AXONBIM_GODOT_BIN o instale godot en PATH)."
            raise RuntimeError(msg)
        scene = "res://scenes/worker/worker_host.tscn"
        env = os.environ.copy()
        env["AXONBIM_WORKER_PORT"] = str(self._port)
        _log.info(
            "Arrancando Godot worker (%s) --path %s %s",
            self._godot_bin,
            self._frontend_dir,
            scene,
        )
        self._proc = await asyncio.create_subprocess_exec(
            self._godot_bin,
            "--headless",
            "--path",
            str(self._frontend_dir),
            scene,
            env=env,
            stdout=asyncio.subprocess.DEVNULL,
            stderr=asyncio.subprocess.DEVNULL,
        )
        await self._wait_until_responds(timeout_s=12.0)
        if self._proc.returncode is not None:
            raise RuntimeError(f"Godot worker terminó al iniciar (código {self._proc.returncode})")

    async def _wait_until_responds(self, *, timeout_s: float) -> None:
        """Espera a que ``worker.ping`` responda en loopback."""
        loop = asyncio.get_running_loop()
        deadline = loop.time() + timeout_s
        last_exc: BaseException | None = None
        while loop.time() < deadline:
            if self._proc is not None and self._proc.returncode is not None:
                return
            try:
                res = await self.call_worker_rpc("worker.ping", {}, msg_id=1)
                if res.get("result", {}).get("pong") is True:
                    return
            except (OSError, ConnectionError, TimeoutError, FramingError, json.JSONDecodeError) as exc:
                last_exc = exc
            await asyncio.sleep(0.12)
        msg = f"Worker no respondió a tiempo: {last_exc!r}"
        raise TimeoutError(msg) from last_exc

    async def stop(self) -> None:
        """Envía SIGTERM al worker y espera cierre; SIGKILL si no termina."""
        if self._proc is None:
            return
        proc = self._proc
        self._proc = None
        if proc.returncode is not None:
            return
        with contextlib.suppress(ProcessLookupError):
            proc.terminate()
        try:
            await asyncio.wait_for(proc.wait(), timeout=4.0)
        except TimeoutError:
            _log.warning("Worker no terminó a tiempo; SIGKILL")
            with contextlib.suppress(ProcessLookupError):
                proc.kill()
            with contextlib.suppress(ProcessLookupError):
                await proc.wait()

    async def call_worker_rpc(
        self,
        method: str,
        params: dict[str, Any],
        *,
        msg_id: int = 1,
    ) -> dict[str, Any]:
        """Invoca un método JSON-RPC en el worker (una conexión por llamada).

        Args:
            method: Nombre completo, p. ej. ``worker.ping``.
            params: Objeto ``params`` (puede ser vacío).
            msg_id: Identificador JSON-RPC.

        Returns:
            Diccionario parseado del cuerpo JSON de la respuesta.

        Raises:
            ConnectionError: Si no se puede conectar.
            FramingError: Si el encuadre LSP falla.
            json.JSONDecodeError: Si el cuerpo no es JSON válido.
        """
        payload = {"jsonrpc": "2.0", "id": msg_id, "method": method, "params": params}
        reader, writer = await asyncio.open_connection("127.0.0.1", self._port)
        try:
            await write_message(writer, json.dumps(payload).encode("utf-8"))
            body = await asyncio.wait_for(read_message(reader), timeout=8.0)
            if body is None:
                raise ConnectionError("EOF antes de respuesta del worker")
            return cast(dict[str, Any], json.loads(body.decode("utf-8")))
        finally:
            writer.close()
            await writer.wait_closed()

