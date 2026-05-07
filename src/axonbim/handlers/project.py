# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Handlers del dominio ``project.*``.

Incluye ``project.save``, ``project.open``, gestión de **niveles** ``IfcBuildingStorey`` (lista, crear,
activo) y transiciones ISO 19650 (WIP/Shared/…) para Fase 4.
"""

from __future__ import annotations

import logging
from pathlib import Path
from typing import Any

from pydantic import BaseModel, ConfigDict, Field

from axonbim.geometry import topo_registry
from axonbim.history import sqlite_store as history_store
from axonbim.ifc import wall_import
from axonbim.ifc.session import IfcSession, get_session, install_session
from axonbim.rpc.dispatcher import Dispatcher, RpcError
from axonbim.rpc.models import ErrorCode

_log = logging.getLogger(__name__)


def _storey_elevation_m(st: Any) -> float:
    raw = getattr(st, "Elevation", None)
    return float(raw) if raw is not None else 0.0


class EmptyParams(BaseModel):
    """Cuerpo vacío para métodos RPC sin argumentos."""

    model_config = ConfigDict(extra="forbid")


class SaveParams(BaseModel):
    """Parametros de ``project.save``: ruta destino en el filesystem local."""

    model_config = ConfigDict(extra="forbid")

    path: str


class CreateStoreyParams(BaseModel):
    """Parametros de ``project.create_storey``."""

    model_config = ConfigDict(extra="forbid")

    name: str = Field(min_length=1, max_length=128, description="Nombre visible del nivel.")
    elevation_m: float = Field(description="Cota Z del forjado en metros (IfcBuildingStorey.Elevation).")


class SetActiveStoreyParams(BaseModel):
    """Parametros de ``project.set_active_storey``."""

    model_config = ConfigDict(extra="forbid")

    guid: str = Field(min_length=1, description="GlobalId del IfcBuildingStorey.")


class OpenParams(BaseModel):
    """Parametros de ``project.open``: ruta de un ``.ifc`` existente en disco local."""

    model_config = ConfigDict(extra="forbid")

    path: str


async def save(params: dict[str, Any]) -> dict[str, Any]:
    """Handler de ``project.save``: serializa la sesion IFC activa a ``path``.

    Raises:
        RpcError: con ``INTERNAL_ERROR`` si el filesystem rechaza la escritura.
    """
    args = SaveParams.model_validate(params)
    target = Path(args.path).expanduser()

    session = get_session()
    try:
        session.save(target)
    except OSError as exc:
        raise RpcError(
            ErrorCode.INTERNAL_ERROR, f"No pude escribir IFC: {exc}", {"path": str(target)}
        ) from exc

    size = target.stat().st_size
    _log.info("Proyecto guardado: %s (%d bytes)", target, size)
    history_store.set_scope(str(target.resolve()))
    return {"path": str(target), "bytes": size}


async def list_storeys(params: dict[str, Any] | None) -> dict[str, Any]:
    """Lista niveles del edificio activo y marca el que recibe nuevos elementos."""
    raw: dict[str, Any] = params if isinstance(params, dict) else {}
    EmptyParams.model_validate(raw)
    session = get_session()
    active = str(session.storey.GlobalId)
    rows: list[dict[str, Any]] = []
    for st in session.list_storeys_ordered():
        gid = str(st.GlobalId)
        rows.append(
            {
                "guid": gid,
                "name": str(st.Name or ""),
                "elevation_m": _storey_elevation_m(st),
                "is_active": gid == active,
            }
        )
    return {"storeys": rows}


async def create_storey(params: dict[str, Any]) -> dict[str, Any]:
    """Crea un ``IfcBuildingStorey`` bajo el edificio de la sesión."""
    args = CreateStoreyParams.model_validate(params)
    session = get_session()
    st = session.create_storey(args.name, args.elevation_m)
    return {
        "guid": str(st.GlobalId),
        "name": str(st.Name or ""),
        "elevation_m": _storey_elevation_m(st),
    }


async def set_active_storey(params: dict[str, Any]) -> dict[str, Any]:
    """Fija el nivel activo (contenedor de nuevos muros y similares)."""
    args = SetActiveStoreyParams.model_validate(params)
    session = get_session()
    try:
        session.set_active_storey(args.guid)
    except ValueError as exc:
        raise RpcError(ErrorCode.INVALID_PARAMS, str(exc), {}) from exc
    return {
        "ok": True,
        "guid": str(session.storey.GlobalId),
        "elevation_m": _storey_elevation_m(session.storey),
    }


async def open_ifc(params: dict[str, Any]) -> dict[str, Any]:
    """Carga un ``.ifc`` desde disco, reemplaza la sesión y rehidrata muros AxonBIM.

    Los ``IfcWall`` cuya geometría no coincide con el patrón caja+extrusión vertical
    se omiten (``walls_skipped``). El historial SQLite se vacía y el ámbito pasa a
    la ruta canónica del archivo abierto.

    Args:
        params: ``{ "path": "<ruta .ifc>" }``.

    Returns:
        Diccionario con ``path``, ``wall_count``, ``walls_skipped``, ``walls``
        (lista de ``guid`` + ``mesh``), ``storeys`` (como ``list_storeys``) y
        ``workspace_xy_half_m``.

    Raises:
        RpcError: ``INVALID_PARAMS`` si la ruta no existe o el IFC carece de
        jerarquía espacial mínima.
    """
    args = OpenParams.model_validate(params)
    target = Path(args.path).expanduser().resolve()
    if not target.is_file():
        raise RpcError(
            ErrorCode.INVALID_PARAMS,
            f"No existe el archivo IFC: {target}",
            {"path": str(target)},
        )
    try:
        session = IfcSession.open_existing(target)
    except FileNotFoundError as exc:
        raise RpcError(ErrorCode.INVALID_PARAMS, str(exc), {}) from exc
    except ValueError as exc:
        raise RpcError(ErrorCode.INVALID_PARAMS, str(exc), {}) from exc

    install_session(session, history_scope=str(target.resolve()))
    session.workspace_xy.half_x_m = 50.0
    session.workspace_xy.half_y_m = 50.0

    walls_payload: list[dict[str, Any]] = []
    skipped = 0
    for w in session.file.by_type("IfcWall"):
        parsed = wall_import.wall_spec_mesh_from_ifc_wall(session.file, w)
        if parsed is None:
            skipped += 1
            continue
        spec, mesh = parsed
        guid = str(w.GlobalId)
        topo_registry.register_mesh(guid, mesh)
        topo_registry.register_wall_spec(guid, spec)
        session.workspace_xy.ensure_contains_segment_plan(
            spec.p1[0], spec.p1[1], spec.p2[0], spec.p2[1]
        )
        walls_payload.append({"guid": guid, "mesh": mesh.to_dict()})

    active = str(session.storey.GlobalId)
    storeys_rows: list[dict[str, Any]] = []
    for st in session.list_storeys_ordered():
        gid = str(st.GlobalId)
        storeys_rows.append(
            {
                "guid": gid,
                "name": str(st.Name or ""),
                "elevation_m": _storey_elevation_m(st),
                "is_active": gid == active,
            }
        )

    return {
        "path": str(target),
        "wall_count": len(walls_payload),
        "walls_skipped": skipped,
        "walls": walls_payload,
        "storeys": storeys_rows,
        "workspace_xy_half_m": session.workspace_xy.as_half_list_m(),
    }


def register(dispatcher: Dispatcher) -> None:
    """Registra todos los metodos ``project.*``."""
    dispatcher.register("project.save", save)
    dispatcher.register("project.open", open_ifc)
    dispatcher.register("project.list_storeys", list_storeys)
    dispatcher.register("project.create_storey", create_storey)
    dispatcher.register("project.set_active_storey", set_active_storey)
