# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Sesion IFC: singleton por proceso que envuelve el ``ifcopenshell.file`` activo.

La ``IfcSession`` mantiene el archivo IFC cargado en memoria + referencias a las
entidades espaciales mas usadas (``project``, ``site``, ``building``, ``storey``,
``body_context``). El atributo ``storey`` es el **IfcBuildingStorey activo**: los
productos nuevos (p. ej. muros) se contienen en ese nivel hasta que se cambie con
:meth:`IfcSession.set_active_storey`.
"""

from __future__ import annotations

import logging
import threading
from pathlib import Path
from typing import TYPE_CHECKING, Any, cast

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

        storey.Elevation = 0.0

        _log.info("Sesion IFC creada (schema=%s, project=%r)", schema, project_name)
        return cls(file, project, site, building, storey, body_context)

    @classmethod
    def open_existing(cls, path: Path) -> IfcSession:
        """Carga un ``.ifc`` desde disco y enlaza proyecto, sitio, edificio y niveles.

        El primer ``IfcBuildingStorey`` por cota (empate por nombre) queda como
        **nivel activo** para nuevos elementos.

        Args:
            path: Ruta a un archivo STEP físico existente.

        Returns:
            Sesión lista para ``save`` y operaciones geométricas.

        Raises:
            FileNotFoundError: Si ``path`` no apunta a un fichero.
            ValueError: Si falta jerarquía espacial mínima o contexto Body.
        """
        resolved = path.expanduser().resolve()
        if not resolved.is_file():
            raise FileNotFoundError(str(resolved))
        file: ifc_file_type = ifcopenshell.open(str(resolved))
        projects = file.by_type("IfcProject")
        if not projects:
            raise ValueError("IFC sin IfcProject")
        project = projects[0]
        sites = _aggregated_children(project, "IfcSite")
        if not sites:
            raise ValueError("IFC sin IfcSite bajo el proyecto")
        site = sites[0]
        buildings = _aggregated_children(site, "IfcBuilding")
        if not buildings:
            raise ValueError("IFC sin IfcBuilding bajo el sitio")
        building = buildings[0]
        storeys = _aggregated_children(building, "IfcBuildingStorey")
        if not storeys:
            raise ValueError("IFC sin IfcBuildingStorey bajo el edificio")
        storeys_sorted = sorted(storeys, key=_storey_sort_key)
        storey0 = storeys_sorted[0]
        body_ctx = _find_body_model_subcontext(file)
        _log.info("Sesion IFC abierta desde %s", resolved)
        return cls(file, project, site, building, storey0, body_ctx)

    def list_storeys_ordered(self) -> list[entity_instance]:
        """Lista ``IfcBuildingStorey`` bajo ``building``, ordenados por cota y nombre."""
        found: list[entity_instance] = []
        for rel in self.building.IsDecomposedBy or []:
            for obj in rel.RelatedObjects or []:
                if obj.is_a("IfcBuildingStorey"):
                    found.append(obj)
        return sorted(found, key=_storey_sort_key)

    def create_storey(self, name: str, elevation_m: float) -> entity_instance:
        """Crea un nivel, lo agrega al edificio y fija ``Elevation`` en metros."""
        storey = _run(
            "root.create_entity",
            self.file,
            ifc_class="IfcBuildingStorey",
            name=name,
        )
        storey.Elevation = float(elevation_m)
        _run(
            "aggregate.assign_object",
            self.file,
            relating_object=self.building,
            products=[storey],
        )
        return cast("entity_instance", storey)

    def set_active_storey(self, guid: str) -> None:
        """Apunta ``self.storey`` al ``IfcBuildingStorey`` con ``GlobalId`` dado.

        Raises:
            ValueError: Si el GUID no corresponde a un nivel del edificio activo.
        """
        for st in self.list_storeys_ordered():
            if str(st.GlobalId) == guid:
                self.storey = st
                return
        raise ValueError(f"No hay IfcBuildingStorey bajo el edificio con GlobalId={guid!r}")

    def save(self, path: Path) -> None:
        """Serializa la sesion a ``path`` como texto ISO 10303-21 (``.ifc``)."""
        path.parent.mkdir(parents=True, exist_ok=True)
        self.file.write(str(path))
        _log.info("IFC guardado en %s (%d bytes)", path, path.stat().st_size)


def _storey_sort_key(st: Any) -> tuple[float, str]:
    raw = getattr(st, "Elevation", None)
    ez: float = float(raw) if raw is not None else 0.0
    return (ez, str(st.Name or ""))


def _aggregated_children(parent: Any, ifc_class: str) -> list[Any]:
    """Hijos directos vía ``IfcRelAggregates`` con la clase dada."""
    found: list[Any] = []
    for rel in parent.IsDecomposedBy or []:
        for obj in rel.RelatedObjects or []:
            if obj.is_a(ifc_class):
                found.append(obj)
    return found


def _find_body_model_subcontext(ifc_file: ifcopenshell.file) -> Any:
    """Localiza el subcontexto ``Body`` / ``MODEL_VIEW`` para asignar geometría."""
    for ctx in ifc_file.by_type("IfcGeometricRepresentationSubContext"):
        if getattr(ctx, "ContextIdentifier", None) == "Body" and getattr(
            ctx, "TargetView", None
        ) == "MODEL_VIEW":
            return ctx
    raise ValueError("IFC sin IfcGeometricRepresentationSubContext Body / MODEL_VIEW")


def install_session(session: IfcSession, *, history_scope: str) -> None:
    """Sustituye la sesión global, limpia topo/historial y fija el ámbito SQLite.

    Args:
        session: Nueva sesión (p. ej. tras ``IfcSession.open_existing``).
        history_scope: Clave de ámbito para la pila undo (ruta canónica del ``.ifc``).
    """
    global _SESSION  # noqa: PLW0603
    with _SESSION_LOCK:
        _SESSION = session
    topo_registry.clear()
    history_store.clear()
    history_store.set_scope(history_scope)


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
