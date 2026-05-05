# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Creacion de muros IFC (``IfcWall``) con representacion geometrica extrudida.

En Sprint 1.4 el muro es una caja (paralelepipedo). La mesh que viaja a Godot
se calcula analiticamente en :mod:`axonbim.geometry.meshing` sin OCP; la
representacion IFC escrita al disco usa ``ifcopenshell.util.shape_builder``
para producir un ``IfcExtrudedAreaSolid`` valido.
"""

from __future__ import annotations

import logging
import math
from dataclasses import dataclass
from typing import Any

import ifcopenshell.api
import numpy as np
from ifcopenshell.util.shape_builder import ShapeBuilder

from axonbim.geometry.meshing import Mesh, wall_box_mesh
from axonbim.geometry.topology import Vec3
from axonbim.geometry.wall_spec import WallSpec
from axonbim.ifc.session import IfcSession

_log = logging.getLogger(__name__)
_MIN_PLACEMENT_LENGTH_M: float = 1e-9


@dataclass(slots=True)
class WallResult:
    """Resultado de crear un muro: GUID IFC + mesh lista para Godot."""

    guid: str
    mesh: Mesh


def _run(usecase: str, *args: Any, **kwargs: Any) -> Any:
    return ifcopenshell.api.run(usecase, *args, **kwargs)


def create_wall(
    session: IfcSession,
    p1: Vec3,
    p2: Vec3,
    height: float,
    thickness: float,
    *,
    name: str | None = None,
) -> WallResult:
    """Crea un ``IfcWall`` entre ``p1`` y ``p2`` con geometria extrudida.

    Args:
        session: sesion IFC activa.
        p1: extremo inicial en planta (metros).
        p2: extremo final en planta (metros).
        height: altura en metros (> 0).
        thickness: grosor en metros (> 0).
        name: nombre opcional. Si es ``None`` se autogenera ``Wall-<N>``.

    Returns:
        ``WallResult`` con ``guid`` y ``mesh`` para renderizar en Godot.
    """
    mesh = wall_box_mesh(p1, p2, height, thickness)

    wall_name = name or _next_wall_name(session)
    wall = _run("root.create_entity", session.file, ifc_class="IfcWall", name=wall_name)
    _run(
        "spatial.assign_container",
        session.file,
        relating_structure=session.storey,
        products=[wall],
    )

    length = math.hypot(p2[0] - p1[0], p2[1] - p1[1])
    _assign_box_representation(session, wall, length=length, thickness=thickness, height=height)
    _place_wall(session, wall, p1=p1, p2=p2)

    _log.info("Muro creado: guid=%s, length=%.3f, height=%.3f", wall.GlobalId, length, height)
    return WallResult(guid=str(wall.GlobalId), mesh=mesh)


def update_wall_geometry(session: IfcSession, guid: str, spec: WallSpec) -> WallResult:
    """Regenera representacion IFC y malla Godot para un ``IfcWall`` existente."""
    wall = _wall_by_guid(session, guid)
    if wall is None:
        raise ValueError(f"No existe IfcWall con GlobalId={guid!r}")

    mesh = wall_box_mesh(spec.p1, spec.p2, spec.height, spec.thickness)
    length = math.hypot(spec.p2[0] - spec.p1[0], spec.p2[1] - spec.p1[1])
    _assign_box_representation(
        session, wall, length=length, thickness=spec.thickness, height=spec.height
    )
    _place_wall(session, wall, p1=spec.p1, p2=spec.p2)
    _log.info("Muro actualizado: guid=%s, length=%.3f, height=%.3f", guid, length, spec.height)
    return WallResult(guid=guid, mesh=mesh)


def _wall_by_guid(session: IfcSession, guid: str) -> Any | None:
    for w in session.file.by_type("IfcWall"):
        if str(w.GlobalId) == guid:
            return w
    return None


def _assign_box_representation(
    session: IfcSession,
    wall: Any,
    *,
    length: float,
    thickness: float,
    height: float,
) -> None:
    _remove_body_representations(session, wall)
    sb = ShapeBuilder(session.file)
    rectangle = sb.rectangle(size=np.array([length, thickness]))
    extrusion = sb.extrude(rectangle, magnitude=height)
    representation = sb.get_representation(session.body_context, [extrusion])
    _run(
        "geometry.assign_representation",
        session.file,
        product=wall,
        representation=representation,
    )


def _remove_body_representations(session: IfcSession, wall: Any) -> None:
    """Elimina representaciones ``Body`` previas antes de regenerar geometría."""
    product_representation = getattr(wall, "Representation", None)
    if product_representation is None:
        return
    old_representations = [
        representation
        for representation in product_representation.Representations
        if representation.RepresentationIdentifier == "Body"
    ]
    for representation in old_representations:
        _run(
            "geometry.unassign_representation",
            session.file,
            product=wall,
            representation=representation,
        )
        _run("geometry.remove_representation", session.file, representation=representation)


def _place_wall(session: IfcSession, wall: Any, *, p1: Vec3, p2: Vec3) -> None:
    dx, dy = p2[0] - p1[0], p2[1] - p1[1]
    length = math.hypot(dx, dy)
    if length < _MIN_PLACEMENT_LENGTH_M:
        return
    ux, uy = dx / length, dy / length
    nx, ny = -uy, ux

    matrix = np.array(
        [
            [ux, nx, 0.0, p1[0]],
            [uy, ny, 0.0, p1[1]],
            [0.0, 0.0, 1.0, min(p1[2], p2[2])],
            [0.0, 0.0, 0.0, 1.0],
        ],
        dtype=float,
    )
    _run("geometry.edit_object_placement", session.file, product=wall, matrix=matrix)


def _next_wall_name(session: IfcSession) -> str:
    existing = session.file.by_type("IfcWall")
    return f"Wall-{len(existing) + 1:03d}"
