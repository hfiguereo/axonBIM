# ADR-0001: Multi-viewport y vistas ortogonales alineadas al backend

- **Estado:** Proposed
- **Fecha:** 2026-05-05
- **Autores:** @hfiguereo
- **Fase:** Transición Fase 2 → Fase 3

---

## Contexto

AxonBIM hoy usa un solo `SubViewport` 3D en Godot con cámara orbital y presets ortográficos. Esta aproximación funciona para modelado rápido, pero limita:

- vistas ortogonales técnicas independientes (escala por vista),
- composición de varias vistas simultáneas (planta/alzado/sección),
- preparación de salidas tipo lámina (sheet) con escalas y recortes por viewport.

Además, la intención del producto exige que las ortogonales técnicas se alineen con el **núcleo geométrico del backend Python** (misma semántica que la malla IFC expuesta a Godot) para evitar divergencias entre “vista de trabajo” y “vista documental”.

## Decisión

Adoptaremos una arquitectura de **multi-viewport en Godot** con estado por vista y proyección ortogonal alimentada por geometría calculada en el backend (pipeline analítico actual, RPC `draw.*`).

Concretamente:

1. Godot seguirá siendo responsable de UI y renderizado, pero cada viewport tendrá su propio estado (`camera`, `scale_hint`, `clip`, `mode`).
2. Las ortogonales “de documentación” consultarán al backend para datos de encuadre/recorte derivados del modelo de sesión.
3. La serialización de proyecto incorporará un bloque de `viewports` para permitir independencia de escalas y futura maquetación en hojas.

## Alternativas consideradas

### Alternativa A — Mantener un solo viewport con presets

- **Descripción:** conservar cámara única y ampliar botones/atajos.
- **Pros:** costo bajo; casi sin migración.
- **Contras:** no hay independencia real de escala/recorte; difícil evolucionar a layout tipo lámina.
- **Motivo por el que se descartó:** no satisface el objetivo de vistas técnicas separadas.

### Alternativa B — Resolver todas las vistas en backend y dibujar 2D puro en frontend

- **Descripción:** Godot sólo recibiría proyecciones 2D finales para todo.
- **Pros:** máxima consistencia normativa con la geometría de sesión en Python.
- **Contras:** experiencia interactiva más rígida; incremento de complejidad RPC y latencia.
- **Motivo por el que se descartó:** reduce flexibilidad de interacción y sobrecarga temprana del puente.

## Consecuencias

### Positivas

- Escala por viewport independiente y futura reutilización en hojas.
- Mejor alineación entre vistas ortogonales y geometría servida por el backend.
- Camino claro para layouts de documentación tipo Revit.

### Negativas / trade-offs aceptados

- Más complejidad de estado en frontend (múltiples cámaras/overlays).
- Contrato RPC más amplio para viewport técnico.
- Necesidad de pruebas adicionales de sincronía frontend/backend.

### Neutras

- El viewport único actual puede convivir durante migración (feature flag).

## Plan de implementación (opcional)

- [ ] Paso 1: introducir `ViewportState` serializable (escala, modo, clip, encuadre).
- [ ] Paso 2: crear layout inicial de 2–4 `SubViewport` en Godot con sincronización básica.
- [ ] Paso 3: exponer endpoints backend para encuadre ortogonal y recorte coherente con `draw.ortho_snapshot`.
- [ ] Paso 4: persistir/recuperar estados de viewport en proyecto.
- [ ] Paso 5: prototipo de hoja con viewports independientes.

## Referencias

- PR que acompaña este ADR: N/A (chat incremental)
- ADRs relacionados: `0000-template.md`
- Especificación puente: `docs/architecture/jsonrpc-protocol.md`
