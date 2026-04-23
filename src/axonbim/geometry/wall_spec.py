# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Parametros de un muro caja IFC/Godot para regenerar malla y extruir caras."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from axonbim.geometry.topology import Vec3


@dataclass(slots=True)
class WallSpec:
    """Extremos en planta, altura y grosor (metros). ``z`` de ``p1``/``p2`` define la base."""

    p1: Vec3
    p2: Vec3
    height: float
    thickness: float

    def to_dict(self) -> dict[str, Any]:
        """Serializa para JSON/SQLite."""
        return {
            "p1": {"x": self.p1[0], "y": self.p1[1], "z": self.p1[2]},
            "p2": {"x": self.p2[0], "y": self.p2[1], "z": self.p2[2]},
            "height": self.height,
            "thickness": self.thickness,
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> WallSpec:
        """Deserializa desde dict (p. ej. historial undo)."""
        p1 = data["p1"]
        p2 = data["p2"]
        return cls(
            p1=(float(p1["x"]), float(p1["y"]), float(p1["z"])),
            p2=(float(p2["x"]), float(p2["y"]), float(p2["z"])),
            height=float(data["height"]),
            thickness=float(data["thickness"]),
        )
