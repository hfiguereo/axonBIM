# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Handlers del dominio ``ifc.*``: creacion y consulta de entidades IFC.

Sprint 1.4 expone unicamente ``ifc.create_wall``.
"""

from __future__ import annotations

from typing import Any

from pydantic import BaseModel, ConfigDict, Field

from axonbim.geometry.topology import Vec3
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


async def create_wall(params: dict[str, Any]) -> dict[str, Any]:
    """Handler de ``ifc.create_wall``: valida parametros, crea ``IfcWall`` y devuelve mesh.

    Raises:
        RpcError: con codigo ``INVALID_PARAMS`` si la geometria es invalida.
    """
    args = CreateWallParams.model_validate(params)

    session = get_session()
    try:
        result = wall_module.create_wall(
            session,
            args.p1.as_tuple(),
            args.p2.as_tuple(),
            height=args.height,
            thickness=args.thickness,
            name=args.name,
        )
    except ValueError as exc:
        raise RpcError(ErrorCode.INVALID_PARAMS, str(exc)) from exc

    return {
        "guid": result.guid,
        "mesh": result.mesh.to_dict(),
    }


def register(dispatcher: Dispatcher) -> None:
    """Registra todos los metodos ``ifc.*`` en el dispatcher dado."""
    dispatcher.register("ifc.create_wall", create_wall)
