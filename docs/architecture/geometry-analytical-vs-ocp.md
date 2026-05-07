# Geometría analítica vs OCP (OpenCASCADE)

Propósito en una frase: aclarar **qué camino geométrico** usa el tronco hoy y **cuándo** tocar OCP, para que los PRs no asuman OCC obligatorio en flujos que pueden seguir siendo analíticos.

## Hecho en el producto actual

| Área | Camino por defecto | OCP / OCC |
|------|-------------------|-----------|
| Muro caja IFC + malla Godot | Fórmulas caja + `wall_box_mesh` | Opcional como **sonda** (`debug_ocp_mesh_stats`, malla paralela) |
| `geom.extrude_face` | `extrude_wall_face` analítico | Sonda B-Rep en paralelo |
| `draw.ortho_snapshot` | `projection_engine=analytical` | `ocp` opcional por parámetro RPC |
| Export DXF muros | Proyección analítica | Sin OCP en el tronco actual |

## Cuándo tiene sentido profundizar en OCP

- Validación frente a un sólido B-Rep cuando la analítica y OCP deban **coincidir** dentro de tolerancia.
- Preparar terreno para operaciones que **no** tengan fórmula caja cerrada (booleanas reales, cortes complejos).
- **No** es requisito para la capa MIVED 2D si la entrega se basa en **proyección y simbología 2D** derivadas del modelo ligero.

## Referencias de código

- `src/axonbim/geometry/wall_extrude.py`, `meshing.py`
- `src/axonbim/handlers/geom.py`, `handlers/draw.py`
- `docs/phase-reports/phase-2-report.md` (modelado interactivo)
