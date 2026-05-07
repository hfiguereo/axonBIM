# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Handlers del dominio ``ifc.*``: creacion y consulta de entidades IFC.

Incluye ``ifc.create_wall``, lectura de ``WallSpec`` y actualizacion por tipologia.
"""

from __future__ import annotations

import math
from typing import Any

from pydantic import BaseModel, ConfigDict, Field

from axonbim.geometry import topo_registry
from axonbim.geometry.topology import Vec3
from axonbim.geometry.wall_spec import WallSpec
from axonbim.history import recording
from axonbim.history import sqlite_store as history_store
from axonbim.ifc import wall as wall_module
from axonbim.ifc.session import get_session
from axonbim.rpc.dispatcher import Dispatcher, RpcError
from axonbim.rpc.models import ErrorCode


class _Point3(BaseModel):
    """Punto 3D en coordenadas de mundo (metros). ``z`` por defecto = 0.0."""

    model_config = ConfigDict(extra="forbid")

    x: float
    y: float
    z: float = 0.0

    def as_tuple(self) -> Vec3:
        """Proyeccion a la tupla ``Vec3`` usada por el backend geometrico."""
        return (self.x, self.y, self.z)


class CreateWallParams(BaseModel):
    """Parametros del metodo RPC ``ifc.create_wall``."""

    model_config = ConfigDict(extra="forbid")

    p1: _Point3
    p2: _Point3
    height: float = Field(gt=0.0, description="Altura en metros (> 0).")
    thickness: float = Field(gt=0.0, description="Grosor en metros (> 0).")
    name: str | None = None
    join_with_guid: str | None = Field(
        default=None,
        description="GUID previo opcional para auto-cierre de esquina en cadena.",
    )
    join_end_guid: str | None = Field(
        default=None,
        description=(
            "GUID del primer muro del contorno cuando ``p2`` cierra el polígono en su ``p1``; "
            "ajuste simétrico al de ``join_with_guid`` en el extremo final."
        ),
    )


_CHAIN_JOIN_EPS_M: float = 1e-4
_CHAIN_PERP_DOT_MAX: float = 0.15
_DIR_NORM_EPS_M: float = 1e-9


def _wall_history_snapshot(guid: str) -> dict[str, Any]:
    """Serializa muro actual para la pila de deshacer (vacío si no está indexado)."""
    spec = topo_registry.get_wall_spec(guid)
    mesh = topo_registry.mesh_for_guid(guid)
    if spec is None or mesh is None:
        return {}
    return {
        "guid": guid,
        "wall_spec": spec.to_dict(),
        "mesh": mesh.to_dict(),
    }


def _normalize_xy(dx: float, dy: float) -> tuple[float, float] | None:
    length: float = math.hypot(dx, dy)
    if length < _DIR_NORM_EPS_M:
        return None
    return (dx / length, dy / length)


def _adjust_corner_closure_if_chain(
    args: CreateWallParams,
) -> tuple[Vec3, Vec3]:
    """Ajusta ``p1`` en giros ~90° para reducir hueco perceptual en la esquina.

    Regla aplicada solo si:
    - ``join_with_guid`` existe en el registro,
    - ``prev.p2`` coincide con ``new.p1`` (tolerancia pequeña),
    - el ángulo entre ejes es cercano a perpendicular.

    El ajuste extiende ``new.p1`` medio espesor efectivo hacia atrás del eje
    del nuevo muro, cerrando visualmente la unión en cadena.
    """
    p1: Vec3 = args.p1.as_tuple()
    p2: Vec3 = args.p2.as_tuple()
    if not args.join_with_guid:
        return (p1, p2)
    prev: WallSpec | None = topo_registry.get_wall_spec(args.join_with_guid)
    if prev is None:
        return (p1, p2)
    if abs(prev.p2[0] - p1[0]) > _CHAIN_JOIN_EPS_M or abs(prev.p2[1] - p1[1]) > _CHAIN_JOIN_EPS_M:
        return (p1, p2)

    prev_dir = _normalize_xy(prev.p2[0] - prev.p1[0], prev.p2[1] - prev.p1[1])
    new_dir = _normalize_xy(p2[0] - p1[0], p2[1] - p1[1])
    if prev_dir is None or new_dir is None:
        return (p1, p2)
    dot_abs: float = abs(prev_dir[0] * new_dir[0] + prev_dir[1] * new_dir[1])
    if dot_abs > _CHAIN_PERP_DOT_MAX:
        return (p1, p2)

    effective_t: float = max(0.01, min(args.thickness, prev.thickness))
    back: float = effective_t * 0.5
    p1_adjusted: Vec3 = (
        p1[0] - new_dir[0] * back,
        p1[1] - new_dir[1] * back,
        p1[2],
    )
    return (p1_adjusted, p2)


def _adjust_loop_closure_at_p2(
    p1: Vec3,
    p2: Vec3,
    args: CreateWallParams,
) -> tuple[Vec3, Vec3]:
    """Extiende ``p2`` medio espesor en giros ~90° al coincidir con el ``p1`` del muro inicial.

    Cierra el hueco visual en la última esquina al volver al primer vértice del contorno
    (habitación rectangular u poligonal ortogonal). Requiere ``join_end_guid`` registrado y
    ``p2`` alineado con ``first.p1`` en planta.

    Args:
        p1: Inicio del muro nuevo (posiblemente ya ajustado por cadena).
        p2: Fin nominal del muro nuevo (debe coincidir con el ``p1`` del muro de cierre).
        args: Parámetros RPC; usa ``join_end_guid`` y ``thickness``.

    Returns:
        ``(p1, p2)`` con ``p2`` extendido sobre el eje del segmento si aplica.

    Raises:
        RpcError: Si ``join_end_guid`` no resuelve un muro o ``p2`` no encaja en el cierre.
    """
    if not args.join_end_guid:
        return (p1, p2)
    first: WallSpec | None = topo_registry.get_wall_spec(args.join_end_guid)
    if first is None:
        raise RpcError(
            ErrorCode.INVALID_PARAMS,
            f"join_end_guid no registrado: {args.join_end_guid!r}",
        )
    if abs(first.p1[0] - p2[0]) > _CHAIN_JOIN_EPS_M or abs(first.p1[1] - p2[1]) > _CHAIN_JOIN_EPS_M:
        raise RpcError(
            ErrorCode.INVALID_PARAMS,
            "join_end_guid: p2 debe coincidir con el p1 del muro indicado (cierre de contorno).",
        )
    first_dir = _normalize_xy(first.p2[0] - first.p1[0], first.p2[1] - first.p1[1])
    new_dir = _normalize_xy(p2[0] - p1[0], p2[1] - p1[1])
    if first_dir is None or new_dir is None:
        raise RpcError(
            ErrorCode.INVALID_PARAMS,
            "join_end_guid: dirección del segmento o del muro inicial degenerada.",
        )
    dot_abs: float = abs(first_dir[0] * new_dir[0] + first_dir[1] * new_dir[1])
    if dot_abs > _CHAIN_PERP_DOT_MAX:
        raise RpcError(
            ErrorCode.INVALID_PARAMS,
            "join_end_guid: el cierre requiere esquina ~90° respecto al primer muro.",
        )
    effective_t: float = max(0.01, min(args.thickness, first.thickness))
    back: float = effective_t * 0.5
    p2_adjusted: Vec3 = (
        p2[0] + new_dir[0] * back,
        p2[1] + new_dir[1] * back,
        p2[2],
    )
    return (p1, p2_adjusted)


class GetWallSpecParams(BaseModel):
    """Parametros de ``ifc.get_wall_spec``."""

    model_config = ConfigDict(extra="forbid")

    guid: str = Field(min_length=1, description="GlobalId del IfcWall.")


class DeleteParams(BaseModel):
    """Parametros de ``ifc.delete``."""

    model_config = ConfigDict(extra="forbid")

    guid: str = Field(min_length=1, description="GlobalId del producto IFC a borrar.")


class SetWallTypologyParams(BaseModel):
    """Parametros de ``ifc.set_wall_typology``: nueva familia dimensional sin mover el eje."""

    model_config = ConfigDict(extra="forbid")

    guid: str = Field(min_length=1, description="GlobalId del IfcWall.")
    height: float = Field(gt=0.0, description="Nueva altura en metros.")
    thickness: float = Field(gt=0.0, description="Nuevo grosor en metros.")
    typology_id: str | None = Field(
        default=None,
        description="Identificador de tipologia en cliente (trazabilidad; opcional).",
    )


async def create_wall(params: dict[str, Any]) -> dict[str, Any]:
    """Handler de ``ifc.create_wall``: valida parametros, crea ``IfcWall`` y devuelve mesh.

    Returns:
        Diccionario con ``guid``, ``mesh`` y ``workspace_xy_half_m`` (lista de dos
        valores: media en X y media en Y desde el origen, en metros).

    Raises:
        RpcError: con codigo ``INVALID_PARAMS`` si la geometria es invalida.
    """
    args = CreateWallParams.model_validate(params)

    p1, p2 = _adjust_corner_closure_if_chain(args)
    p1, p2 = _adjust_loop_closure_at_p2(p1, p2, args)
    session = get_session()
    session.workspace_xy.ensure_contains_segment_plan(p1[0], p1[1], p2[0], p2[1])
    try:
        result = wall_module.create_wall(
            session,
            p1,
            p2,
            height=args.height,
            thickness=args.thickness,
            name=args.name,
        )
    except ValueError as exc:
        raise RpcError(ErrorCode.INVALID_PARAMS, str(exc)) from exc

    topo_registry.register_mesh(result.guid, result.mesh)
    topo_registry.register_wall_spec(
        result.guid,
        WallSpec(
            p1=p1,
            p2=p2,
            height=args.height,
            thickness=args.thickness,
        ),
    )
    if not recording.is_suppressed():
        history_store.push_undo(
            "create_wall",
            {"guid": result.guid},
            clear_redo=True,
        )
    return {
        "guid": result.guid,
        "mesh": result.mesh.to_dict(),
        "workspace_xy_half_m": session.workspace_xy.as_half_list_m(),
    }


async def get_wall_spec(params: dict[str, Any]) -> dict[str, Any]:
    """Devuelve el ``WallSpec`` registrado para un muro de la sesion."""
    args = GetWallSpecParams.model_validate(params)
    spec = topo_registry.get_wall_spec(args.guid)
    if spec is None:
        raise RpcError(
            ErrorCode.INVALID_PARAMS,
            f"No hay WallSpec para el guid {args.guid!r} (muro no creado en esta sesion o no indexado).",
        )
    return {"wall_spec": spec.to_dict()}


async def set_wall_typology(params: dict[str, Any]) -> dict[str, Any]:
    """Regenera geometria IFC y malla conservando el eje P1-P2 del muro."""
    args = SetWallTypologyParams.model_validate(params)
    old = topo_registry.get_wall_spec(args.guid)
    if old is None:
        raise RpcError(
            ErrorCode.INVALID_PARAMS,
            f"No hay WallSpec para el guid {args.guid!r}.",
        )
    mesh0 = topo_registry.mesh_for_guid(args.guid)
    if mesh0 is None:
        raise RpcError(
            ErrorCode.INVALID_PARAMS,
            f"No hay malla registrada para el guid {args.guid!r}.",
        )
    old_payload: dict[str, Any] = {
        "guid": args.guid,
        "wall_spec": old.to_dict(),
        "mesh": mesh0.to_dict(),
    }
    new_spec = WallSpec(
        p1=old.p1,
        p2=old.p2,
        height=args.height,
        thickness=args.thickness,
    )
    session = get_session()
    if not recording.is_suppressed():
        history_store.push_undo("set_wall_typology", old_payload, clear_redo=True)
    try:
        result = wall_module.update_wall_geometry(session, args.guid, new_spec)
    except ValueError as exc:
        raise RpcError(ErrorCode.INVALID_PARAMS, str(exc)) from exc

    topo_registry.replace_mesh(args.guid, result.mesh)
    topo_registry.update_wall_spec(args.guid, new_spec)
    return {"guid": args.guid, "mesh": result.mesh.to_dict()}


async def delete_product(params: dict[str, Any]) -> dict[str, Any]:
    """Elimina un ``IfcWall`` (u otro producto soportado por ``remove_product``) de la sesion."""
    args = DeleteParams.model_validate(params)
    snap = _wall_history_snapshot(args.guid)
    if snap and not recording.is_suppressed():
        history_store.push_undo("delete_wall", snap, clear_redo=True)
    session = get_session()
    try:
        wall_module.delete_wall(session, args.guid)
    except ValueError as exc:
        raise RpcError(ErrorCode.INVALID_PARAMS, str(exc)) from exc
    topo_registry.unregister_guid(args.guid)
    return {"ok": True}


def register(dispatcher: Dispatcher) -> None:
    """Registra todos los metodos ``ifc.*`` en el dispatcher dado."""
    dispatcher.register("ifc.create_wall", create_wall)
    dispatcher.register("ifc.get_wall_spec", get_wall_spec)
    dispatcher.register("ifc.set_wall_typology", set_wall_typology)
    dispatcher.register("ifc.delete", delete_product)
