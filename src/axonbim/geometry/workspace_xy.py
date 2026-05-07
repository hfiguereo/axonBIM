# © 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Extensiones en planta (XY) del ``espacio de trabajo`` asociado a la sesion IFC.

No es un limite duro de coordenadas: se **amplia** automaticamente cuando la
geometria valida excede el rectangulo simetrico actual. El frontend puede
mostrar la media y alinear rejillas o impresion en fases posteriores.
"""

from __future__ import annotations

from dataclasses import dataclass

_EXPAND_MARGIN = 1.12


@dataclass
class WorkspaceXYHalfExtents:
    """Mitad del ancho en X y en Y (metros) respecto al origen; simetrico ``±half``."""

    half_x_m: float = 50.0
    half_y_m: float = 50.0

    def ensure_contains_segment_plan(self, x1: float, y1: float, x2: float, y2: float) -> None:
        """Garantiza que ambos extremos del segmento en planta queden dentro del rectangulo.

        Si alguna coordenada absoluta supera la media actual, la media crece con
        un margen proporcional para dejar holgura.
        """
        for x, y in ((x1, y1), (x2, y2)):
            ax = abs(float(x))
            ay = abs(float(y))
            if ax > self.half_x_m:
                self.half_x_m = ax * _EXPAND_MARGIN
            if ay > self.half_y_m:
                self.half_y_m = ay * _EXPAND_MARGIN

    def as_half_list_m(self) -> list[float]:
        """Lista ``[half_x_m, half_y_m]`` para serializar en JSON-RPC."""
        return [float(self.half_x_m), float(self.half_y_m)]
