# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Huecos ``IfcOpeningElement`` anclados a ``IfcWall`` con ``IfcRelVoidsElement``."""

from __future__ import annotations

import logging
import math
from typing import Any

import ifcopenshell
import ifcopenshell.api
import numpy as np
from ifcopenshell.util.shape_builder import ShapeBuilder

from axonbim.geometry.wall_spec import WallOpeningSpec, WallSpec
from axonbim.ifc.session import IfcSession

_log = logging.getLogger(__name__)
_MIN_OPENING_WALL_LEN_M: float = 1e-9


def _run(usecase: str, *args: Any, **kwargs: Any) -> Any:
    return ifcopenshell.api.run(usecase, *args, **kwargs)


def create_wall_opening(
    session: IfcSession,
    wall_guid: str,
    opening: WallOpeningSpec,
    wall_spec: WallSpec,
) -> str:
    """Crea ``IfcOpeningElement`` + ``IfcRelVoidsElement`` en el muro indicado.

    El perfil de ``ShapeBuilder`` vive en XY y se extruye en +Z; se rota al sistema
    local del muro (X a lo largo, Y grosor, Z vertical) y se centra en el hueco.

    Args:
        session: Sesión IFC activa.
        wall_guid: ``GlobalId`` del ``IfcWall`` anfitrión.
        opening: Parámetros del hueco respecto al muro caja AxonBIM.
        wall_spec: Especificación actual del muro (ejes y dimensiones).

    Returns:
        ``GlobalId`` del ``IfcOpeningElement`` creado.

    Raises:
        ValueError: Si no existe el muro o los parámetros son degenerados.
    """
    wall = _wall_by_guid(session, wall_guid)
    if wall is None:
        raise ValueError(f"No existe IfcWall con GlobalId={wall_guid!r}")

    p1, p2 = wall_spec.p1, wall_spec.p2
    dx, dy = p2[0] - p1[0], p2[1] - p1[1]
    length = math.hypot(dx, dy)
    if length < _MIN_OPENING_WALL_LEN_M:
        raise ValueError("muro degenerado para hueco")

    ux, uy = dx / length, dy / length
    nx, ny = -uy, ux
    z0 = min(p1[2], p2[2])

    depth = wall_spec.thickness * 1.25
    cx = opening.along_start_m + opening.width_m * 0.5
    cz = opening.sill_height_m + opening.height_m * 0.5

    sb = ShapeBuilder(session.file)
    rectangle = sb.rectangle(size=np.array([opening.width_m, opening.height_m]))
    extrusion = sb.extrude(rectangle, magnitude=depth)
    representation = sb.get_representation(session.body_context, [extrusion])

    opening_el = _run(
        "root.create_entity",
        session.file,
        ifc_class="IfcOpeningElement",
        name="Opening",
    )

    p_map = np.array([[1.0, 0.0, 0.0], [0.0, 0.0, 1.0], [0.0, 1.0, 0.0]], dtype=float)
    trans = np.eye(4)
    trans[0, 3] = cx
    trans[1, 3] = -0.5 * depth
    trans[2, 3] = cz

    m_wall = np.array(
        [
            [ux, nx, 0.0, p1[0]],
            [uy, ny, 0.0, p1[1]],
            [0.0, 0.0, 1.0, z0],
            [0.0, 0.0, 0.0, 1.0],
        ],
        dtype=float,
    )
    rot4 = np.eye(4)
    rot4[:3, :3] = p_map
    full = m_wall @ trans @ rot4

    _run(
        "geometry.edit_object_placement",
        session.file,
        product=opening_el,
        matrix=full,
    )
    _run(
        "geometry.assign_representation",
        session.file,
        product=opening_el,
        representation=representation,
    )
    _run(
        "spatial.assign_container",
        session.file,
        relating_structure=session.storey,
        products=[opening_el],
    )
    session.file.create_entity(
        "IfcRelVoidsElement",
        GlobalId=ifcopenshell.guid.new(),
        RelatingBuildingElement=wall,
        RelatedOpeningElement=opening_el,
    )
    _log.info("Hueco IFC creado en muro %s: opening=%s", wall_guid, opening_el.GlobalId)
    return str(opening_el.GlobalId)


def delete_opening_element(session: IfcSession, opening_guid: str) -> None:
    """Elimina un ``IfcOpeningElement`` y sus relaciones vía ``remove_product``."""
    inst = session.file.by_guid(opening_guid)
    if inst is None or not inst.is_a("IfcOpeningElement"):
        raise ValueError(f"No existe IfcOpeningElement con GlobalId={opening_guid!r}")
    _run("root.remove_product", session.file, product=inst)


def _wall_by_guid(session: IfcSession, guid: str) -> Any | None:
    for w in session.file.by_type("IfcWall"):
        if str(w.GlobalId) == guid:
            return w
    return None
