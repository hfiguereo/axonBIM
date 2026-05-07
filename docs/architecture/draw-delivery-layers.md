# Capas y convenciones de entrega 2D (hacia MIVED)

Propósito en una frase: fijar **nombres de capa** y convenciones DXF/PDF compartidas entre backend y documentación de producto, sin copiar texto normativo.

## Relación con el código

- Fuente única de nombres y plantilla mínima: [`../../src/axonbim/drawing/layer_ids.py`](../../src/axonbim/drawing/layer_ids.py) (`DXF_ARCH_LAYER_SPECS`, `arch_layer_names()`).
- Export actual de muros: [`../../src/axonbim/drawing/dxf_walls.py`](../../src/axonbim/drawing/dxf_walls.py) escribe **líneas** solo en `WALLS` y **registra** el resto de capas sin entidades (plantilla estable para PDF/otros exports).

## Convención interna AxonBIM (2026)

Hasta que el extracto operativo CCRD §3.7.3 defina nombres obligatorios, el proyecto usa esta tabla **interna**. Los colores son índices AutoCAD estándar (no equivalen aún a tabla CCRD).

| Capa | Uso previsto | Color (ACI) |
|------|----------------|------------|
| `WALLS` | Huella de muros (eje / convención del exportador analítico) | 7 |
| `AXON_AXES` | Ejes, rejillas, referencias | 1 |
| `AXON_DIM` | Cotas y auxiliares de medida | 3 |
| `AXON_TEXT` | Texto y rotulación | 7 |
| `AXON_HATCH` | Sombras y recintos | 8 |
| `AXON_OPENINGS` | Huella simbólica de huecos (futuro) | 4 |

## Normativa CCRD

El mapeo **oficial** capa ↔ capítulo del Código de Construcción RD queda en [`../normativa/mived/ccrd-vol-i.md`](../normativa/mived/ccrd-vol-i.md) §4.1 cuando exista extracción de §3.7.3.

## Próximos pasos

- Paridad de nombres entre DXF, PDF y PNG donde el producto lo prometa (SH-F3-11).
- Tests golden adicionales por formato (SH-F3-14).
