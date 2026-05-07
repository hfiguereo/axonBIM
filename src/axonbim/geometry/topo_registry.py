# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Registro de ``topo_id`` -> entidad IFC para resolver ``geom.*`` en sesion.

Paralelo conceptual a tener **sub-elementos** (cara, arista) direccionables en
App mientras Gui hace picking. Sprint 1.4 solo registraba mallas de
``ifc.create_wall``; Fase 2 añade ``WallSpec`` para extruir caras sin OCP.
"""

from __future__ import annotations

import threading

from axonbim.geometry.meshing import Mesh
from axonbim.geometry.slab_spec import SlabSpec
from axonbim.geometry.wall_spec import WallSpec

_LOCK = threading.Lock()
# topo_id -> guid IFC del producto que posee esa cara en la mesh serializada.
_BY_TOPO: dict[str, str] = {}
# guid -> ultima mesh registrada.
_BY_GUID: dict[str, Mesh] = {}
# guid -> parametros del muro caja (para ``geom.extrude_face``).
_WALL_SPEC: dict[str, WallSpec] = {}
# guid -> parametros de losa prismática (``ifc.create_slab``).
_SLAB_SPEC: dict[str, SlabSpec] = {}


def clear() -> None:
    """Vacía el registro (p. ej. al resetear sesion IFC en tests)."""
    with _LOCK:
        _BY_TOPO.clear()
        _BY_GUID.clear()
        _WALL_SPEC.clear()
        _SLAB_SPEC.clear()


def register_mesh(guid: str, mesh: Mesh) -> None:
    """Indexa ``topo_id`` -> ``guid`` y guarda la malla por ``guid``."""
    with _LOCK:
        _replace_mesh_locked(guid, mesh)


def register_wall_spec(guid: str, spec: WallSpec) -> None:
    """Asocia parametros de muro caja al ``guid`` (tras ``ifc.create_wall``)."""
    with _LOCK:
        _WALL_SPEC[guid] = spec


def register_slab_spec(guid: str, spec: SlabSpec) -> None:
    """Asocia parametros de losa al ``guid`` (tras ``ifc.create_slab``)."""
    with _LOCK:
        _SLAB_SPEC[guid] = spec


def get_slab_spec(guid: str) -> SlabSpec | None:
    """Devuelve el ``SlabSpec`` registrado o ``None``."""
    with _LOCK:
        return _SLAB_SPEC.get(guid)


def get_wall_spec(guid: str) -> WallSpec | None:
    """Devuelve el ``WallSpec`` registrado o ``None``."""
    with _LOCK:
        return _WALL_SPEC.get(guid)


def all_wall_specs() -> dict[str, WallSpec]:
    """Copia ``guid -> WallSpec`` de la sesión actual."""
    with _LOCK:
        return dict(_WALL_SPEC)


def update_wall_spec(guid: str, spec: WallSpec) -> None:
    """Sustituye el ``WallSpec`` tras una mutacion geometrica."""
    with _LOCK:
        _WALL_SPEC[guid] = spec


def replace_mesh(guid: str, mesh: Mesh) -> None:
    """Sustituye la malla y reindexa ``topo_id`` (invalida hashes viejos del mismo guid)."""
    with _LOCK:
        _replace_mesh_locked(guid, mesh)


def _replace_mesh_locked(guid: str, mesh: Mesh) -> None:
    old = _BY_GUID.pop(guid, None)
    if old is not None:
        for tid in set(old.topo_ids):
            if _BY_TOPO.get(tid) == guid:
                del _BY_TOPO[tid]
    _BY_GUID[guid] = mesh
    for tid in set(mesh.topo_ids):
        _BY_TOPO[tid] = guid


def owner_guid(topo_id: str) -> str | None:
    """Devuelve el ``GlobalId`` IFC asociado a ``topo_id``, o ``None``."""
    with _LOCK:
        return _BY_TOPO.get(topo_id)


def mesh_for_topo_id(topo_id: str) -> Mesh | None:
    """Devuelve la malla del producto que contiene ``topo_id``, o ``None``."""
    with _LOCK:
        guid = _BY_TOPO.get(topo_id)
        if guid is None:
            return None
        return _BY_GUID.get(guid)


def mesh_for_guid(guid: str) -> Mesh | None:
    """Devuelve la malla registrada para ``guid``, o ``None``."""
    with _LOCK:
        return _BY_GUID.get(guid)


def unregister_guid(guid: str) -> None:
    """Elimina ``guid``, su ``WallSpec`` o ``SlabSpec`` y los ``topo_id`` derivados."""
    with _LOCK:
        old = _BY_GUID.pop(guid, None)
        if old is not None:
            for tid in set(old.topo_ids):
                if _BY_TOPO.get(tid) == guid:
                    del _BY_TOPO[tid]
        _WALL_SPEC.pop(guid, None)
        _SLAB_SPEC.pop(guid, None)


def has_topo_id(topo_id: str) -> bool:
    """True si ``topo_id`` esta registrado en la sesion actual."""
    with _LOCK:
        return topo_id in _BY_TOPO
