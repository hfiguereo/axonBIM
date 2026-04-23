# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Handlers ``history.*`` (deshacer operaciones mutantes)."""

from __future__ import annotations

from typing import Any

from axonbim.geometry import topo_registry
from axonbim.geometry.meshing import Mesh
from axonbim.geometry.wall_spec import WallSpec
from axonbim.history import sqlite_store as history_store
from axonbim.ifc import wall as wall_module
from axonbim.ifc.session import get_session
from axonbim.rpc.dispatcher import Dispatcher


async def undo(_params: dict[str, Any]) -> dict[str, Any]:
    """Deshace la ultima operacion apilada (hoy: ``extrude_face``)."""
    popped = history_store.pop_undo()
    if popped is None:
        return {"applied": False, "reason": "empty"}

    kind, data = popped
    if kind != "extrude_face":
        return {"applied": False, "reason": f"unsupported:{kind}"}

    guid = str(data["guid"])
    spec = WallSpec.from_dict(data["wall_spec"])
    mesh = Mesh.from_dict(data["mesh"])
    session = get_session()
    wall_module.update_wall_geometry(session, guid, spec)
    topo_registry.replace_mesh(guid, mesh)
    topo_registry.update_wall_spec(guid, spec)
    return {"applied": True, "guid": guid, "mesh": mesh.to_dict(), "topo_map": {}}


def register(dispatcher: Dispatcher) -> None:
    """Registra metodos ``history.*``."""
    dispatcher.register("history.undo", undo)
