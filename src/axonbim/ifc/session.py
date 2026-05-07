# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Sesion IFC: singleton por proceso que envuelve el ``ifcopenshell.file`` activo.

La ``IfcSession`` mantiene el archivo IFC cargado en memoria + referencias a las
entidades espaciales mas usadas (``project``, ``site``, ``building``, ``storey``,
``body_context``). Sprint 1.4 solo expone un proyecto vacio con un storey por
defecto; la apertura de archivos existentes llega en Fase 2.
"""

from __future__ import annotations

import logging
import threading
from pathlib import Path
from typing import TYPE_CHECKING, Any

import ifcopenshell
import ifcopenshell.api

from axonbim.geometry import topo_registry
from axonbim.geometry.workspace_xy import WorkspaceXYHalfExtents
from axonbim.history import sqlite_store as history_store

if TYPE_CHECKING:
    from ifcopenshell import entity_instance
    from ifcopenshell import file as ifc_file_type

_log = logging.getLogger(__name__)
_SESSION_LOCK = threading.Lock()
_SESSION: IfcSession | None = None


def _run(usecase: str, *args: Any, **kwargs: Any) -> Any:
    """Wrapper tipado sobre ``ifcopenshell.api.run`` (que es ``Any``)."""
    return ifcopenshell.api.run(usecase, *args, **kwargs)


class IfcSession:
    """Proyecto IFC activo + punteros a las entidades espaciales minimas."""

    file: ifc_file_type
    project: entity_instance
    site: entity_instance
    building: entity_instance
    storey: entity_instance
    body_context: entity_instance
    workspace_xy: WorkspaceXYHalfExtents
    view2d_states: dict[str, dict[str, float | str]]

    def __init__(
        self,
        file: ifc_file_type,
        project: entity_instance,
        site: entity_instance,
        building: entity_instance,
        storey: entity_instance,
        body_context: entity_instance,
        workspace_xy: WorkspaceXYHalfExtents | None = None,
    ) -> None:
        """Construye la sesion con referencias ya creadas a las entidades espaciales."""
        self.file = file
        self.project = project
        self.site = site
        self.building = building
        self.storey = storey
        self.body_context = body_context
        self.workspace_xy = workspace_xy if workspace_xy is not None else WorkspaceXYHalfExtents()
        self.view2d_states = {}

    @classmethod
    def create_new(
        cls,
        *,
        schema: str = "IFC4",
        project_name: str = "AxonBIM Project",
        storey_name: str = "Planta baja",
    ) -> IfcSession:
        """Construye un proyecto IFC minimo listo para recibir geometria."""
        file: ifc_file_type = _run("project.create_file", version=schema)
        project = _run("root.create_entity", file, ifc_class="IfcProject", name=project_name)
        _run("unit.assign_unit", file)

        model_context = _run("context.add_context", file, context_type="Model")
        body_context = _run(
            "context.add_context",
            file,
            context_type="Model",
            context_identifier="Body",
            target_view="MODEL_VIEW",
            parent=model_context,
        )

        site = _run("root.create_entity", file, ifc_class="IfcSite", name="Sitio")
        building = _run("root.create_entity", file, ifc_class="IfcBuilding", name="Edificio")
        storey = _run("root.create_entity", file, ifc_class="IfcBuildingStorey", name=storey_name)

        _run("aggregate.assign_object", file, relating_object=project, products=[site])
        _run("aggregate.assign_object", file, relating_object=site, products=[building])
        _run("aggregate.assign_object", file, relating_object=building, products=[storey])

        _log.info("Sesion IFC creada (schema=%s, project=%r)", schema, project_name)
        return cls(file, project, site, building, storey, body_context)

    def save(self, path: Path) -> None:
        """Serializa la sesion a ``path`` como texto ISO 10303-21 (``.ifc``)."""
        path.parent.mkdir(parents=True, exist_ok=True)
        self.file.write(str(path))
        _log.info("IFC guardado en %s (%d bytes)", path, path.stat().st_size)


def get_session() -> IfcSession:
    """Devuelve la sesion activa (creandola si no existe). Thread-safe."""
    global _SESSION  # noqa: PLW0603
    with _SESSION_LOCK:
        if _SESSION is None:
            _SESSION = IfcSession.create_new()
            history_store.set_scope(history_store.SCOPE_UNSAVED)
        return _SESSION


def reset_session() -> None:
    """Descarta la sesion actual. Util para tests."""
    global _SESSION  # noqa: PLW0603
    with _SESSION_LOCK:
        _SESSION = None
    topo_registry.clear()
    history_store.clear()
    history_store.set_scope(history_store.SCOPE_UNSAVED)
