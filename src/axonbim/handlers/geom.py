# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Handlers del dominio ``geom.*``: extrude_face, etc."""

from __future__ import annotations

from typing import Any, Final

from pydantic import BaseModel, ConfigDict, Field, field_validator

from axonbim.geometry import topo_registry
from axonbim.geometry.meshing import Mesh
from axonbim.geometry.ocp_brep import wall_box_mesh_ocp
from axonbim.geometry.wall_extrude import extrude_wall_face
from axonbim.geometry.wall_spec import WallSpec
from axonbim.history import sqlite_store as history_store
from axonbim.ifc import wall as wall_module
from axonbim.ifc.session import get_session
from axonbim.rpc.dispatcher import Dispatcher, RpcError
from axonbim.rpc.models import ErrorCode

_VEC3_LEN: Final[int] = 3


class ExtrudeFaceParams(BaseModel):
    """Parametros de ``geom.extrude_face``."""

    model_config = ConfigDict(extra="forbid")

    topo_id: str = Field(min_length=1)
    vector: list[float] = Field(description="Vector de extrusion en metros (world), 3 componentes.")

    @field_validator("vector", mode="before")
    @classmethod
    def _coerce_vector(cls, value: object) -> list[float]:
        if isinstance(value, (list, tuple)) and len(value) == _VEC3_LEN:
            return [float(value[0]), float(value[1]), float(value[2])]
        raise ValueError("vector must be a sequence of 3 numbers")


async def extrude_face(params: dict[str, Any]) -> dict[str, Any]:
    """Extruye una cara identificada por ``topo_id`` a lo largo de la normal exterior."""
    args = ExtrudeFaceParams.model_validate(params)

    mesh = topo_registry.mesh_for_topo_id(args.topo_id)
    if mesh is None:
        raise RpcError(
            ErrorCode.TOPO_ID_NOT_FOUND,
            f"topo_id not in session: {args.topo_id!r}",
            data={"topo_id": args.topo_id},
        )

    guid = topo_registry.owner_guid(args.topo_id)
    if guid is None:
        raise RpcError(
            ErrorCode.INTERNAL_ERROR,
            "topo_id sin propietario guid",
            data={"topo_id": args.topo_id},
        )

    spec = topo_registry.get_wall_spec(guid)
    if spec is None:
        raise RpcError(
            ErrorCode.INVALID_PARAMS,
            "Muro sin WallSpec en sesion; vuelve a crear el muro en esta sesion.",
            data={"guid": guid},
        )

    old_spec = WallSpec(spec.p1, spec.p2, spec.height, spec.thickness)
    old_mesh = Mesh.from_dict(mesh.to_dict())
    vec = (args.vector[0], args.vector[1], args.vector[2])

    try:
        new_spec, new_mesh, topo_map = extrude_wall_face(old_spec, mesh, args.topo_id, vec)
    except ValueError as exc:
        raise RpcError(ErrorCode.INVALID_PARAMS, str(exc)) from exc

    history_store.push_undo(
        "extrude_face",
        {
            "guid": guid,
            "wall_spec": old_spec.to_dict(),
            "mesh": old_mesh.to_dict(),
        },
        clear_redo=True,
    )

    session = get_session()
    wall_module.update_wall_geometry(session, guid, new_spec)
    topo_registry.replace_mesh(guid, new_mesh)
    topo_registry.update_wall_spec(guid, new_spec)
    ocp_mesh = wall_box_mesh_ocp(
        new_spec,
        parent_guid=guid,
        op_signature="geom.extrude_face:ocp_probe:v1",
    )

    return {
        "guid": guid,
        "mesh": new_mesh.to_dict(),
        "topo_map": topo_map,
        "debug_ocp_mesh_stats": {
            "vertices": ocp_mesh.vertex_count,
            "triangles": ocp_mesh.triangle_count,
            "faces": len(set(ocp_mesh.topo_ids)),
        },
    }


def register(dispatcher: Dispatcher) -> None:
    """Registra metodos ``geom.*``."""
    dispatcher.register("geom.extrude_face", extrude_face)
