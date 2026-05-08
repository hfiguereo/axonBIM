# Guía: estructura de sub-hitos del ROADMAP

Propósito en una frase: dar **contexto ejecutable** (qué / cómo / por qué / cuándo está hecho) sin convertir [`ROADMAP.md`](../../ROADMAP.md) en un manual infinito.

---

## 1. Plantilla por sub-hito

Cada sub-hito se escribe con el mismo esqueleto:

```markdown
### SH-Fx-NN — Título corto
- **Estado:** Cerrado | En curso | Abierto
- **Qué:** resultado observable (producto o verificación).
- **Cómo:** capa principal (Godot / Python / RPC / docs / CI) y enfoque; sin micro-diseño salvo que sea estabilizador.
- **Por qué:** qué riesgo o punto ciego evita; alineación con principios del ROADMAP.
- **Hecho cuando:** criterio verificable (test, demo, checklist, release).
- **Evidencia / enlaces:** rutas, tests, reportes, ADRs (opcional).
```

**Convención de ID:** `SH-F1-01` = sub-hito 01 de Fase 1. Los números son estables; si un ítem se abandona, marcar **Estado: Descartado** y una línea **Nota** en lugar de renumerar (evita roturas en conversaciones y commits).

---

## 2. Relación con otros documentos

| Artefacto | Rol |
|-----------|-----|
| `ROADMAP.md` | Horizonte, hitos [x]/[ ] y criterios de salida por fase. |
| `docs/roadmap/fase-0x-subhitos.md` | Detalle operativo **por fase**. |
| `docs/phase-reports/phase-N-report.md` | Cierre narrativo cuando una fase se declare cerrada. |
| `docs/architecture/decisions/` | Decisiones difíciles de revertir tocadas por un sub-hito. |
| `docs/architecture/jsonrpc-protocol.md` | Contrato RPC; obligatorio si el sub-hito añade o cambia métodos. |

### 2.1. Estructura homogénea por archivo de fase

Cada `fase-0x-subhitos.md` sigue este orden (omite secciones vacías):

1. **Sub-hitos ya cubiertos** — Tronco alineado con hitos [x] del ROADMAP; **Estado: Cerrado** salvo nota explícita (*parcial*).
2. **Pendientes hacia el criterio de salida** — Trabajo que falta para cerrar la fase.
3. **Mejoras posibles** — Backlog que no redefine el criterio (típico en fases ya cerradas: Fase 1–2).

`post-v1-subhitos.md` usa solo lista exploratoria bajo **Sub-hitos exploratorios** (sin criterio de release).

---

## 3. Mejoras de estructura permitidas (sin gran refactor)

- Añadir sub-hitos **nuevos** con el siguiente `NN` libre.
- Dividir un sub-hito **demasiado grande** en `SH-Fx-NNa` / `NNb` solo si aporta claridad; preferir descomponer en dos filas con IDs nuevos.
- Mantener el pipeline **analítico** como columna vertebral donde el producto pueda avanzar sin motor CAD pesado (especialmente entrega 2D normada); el *cómo* debe decirlo explícitamente.

---

## 4. Mantenimiento

Al cerrar un sub-hito: actualizar **Estado**, **Hecho cuando** y **Evidencia**; reflejar el hito correspondiente en `ROADMAP.md` si aún no estaba tachado.

Al abrir un trabajo nuevo: preferir **un sub-hito = un PR o una cadena corta de PRs**, no mezclar fases en el mismo cambio salvo dependencia real.
