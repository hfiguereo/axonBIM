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


def _logical_face_topo_ids(mesh: Mesh) -> list[str]:
    """Devuelve un ``topo_id`` por cara lógica de malla caja."""
    return [mesh.topo_ids[i] for i in range(0, len(mesh.topo_ids), 2)]


def _topo_map_between(before: Mesh | None, after: Mesh) -> dict[str, str]:
    """Mapea caras lógicas cuando una restauración de historial cambia hashes."""
    if before is None:
        return {}
    before_faces = _logical_face_topo_ids(before)
    after_faces = _logical_face_topo_ids(after)
    topo_map: dict[str, str] = {}
    for old_id, new_id in zip(before_faces, after_faces, strict=False):
        if old_id != new_id:
            topo_map[old_id] = new_id
    return topo_map


def _snapshot_current_wall(guid: str) -> dict[str, Any]:
    spec = topo_registry.get_wall_spec(guid)
    mesh = topo_registry.mesh_for_guid(guid)
    if spec is None or mesh is None:
        return {}
    return {
        "guid": guid,
        "wall_spec": spec.to_dict(),
        "mesh": mesh.to_dict(),
    }


def _apply_wall_snapshot(data: dict[str, Any]) -> dict[str, Any]:
    guid = str(data["guid"])
    spec = WallSpec.from_dict(data["wall_spec"])
    mesh = Mesh.from_dict(data["mesh"])
    current_mesh = topo_registry.mesh_for_guid(guid)
    topo_map = _topo_map_between(current_mesh, mesh)
    session = get_session()
    wall_module.update_wall_geometry(session, guid, spec)
    topo_registry.replace_mesh(guid, mesh)
    topo_registry.update_wall_spec(guid, spec)
    return {"applied": True, "guid": guid, "mesh": mesh.to_dict(), "topo_map": topo_map}


async def undo(_params: dict[str, Any]) -> dict[str, Any]:
    """Deshace la ultima operacion apilada (hoy: ``extrude_face``)."""
    popped = history_store.pop_undo()
    if popped is None:
        return {"applied": False, "reason": "empty"}

    kind, data = popped
    if kind != "extrude_face":
        return {"applied": False, "reason": f"unsupported:{kind}"}

    redo_payload = _snapshot_current_wall(str(data["guid"]))
    result = _apply_wall_snapshot(data)
    if redo_payload:
        history_store.push_redo(kind, redo_payload)
    return result


async def redo(_params: dict[str, Any]) -> dict[str, Any]:
    """Reaplica la ultima operacion deshecha (hoy: ``extrude_face``)."""
    popped = history_store.pop_redo()
    if popped is None:
        return {"applied": False, "reason": "empty"}

    kind, data = popped
    if kind != "extrude_face":
        return {"applied": False, "reason": f"unsupported:{kind}"}

    undo_payload = _snapshot_current_wall(str(data["guid"]))
    result = _apply_wall_snapshot(data)
    if undo_payload:
        history_store.push_undo(kind, undo_payload, clear_redo=False)
    return result


def register(dispatcher: Dispatcher) -> None:
    """Registra metodos ``history.*``."""
    dispatcher.register("history.undo", undo)
    dispatcher.register("history.redo", redo)
