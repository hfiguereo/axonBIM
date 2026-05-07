# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Creación de losas ``IfcSlab`` con prisma convexo en planta (MVP analítico)."""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Any

import ifcopenshell.api
import numpy as np
from ifcopenshell.util.shape_builder import ShapeBuilder

from axonbim.geometry.meshing import Mesh, slab_prism_mesh
from axonbim.geometry.slab_spec import SlabSpec
from axonbim.ifc.session import IfcSession

_log = logging.getLogger(__name__)


def _run(usecase: str, *args: Any, **kwargs: Any) -> Any:
    return ifcopenshell.api.run(usecase, *args, **kwargs)


@dataclass(slots=True)
class SlabResult:
    """Resultado de crear una losa: GUID IFC + malla Godot."""

    guid: str
    mesh: Mesh


def create_slab(
    session: IfcSession,
    spec: SlabSpec,
    *,
    name: str | None = None,
) -> SlabResult:
    """Crea ``IfcSlab`` tipo ``FLOOR`` con extrusión vertical hacia ``-Z``.

    Args:
        session: Sesión IFC activa.
        spec: Contorno convexo CCW, cota superior y espesor (metros).
        name: Nombre opcional; si es ``None`` se autogenera ``Slab-<N>``.

    Returns:
        ``SlabResult`` con ``guid`` y ``mesh``.

    Raises:
        ValueError: Si la geometría es inválida.
    """
    slab_name = name or _next_slab_name(session)
    slab = _run("root.create_entity", session.file, ifc_class="IfcSlab", name=slab_name)
    slab.PredefinedType = "FLOOR"
    _run(
        "spatial.assign_container",
        session.file,
        relating_structure=session.storey,
        products=[slab],
    )

    guid = str(slab.GlobalId)
    mesh = slab_prism_mesh(
        spec.polygon_xy,
        spec.z_top_m,
        spec.thickness_m,
        parent_guid=guid,
    )

    sb = ShapeBuilder(session.file)
    pts = [np.array([p[0], p[1]], dtype=float) for p in spec.polygon_xy]
    poly = sb.polyline(pts, closed=True)
    solid = sb.extrude(
        poly,
        magnitude=spec.thickness_m,
        position=(0.0, 0.0, spec.z_top_m),
        extrusion_vector=(0.0, 0.0, -1.0),
    )
    representation = sb.get_representation(session.body_context, [solid])
    _run(
        "geometry.assign_representation",
        session.file,
        product=slab,
        representation=representation,
    )
    _log.info("Losa creada: guid=%s", guid)
    return SlabResult(guid=guid, mesh=mesh)


def delete_slab(session: IfcSession, guid: str) -> None:
    """Elimina un ``IfcSlab`` del modelo."""
    slab = _slab_by_guid(session, guid)
    if slab is None:
        raise ValueError(f"No existe IfcSlab con GlobalId={guid!r}")
    _run("root.remove_product", session.file, product=slab)
    _log.info("Losa eliminada: guid=%s", guid)


def restore_slab(
    session: IfcSession,
    guid: str,
    spec: SlabSpec,
    *,
    name: str | None = None,
) -> SlabResult:
    """Recrea ``IfcSlab`` con ``GlobalId`` fijo (deshacer borrado)."""
    if _slab_by_guid(session, guid) is not None:
        raise ValueError(f"Ya existe IfcSlab con GlobalId={guid!r}")
    mesh = slab_prism_mesh(
        spec.polygon_xy,
        spec.z_top_m,
        spec.thickness_m,
        parent_guid=guid,
    )
    slab_name = name or _next_slab_name(session)
    slab = session.file.create_entity("IfcSlab", GlobalId=str(guid), Name=slab_name)
    slab.PredefinedType = "FLOOR"
    _run(
        "spatial.assign_container",
        session.file,
        relating_structure=session.storey,
        products=[slab],
    )
    sb = ShapeBuilder(session.file)
    pts = [np.array([p[0], p[1]], dtype=float) for p in spec.polygon_xy]
    poly = sb.polyline(pts, closed=True)
    solid = sb.extrude(
        poly,
        magnitude=spec.thickness_m,
        position=(0.0, 0.0, spec.z_top_m),
        extrusion_vector=(0.0, 0.0, -1.0),
    )
    representation = sb.get_representation(session.body_context, [solid])
    _run(
        "geometry.assign_representation",
        session.file,
        product=slab,
        representation=representation,
    )
    _log.info("Losa restaurada: guid=%s", guid)
    return SlabResult(guid=str(guid), mesh=mesh)


def _slab_by_guid(session: IfcSession, guid: str) -> Any | None:
    for s in session.file.by_type("IfcSlab"):
        if str(s.GlobalId) == guid:
            return s
    return None


def _next_slab_name(session: IfcSession) -> str:
    existing = session.file.by_type("IfcSlab")
    return f"Slab-{len(existing) + 1:03d}"
