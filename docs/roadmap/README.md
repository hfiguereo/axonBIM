# Desglose operativo del ROADMAP

Complemento de [`ROADMAP.md`](../../ROADMAP.md): **sub-hitos** con *qué*, *cómo* y *por qué*, para reducir puntos ciegos sin sustituir el documento estratégico. El `ROADMAP.md` incorpora además **pipelines** (modelado vs documentación 2D), **objetivo frente a referentes** (SketchUp/Revit) y **puntos ciegos** al añadir ventanas/herramientas.

Cada archivo de fase usa la **misma estructura**: *Sub-hitos ya cubiertos* (tronco / ROADMAP [x]) → *Pendientes hacia criterio de salida* → *Mejoras posibles* (solo en fases cerradas). Detalle en [`00-guia-estructura-subhitos.md`](00-guia-estructura-subhitos.md) §2.1.

## Cómo leer esto

| Documento | Contenido |
|-----------|-----------|
| [`00-guia-estructura-subhitos.md`](00-guia-estructura-subhitos.md) | Plantilla de cada sub-hito y reglas de mantenimiento. |
| [`fase-01-subhitos.md`](fase-01-subhitos.md) | Fase 1 (puente); mayormente **cerrada** — posibles mejoras menores. |
| [`fase-02-subhitos.md`](fase-02-subhitos.md) | Fase 2: criterio de salida **cerrado**; oleada «cáscara de vivienda» (**SH-F2-11…13**) documentada como siguiente trabajo. |
| [`fase-03-subhitos.md`](fase-03-subhitos.md) | Fase 3 (MIVED / 2D normado); **abierta** — lista ampliada. |
| [`fase-04-subhitos.md`](fase-04-subhitos.md) | Fase 4 (distribución / ISO / v1.0); **abierta**. |
| [`post-v1-subhitos.md`](post-v1-subhitos.md) | Ideas post-v1.0 como sub-hitos exploratorios. |

**Reportes de cierre de fase** (bitácora humana): [`../phase-reports/README.md`](../phase-reports/README.md).

**No sustituye** ADRs ni `jsonrpc-protocol.md`: cuando un sub-hito cambie contrato o arquitectura, actualizar esos artefactos en el mismo cambio.
