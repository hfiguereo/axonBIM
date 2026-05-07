# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Pruebas unitarias del gestor del proceso Godot worker."""

from __future__ import annotations

import os
from pathlib import Path

import pytest

from axonbim.worker_manager import WorkerManager, resolve_godot_binary, resolve_worker_port


@pytest.mark.asyncio
async def test_worker_manager_stop_without_start_is_safe() -> None:
    """``stop`` sin ``start`` no debe lanzar."""
    wm = WorkerManager(frontend_dir=Path("/tmp"), godot_bin="/nonexistent")
    await wm.stop()


def test_resolve_worker_port_env(monkeypatch: pytest.MonkeyPatch) -> None:
    """``AXONBIM_WORKER_PORT`` numérico redefine el puerto."""
    monkeypatch.setenv("AXONBIM_WORKER_PORT", "5920")
    assert resolve_worker_port() == 5920


def test_resolve_worker_port_invalid_falls_back(monkeypatch: pytest.MonkeyPatch) -> None:
    """Valor no numérico cae al default documentado."""
    monkeypatch.setenv("AXONBIM_WORKER_PORT", "oops")
    assert resolve_worker_port() == 5800


@pytest.mark.asyncio
async def test_worker_smoke_ping_when_godot_present() -> None:
    """Ciclo de vida real: solo con ``AXONBIM_RUN_GODOT_WORKER_TEST=1`` y Godot en PATH."""
    if os.environ.get("AXONBIM_RUN_GODOT_WORKER_TEST", "").lower() not in ("1", "true", "yes"):
        pytest.skip("Prueba opt-in: AXONBIM_RUN_GODOT_WORKER_TEST=1")
    if resolve_godot_binary() is None:
        pytest.skip("Sin binario Godot (PATH / AXONBIM_GODOT_BIN).")
    repo = Path(__file__).resolve().parents[2]
    frontend = repo / "frontend"
    wm = WorkerManager(frontend_dir=frontend)
    try:
        await wm.start()
        raw = await wm.call_worker_rpc("worker.ping", {})
        assert raw.get("result", {}).get("pong") is True
        hit = await wm.call_worker_rpc(
            "worker.aabb_intersects",
            {
                "a_min": [0.0, 0.0, 0.0],
                "a_max": [1.0, 1.0, 1.0],
                "b_min": [0.5, 0.5, 0.5],
                "b_max": [1.5, 1.5, 1.5],
            },
        )
        assert hit.get("result", {}).get("intersects") is True
    finally:
        await wm.stop()
