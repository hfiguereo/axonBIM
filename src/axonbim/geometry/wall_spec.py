# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Parametros de un muro caja IFC/Godot para regenerar malla y extruir caras."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from axonbim.geometry.topology import Vec3


@dataclass(frozen=True, slots=True)
class WallOpeningSpec:
    """Hueco rectangular en la cara ``+n`` del muro caja (atraviesa el grosor).

    El borde izquierdo del hueco dista ``along_start_m`` del extremo ``p1`` siguiendo
    el eje del muro en planta. La base del hueco está a ``sill_height_m`` sobre
    ``min(p1.z, p2.z)``.
    """

    along_start_m: float
    width_m: float
    sill_height_m: float
    height_m: float

    def to_dict(self) -> dict[str, Any]:
        """Serializa para JSON/SQLite."""
        return {
            "along_start_m": self.along_start_m,
            "width_m": self.width_m,
            "sill_height_m": self.sill_height_m,
            "height_m": self.height_m,
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> WallOpeningSpec:
        """Deserializa desde dict."""
        return cls(
            along_start_m=float(data["along_start_m"]),
            width_m=float(data["width_m"]),
            sill_height_m=float(data["sill_height_m"]),
            height_m=float(data["height_m"]),
        )


@dataclass(slots=True)
class WallSpec:
    """Extremos en planta, altura y grosor (metros). ``z`` de ``p1``/``p2`` define la base."""

    p1: Vec3
    p2: Vec3
    height: float
    thickness: float
    openings: tuple[WallOpeningSpec, ...] = ()

    def to_dict(self) -> dict[str, Any]:
        """Serializa para JSON/SQLite."""
        return {
            "p1": {"x": self.p1[0], "y": self.p1[1], "z": self.p1[2]},
            "p2": {"x": self.p2[0], "y": self.p2[1], "z": self.p2[2]},
            "height": self.height,
            "thickness": self.thickness,
            "openings": [o.to_dict() for o in self.openings],
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> WallSpec:
        """Deserializa desde dict (p. ej. historial undo)."""
        p1 = data["p1"]
        p2 = data["p2"]
        raw_open = data.get("openings") or []
        openings: tuple[WallOpeningSpec, ...] = tuple(
            WallOpeningSpec.from_dict(x) for x in raw_open
        )
        return cls(
            p1=(float(p1["x"]), float(p1["y"]), float(p1["z"])),
            p2=(float(p2["x"]), float(p2["y"]), float(p2["z"])),
            height=float(data["height"]),
            thickness=float(data["thickness"]),
            openings=openings,
        )
