# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Tests del historial ampliado (create/delete/typology) y ámbito por IFC."""

from __future__ import annotations

import pytest

from axonbim.geometry import topo_registry
from axonbim.handlers import history as history_handlers
from axonbim.handlers import ifc as ifc_handlers
from axonbim.history import sqlite_store as history_store
from axonbim.ifc.session import reset_session


@pytest.fixture(autouse=True)
def _fresh() -> None:
    reset_session()


@pytest.mark.asyncio
async def test_undo_create_wall_removes_wall() -> None:
    out = await ifc_handlers.create_wall(
        {
            "p1": {"x": 0.0, "y": 0.0},
            "p2": {"x": 4.0, "y": 0.0},
            "height": 3.0,
            "thickness": 0.2,
        }
    )
    guid = str(out["guid"])
    assert topo_registry.get_wall_spec(guid) is not None
    u = await history_handlers.undo({})
    assert u["applied"] is True
    assert topo_registry.get_wall_spec(guid) is None
    r = await history_handlers.redo({})
    assert r["applied"] is True
    assert topo_registry.get_wall_spec(guid) is not None


@pytest.mark.asyncio
async def test_undo_delete_wall_restores_wall() -> None:
    out = await ifc_handlers.create_wall(
        {
            "p1": {"x": 0.0, "y": 0.0},
            "p2": {"x": 2.0, "y": 0.0},
            "height": 3.0,
            "thickness": 0.2,
        }
    )
    guid = str(out["guid"])
    await ifc_handlers.delete_product({"guid": guid})
    assert topo_registry.get_wall_spec(guid) is None
    u = await history_handlers.undo({})
    assert u["applied"] is True
    assert topo_registry.get_wall_spec(guid) is not None
    r = await history_handlers.redo({})
    assert r["applied"] is True
    assert topo_registry.get_wall_spec(guid) is None


@pytest.mark.asyncio
async def test_undo_set_wall_typology_restores_dimensions() -> None:
    out = await ifc_handlers.create_wall(
        {
            "p1": {"x": 0.0, "y": 0.0},
            "p2": {"x": 3.0, "y": 0.0},
            "height": 3.0,
            "thickness": 0.2,
        }
    )
    guid = str(out["guid"])
    await ifc_handlers.set_wall_typology({"guid": guid, "height": 4.0, "thickness": 0.3})
    spec = topo_registry.get_wall_spec(guid)
    assert spec is not None
    assert spec.height == pytest.approx(4.0)
    u = await history_handlers.undo({})
    assert u["applied"] is True
    spec2 = topo_registry.get_wall_spec(guid)
    assert spec2 is not None
    assert spec2.height == pytest.approx(3.0)


def test_history_scope_isolation(monkeypatch: pytest.MonkeyPatch, tmp_path) -> None:
    """Pilas separadas por ``set_scope`` (mismo fichero SQLite)."""
    db = tmp_path / "scoped.db"
    monkeypatch.setenv("AXONBIM_HISTORY_DB", str(db))
    history_store.close_for_tests()
    history_store.set_scope("path_a.ifc")
    history_store.push_undo("create_wall", {"guid": "only-a"}, clear_redo=True)
    history_store.set_scope("path_b.ifc")
    assert history_store.pop_undo() is None
    history_store.set_scope("path_a.ifc")
    popped = history_store.pop_undo()
    assert popped is not None
    assert popped[0] == "create_wall"
