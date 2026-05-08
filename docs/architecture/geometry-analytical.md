# Geometría analítica en el tronco

Propósito en una frase: que contribuyentes sepan que **la malla que consume Godot** y las **proyecciones 2D** (`draw.ortho_snapshot`) provienen del **mismo pipeline analítico** (caja de muro y variantes con huecos), sin un segundo motor gráfico paralelo en Python.

## Áreas cubiertas hoy

| Área | Implementación |
|------|----------------|
| Muro caja IFC + malla Godot | `wall_box_mesh` / `wall_mesh_for_spec` en `axonbim.geometry.meshing` |
| `draw.ortho_snapshot` | Aristas proyectadas desde esa malla analítica |
| `geom.extrude_face` | Extrusión analítica de cara de caja; resultado incluye `debug_mesh_stats` (vértices, triángulos, caras lógicas) de la malla devuelta |

Extensiones futuras con sólidos B-Rep o booleanas se adoptarán por **ADR** cuando entren en el tronco; este documento no sustituye normativa MIVED ni el manual de usuario.
