# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Parametros de una losa prismática (contorno convexo en planta y espesor)."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(slots=True)
class SlabSpec:
    """Polígono convexo en XY (metros) y forjado entre ``z_top`` y ``z_top - thickness``."""

    polygon_xy: tuple[tuple[float, float], ...]
    z_top_m: float
    thickness_m: float

    def to_dict(self) -> dict[str, Any]:
        """Serializa para JSON/SQLite."""
        return {
            "polygon_xy": [[float(x), float(y)] for x, y in self.polygon_xy],
            "z_top_m": self.z_top_m,
            "thickness_m": self.thickness_m,
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> SlabSpec:
        """Deserializa desde dict (historial undo)."""
        raw = data["polygon_xy"]
        poly: list[tuple[float, float]] = []
        for item in raw:
            poly.append((float(item[0]), float(item[1])))
        return cls(
            polygon_xy=tuple(poly),
            z_top_m=float(data["z_top_m"]),
            thickness_m=float(data["thickness_m"]),
        )
