# ADR-0002: Estrategia combinada 2D (analítica + ortográfica) y export DXF

- **Estado:** Accepted
- **Fecha:** 2026-05-06
- **Autores:** @hfiguereo
- **Fase:** Transición Fase 2 -> Fase 3

---

## Contexto

Las vistas 2D de AxonBIM ya pueden generarse desde backend (`draw.ortho_snapshot`) y
también mostrarse como proyección ortográfica del modelo 3D en Godot.

Ninguna vía por sí sola cubre todos los casos de producto en este momento:

- El modo analítico es rápido y limpio para geometría cubierta por reglas (muros caja),
  pero su cobertura todavía es incremental.
- El modo ortográfico de modelo conserva toda la interacción de viewport y sirve como
  respaldo cuando el snapshot no aplica o falla.
- La exportación CAD debe salir siempre desde el backend (fuente autoritativa), no desde
  una captura visual.

## Decisión

Adoptar una estrategia combinada estable:

1. **Visualización 2D por defecto:** modo `auto` en frontend.
   - Intenta snapshot 2D analítico (`draw.ortho_snapshot`, `projection_engine=analytical`).
   - Si falla o retorna sin líneas, cae a vista ortográfica de modelo.
2. **Conmutación de usuario:** exponer modos de vista 2D en UI:
   - `Auto (vectorial->orto)`,
   - `Plano vectorial`,
   - `Modelo ortográfico`.
3. **Exportación DXF:** `draw.export_dxf_walls` usa proyección analítica del backend y
   se mantiene independiente del modo visual activo.
4. **Rol OCC/OCP:** conservar OCP para `geom.*` y casos sin equivalente analítico;
   reducir su uso en `draw.*` para muros caja cuando la vía analítica cubra el caso.

## Alternativas consideradas

### Alternativa A - Solo vectorial backend

- **Pros:** consistencia geométrica centralizada.
- **Contras:** cobertura insuficiente en esta etapa para reemplazar todo el flujo visual.

### Alternativa B - Solo ortográfico de modelo

- **Pros:** interacción inmediata sin reglas adicionales.
- **Contras:** no produce salida vectorial técnica por sí mismo.

### Alternativa C - OCC obligatorio para todo `draw.*`

- **Pros:** continuidad con el kernel B-Rep en snapshots.
- **Contras:** mayor costo y dependencia donde la proyección analítica ya resuelve.

## Consecuencias

### Positivas

- Ruta de producto clara entre precisión técnica y cobertura interactiva.
- Menor acoplamiento de snapshots 2D al pipeline OCP en casos simples.
- Export DXF trazable desde la geometría autoritativa del backend.

### Negativas / trade-offs aceptados

- Más estados de UI (modos 2D y fallback).
- Necesidad de documentar límites de cada modo para evitar confusión.

## Referencias

- `frontend/scripts/main/main_scene.gd`
- `src/axonbim/handlers/draw.py`
- `src/axonbim/drawing/dxf_walls.py`
- `docs/architecture/jsonrpc-protocol.md`
