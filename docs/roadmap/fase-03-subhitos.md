# Fase 3 — Sub-hitos complementarios (normativa y motor 2D)

**Referencia:** [`ROADMAP.md`](../../ROADMAP.md) §Fase 3 · **Extracto normativo (paráfrasis):** [`docs/normativa/mived/ccrd-vol-i.md`](../normativa/mived/ccrd-vol-i.md).

**Nota de alcance:** la entrega MIVED puede avanzar con **proyección analítica** y reglas 2D; **OCP/OCC no es requisito** para muchos sub-hitos si el *cómo* lo deja explícito. Donde un sub-hito beneficie de sólidos, se indica como opción, no como bloqueo.

**Criterio de salida (pendiente):** planta arquitectónica residencial MIVED lista para presentación oficial ([`ROADMAP.md`](../../ROADMAP.md) §Fase 3).

## Sub-hitos ya cubiertos (ROADMAP: hitos [x] en tronco)

Esto **no** cierra la fase: es la base técnica sobre la que se construye la capa normada.

---

### SH-F3-16 — `draw.ortho_snapshot` (proyección analítica y opción OCP)

- **Estado:** Cerrado
- **Qué:** Vistas ortogonales `top` / `front` / `right` con líneas 2D rasterizables y metadatos de encuadre; motor `projection_engine` **analítico** por defecto, **OCP** opcional.
- **Cómo:** Handlers `draw.*`, geometría de muro/caja y/o malla OCP según parámetros.
- **Por qué:** Sin snapshot estable no hay canvas 2D ni export que alimente la Fase 3.
- **Hecho cuando:** RPC documentado y consumido por Godot con estados de error/fallback aceptados.
- **Evidencia / enlaces:** `docs/architecture/jsonrpc-protocol.md`, tests `test_handlers_draw.py`, UI canvas 2D.

---

### SH-F3-17 — `draw.export_dxf_walls` (proyección analítica)

- **Estado:** Cerrado
- **Qué:** Export DXF de muros en planta (u orientación acordada) con capa base (`WALLS` u convención actual).
- **Cómo:** `ezdxf` en backend; no sustituye por sí solo plano MIVED completo.
- **Por qué:** Entrega vectorial temprana y verificación de proyección respecto al modelo IFC.
- **Hecho cuando:** Flujo desde Godot o tests que generan DXF válido.
- **Evidencia / enlaces:** `jsonrpc-protocol.md`, botón export en UI Proyecto.

---

### SH-F3-18 — UI 2D base en Godot (pestañas, PNG, DXF, Project Browser)

- **Estado:** Cerrado (parcial respecto al criterio de salida de fase)
- **Qué:** Pestañas de vista modelado/2D, export PNG de vistas ortográficas, export DXF muros, vistas 2D en Project Browser con estados de carga/error/fallback en canvas OCC.
- **Cómo:** `main_scene` / docks / RPC `draw.ortho_snapshot` y `draw.export_dxf_walls`.
- **Por qué:** Da **superficie de producto** para iterar simbología y entrega sin reescribir el visor 3D cada vez.
- **Hecho cuando:** Demo manual reproducible según `docs/manual-de-axonbim.md` (secciones 2D vigentes).
- **Evidencia / enlaces:** `CHANGELOG.md` [0.1.0-alpha.2], manual de usuario.

---

## Pendientes hacia el criterio de salida MIVED

---

### SH-F3-01 — Contrato de “hoja” y vista de entrega

- **Estado:** Abierto
- **Qué:** Definición estable de escala, marco útil, área de dibujo y metadatos mínimos por hoja (aunque sea interno en JSON o recurso Godot).
- **Cómo:** Decisión de capa: backend (plantilla + export) vs Godot (layout) vs mixto; documentada en ADR corto si hay dos fuentes de verdad.
- **Por qué:** Sin esto, cajetín/PDF/sección se implementan como parches inconexos (punto ciego de integración).
- **Hecho cuando:** Un flujo “exportar hoja planta A1/A3 de prueba” con escala declarada en archivo o en metadatos exportados.
- **Evidencia / enlaces:** —

---

### SH-F3-02 — Tabla de capas y tipos de línea (CCRD / convención interna)

- **Estado:** Parcial (convención interna + registro DXF + test de capas en export de ejemplo).
- **Qué:** Mapeo normativo → capas DXF/PDF (nombres, colores, grosores) según extracto operativo propio (sin copiar norma literal).
- **Cómo:** Módulo de estilo 2D en Python (p. ej. ampliación de ezdxf) o tabla versionada en `docs/normativa/` + código.
- **Por qué:** La simbología “estricta” necesita **fuente única** para no diverger entre PNG, DXF y PDF.
- **Hecho cuando:** Test o fixture que valida presencia de capas clave en un export de ejemplo.
- **Evidencia / enlaces:** [`layer_ids.py`](../../src/axonbim/drawing/layer_ids.py), [`draw-delivery-layers.md`](../../docs/architecture/draw-delivery-layers.md), `tests/unit/test_handlers_draw.py` (`test_draw_export_dxf_walls_writes_file`). Grosores y tipos de línea CCRD siguen en §4.2 / §3.7.3 extracto.

---

### SH-F3-03 — Grosores y jerarquía gráfica de muros en planta

- **Estado:** Abierto
- **Qué:** Representación de muros en planta alineada a la convención adoptada (no solo segmento centro).
- **Cómo:** Post-proceso sobre `draw.ortho_snapshot` / polilíneas analíticas; grosor según tabla SH-F3-02.
- **Por qué:** Diferencia entre “vista técnica” y “debug geométrico”.
- **Hecho cuando:** Comparación visual o vectorial aceptada contra checklist interno (golden file).
- **Evidencia / enlaces:** —

---

### SH-F3-04 — Modelo mínimo de huecos (puertas / ventanas)

- **Estado:** Abierto
- **Qué:** Entidades o parámetros IFC (o derivados) suficientes para **simbología** de aperturas en planta.
- **Cómo:** `ifc.create_*` incremental o importación; decidir MVP (rectángulo + eje + ancho/alto).
- **Por qué:** Arcos de puerta y líneas de ventana **no tienen anclaje** si el modelo solo tiene muros caja.
- **Hecho cuando:** Al menos un tipo de hueco en modelo de prueba aparece en 2D con convención acordada.
- **Evidencia / enlaces:** Dependencia lógica de modelado 3D: **SH-F2-12** ([`fase-02-subhitos.md`](fase-02-subhitos.md)).

---

### SH-F3-05 — Hatches y rellenos normados

- **Estado:** Abierto
- **Qué:** Patrones de sombreado según convención adoptada (materiales, zonas, recortes simples).
- **Cómo:** Generación vectorial (DXF hatch) y/o raster en PNG; evitar dependencia OCP si el alcance es 2D puro.
- **Por qué:** “Simbología técnica completa” sin sombreado suele fallar en revisión de planos.
- **Hecho cuando:** Leyenda + ejemplo en proyecto sintético exportado.
- **Evidencia / enlaces:** —

---

### SH-F3-06 — Simbología de aperturas en planta

- **Estado:** Abierto
- **Qué:** Arcos de puerta, muescas, líneas de ventana según convención adoptada.
- **Cómo:** Geometría 2D derivada de SH-F3-04 + reglas de dibujo.
- **Por qué:** Es el corazón del hito “sustituir proyección plana” del ROADMAP.
- **Hecho cuando:** Checklist visual interno cubierta en fixture de proyecto.
- **Evidencia / enlaces:** —

---

### SH-F3-07 — Sección arquitectónica MVP

- **Estado:** Abierto
- **Qué:** Al menos una sección **analítica** (corte por plano) con muros y forjados simplificados si aplica.
- **Cómo:** Corte contra cajas/volumenes simples; **opcional** refinar con OCP si hace falta calidad B-Rep.
- **Por qué:** El ROADMAP lista secciones como pendiente explícito en UI/entrega.
- **Hecho cuando:** Export PNG o PDF de sección de proyecto demo reproducible.
- **Evidencia / enlaces:** —

---

### SH-F3-08 — Export PDF reproducible

- **Estado:** Abierto
- **Qué:** PDF vectorial o híbrido con fuentes y márgenes definidos; misma semántica que DXF donde se prometa.
- **Cómo:** Librería Python (p. ej. ReportLab, cairo, o vía Godot según decisión SH-F3-01).
- **Por qué:** Presentación oficial casi siempre exige PDF; PNG no basta como único entregable.
- **Hecho cuando:** PDF de proyecto sintético pasa checklist de metadatos (escala, nombre proyecto, fecha).
- **Evidencia / enlaces:** —

---

### SH-F3-09 — Cajetín y rotulación MIVED

- **Estado:** Abierto
- **Qué:** Bloque de título con campos obligatorios acordados (proyecto, plano, revisión, responsable, etc.).
- **Cómo:** Plantilla parametrizada consumida por el mismo pipeline que SH-F3-08/02.
- **Por qué:** Criterio de salida ROADMAP (“presentación oficial”).
- **Hecho cuando:** Campos validados contra checklist interno MIVED (paráfrasis operativa).
- **Evidencia / enlaces:** —

---

### SH-F3-10 — Checklist MIVED automatizable

- **Estado:** Abierto
- **Qué:** Reglas ejecutables (capas presentes, textos mínimos, escala declarada, cajetín completo).
- **Cómo:** Comando o RPC `draw.validate_sheet` (nombre ilustrativo); resultado estructurado para UI.
- **Por qué:** Evita que la “norma en cabeza humana” sea el único control (punto ciego de QA).
- **Hecho cuando:** Proyecto bueno pasa; proyecto incompleto falla con mensajes accionables.
- **Evidencia / enlaces:** actualizar `jsonrpc-protocol.md` si hay RPC nuevo.

---

### SH-F3-11 — Paridad y trazabilidad entre formatos de salida

- **Estado:** Abierto
- **Qué:** Documento que declare qué se garantiza igual entre DXF / PDF / PNG (y qué no).
- **Cómo:** Sección en manual o `docs/architecture/`; tests de regresión mínimos por formato.
- **Por qué:** Evita expectativas falsas en presentación a terceros.
- **Hecho cuando:** Tabla “paridad” publicada y aceptada.
- **Evidencia / enlaces:** —

---

### SH-F3-12 — RPC y contrato para pipeline 2D de entrega

- **Estado:** Abierto
- **Qué:** Métodos estables para snapshot, export DXF/PDF, validación; versionado de parámetros.
- **Cómo:** Ampliaciones coherentes en `jsonrpc-protocol.md` + handlers `draw.*` / `project.*`.
- **Por qué:** Godot no debe adivinar payloads; el backend es autoridad.
- **Hecho cuando:** Documentación y tests de contrato alineados.
- **Evidencia / enlaces:** `jsonrpc-protocol.md`.

---

### SH-F3-13 — Evaluación explícita de `ifcopenshell.draw`

- **Estado:** Abierto
- **Qué:** Decisión documentada: adoptar, envolver o rechazar para casos concretos **sin duplicar** OCC salvo beneficio claro.
- **Cómo:** Spike corto + ADR o sección en reporte de fase.
- **Por qué:** El ROADMAP lo lista como pendiente opcional; sin decisión explícita es punto ciego de mantenimiento.
- **Hecho cuando:** ADR o informe de spike archivado.
- **Evidencia / enlaces:** —

---

### SH-F3-14 — Biblioteca de pruebas 2D (golden / snapshots)

- **Estado:** Abierto
- **Qué:** Proyectos sintéticos pequeños + archivos esperados (DXF/PDF hash o extractos) para CI.
- **Cómo:** `tests/fixtures/` + comparación tolerante.
- **Por qué:** La norma gráfica regresa con cada cambio de proyección o capa.
- **Hecho cuando:** Al menos un golden por eje crítico (planta + una simbología).
- **Evidencia / enlaces:** —

---

### SH-F3-15 — UX de entrega en Godot (flujo único)

- **Estado:** Abierto
- **Qué:** Flujo guiado: elegir hoja → previsualizar → export → resultado de validación SH-F3-10.
- **Cómo:** Paneles existentes (Proyecto / 2D) extendidos sin duplicar lógica normativa en GDScript.
- **Por qué:** Evita que el usuario tenga que ensambrar a mano pasos que el backend ya puede orquestar vía RPC.
- **Hecho cuando:** Demo grabada o checklist manual en `docs/manual-de-axonbim.md`.
- **Evidencia / enlaces:** —
