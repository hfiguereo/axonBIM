# ROADMAP — AxonBIM

Hoja de ruta estratégica. Asume una dedicación promedio de **10 horas semanales**.

> Este documento es planificación de producto, **no** una regla para el agente. El código se evalúa por su correctitud actual, no por la fase del roadmap.

**Desglose operativo (sub-hitos: qué / cómo / por qué):** [`docs/roadmap/README.md`](docs/roadmap/README.md).

---

## Principios de modelado

AxonBIM busca **una sola metodología** que combine lo útil de herramientas conocidas —rapidez de gesto (SketchUp), precisión y trazabilidad (Revit), fluidez espacial (Blender)— sin repetir sus defectos sistémicos. Principios operativos:

1. **Semántica primero.** Toda edición que importa al edificio pasa por **entidades IFC u objetos trazables**; no se fomenta geometría “suelta” sin dueño en el modelo.
2. **Backend como autoridad.** Validación, topología mutable, historial y persistencia viven en **Python**; el cliente **Godot** prioriza claridad, feedback y comandos breves.
3. **Topología estable.** Los gestos preservan o **mapean identidad** (`topo_id`, mapas cara→cara) para que el modelo siga siendo mantenible; se evita el caos de modelado directo sin estructura.
4. **Deshacer con sentido.** Las operaciones mutantes son **reversibles en dominio** (p. ej. historial de extrusiones), no un deshacer opaco desconectado del IFC.
5. **Flujo principal único.** Se minimizan **modos y wizards** para cambios de volumen habituales; pasos extra solo cuando el edificio, la seguridad de datos o la **norma** lo exijan.
6. **Rapidez sin caos.** La facilidad de uso no sacrifica **agrupación lógica implícita** (muros como productos con parámetros, no primitivas anónimas acumuladas).
7. **Evolución por fases.** La **precisión normativa y el rigor 2D** se endurecen al acercarse a entrega; el modelado exploratorio inicial no queda bloqueado por el ritual de cada detalle documental.

Estos principios **orientan** prioridades de producto; el detalle técnico sigue en `docs/architecture/` y en el protocolo JSON-RPC.

---

## Estado del tronco (sincronizado con alpha recientes)

Resumen de lo que **ya existe** en el repositorio y cómo encaja con las fases (sin sustituir los criterios de salida formales):

| Área | Qué hay hoy | Notas |
|------|-------------|--------|
| **Puente RPC** | TCP `5799` + Unix socket; `RpcClient`; protocolo en `jsonrpc-protocol.md` | Base Fase 1. |
| **OCC / 2D** | `draw.ortho_snapshot` con motor **analítico** u **OCP** (`projection_engine`); canvas 2D OCC en Godot con estados y fallback a ortográfico legacy | Cubre “motor 2D” operativo; **no** es aún plano MIVED completo (Fase 3). |
| **DXF** | `draw.export_dxf_walls` (proyección analítica de muros, capa `WALLS`) | Distinto de planta normada CCRD §3.7. |
| **Godot UI** | Cinta, pestañas de vista (modelado + 2D), docks desacoplables, vista flotante, tema `axon_theme.tres`, subventanas nativas (`embed_subwindows`), `EventBus` (piloto), `ViewportManager` (política de render del `SubViewport`) | Mejora producto sin cambiar la autoridad del backend. |
| **Worker headless** | Proceso Godot opcional en **puerto auxiliar** (`5800` default), métodos `worker.*` piloto; `WorkerManager` en Python; **ADR-0003** | Solo tareas **auxiliares** serializables; **no** sustituye IfcOpenShell/OCP como fuente de verdad. |
| **Modelado** | Crear muro, tipologías, Push/Pull, edición por elemento, `geom.extrude_face` con estadísticas OCP, `history.undo` / `history.redo`, malla analítica + ruta B-Rep en evolución | Fase 2: **cierre documental** en [`docs/phase-reports/phase-2-report.md`](docs/phase-reports/phase-2-report.md) + test `test_fifty_five_walls_extrude_subset_stable`. |

**Fases 3 y 4** siguen **abiertas**. Inventario explícito de pendientes: [`docs/phase-reports/fases-3-y-4-inventario-pendientes.md`](docs/phase-reports/fases-3-y-4-inventario-pendientes.md).

---

## Fase 1 — El puente de comunicación  *(Mes 1–3)*

**Objetivo:** Lograr que Godot y Python hablen entre sí de forma estable.

**Hitos:**

- [x] Setup del entorno dual (uv + Godot 4.x).
- [x] Pipeline de GitHub Actions: lint, type check, pytest, Godot headless.
- [x] Servidor JSON-RPC 2.0 en Python sobre socket Unix (+ TCP loopback para Godot).
- [x] Cliente `RpcClient` (autoload) en Godot con manejo de errores, timeouts y reconexión automática.
- [x] Demo end-to-end: botón en Godot → solicitud `ifc.create_wall` → Python responde con vértices/caras → Godot dibuja.
- [x] Documentación viva del protocolo en `docs/architecture/jsonrpc-protocol.md`.
- [x] **Extensión documentada:** puerto auxiliar del **worker Godot** (`worker.*`, framing idéntico; ver §5.7 del protocolo y **ADR-0003**). Opcional en runtime (`AXONBIM_SPAWN_GODOT_WORKER`).

**Criterio de salida:** un usuario puede crear un muro IFC clickeando un botón, ver la malla, y el muro persiste en disco como `.ifc` válido. **✅ Alcanzado en `v0.1.0-alpha.1`.**

---

## Fase 2 — Modelado interactivo  *(Mes 4–9)*

**Objetivo:** Manipulación geométrica directa y sincronización bidireccional.

**Hitos:**

- [x] Herramienta gráfica Push/Pull en Godot (cara + arrastre; modo edición por elemento).
- [x] Backend recibe vector de extrusión (`geom.extrude_face`), usa cadena **OCP/OpenCASCADE** para validar/generar malla paralela y devuelve topología + `debug_ocp_mesh_stats` (convivencia con malla analítica).
- [x] Sistema de IDs topológicos persistentes en **evolución** (formato Fase 2; ver `docs/architecture/topological-naming.md` y tests de regresión). *Estabilidad entre operaciones cubierta por regresión geométrica + test de estrés multi-muro.*
- [x] Undo/Redo en sesión vía RPC (`history.undo` / `history.redo`) integrado en la UI.
- [x] Undo/Redo con **persistencia** en SQLite (`session_history.db` en el directorio de datos de AxonBIM, o ruta `AXONBIM_HISTORY_DB`) entre reinicios del backend. *(El módulo `axonbim/persistence/` sigue reservado para metadatos de proyecto más amplios.)*
- [x] Tests de regresión geométrica (snapshots con tolerancia 1e-6; suites RPC ampliadas).

**Criterio de salida:** un modelo de 50+ paredes editado interactivamente sin perder identidad topológica entre operaciones. **Demostración:** test de integración `tests/integration/test_phase2_many_walls_stress.py` (55 muros + extrusiones). Ver [`docs/phase-reports/phase-2-report.md`](docs/phase-reports/phase-2-report.md).

---

## Fase 3 — Normativa y motor 2D  *(Mes 10–15)*

**Objetivo:** Representación técnica bajo estándar dominicano.

**Contexto:** El motor **OCC** en el nombre histórico del roadmap se alinea hoy con **OpenCASCADE vía OCP** en el backend (`draw.ortho_snapshot`, mallas de muro, extrusión). La **salida gráfica normada** (CCRD/MIVED) es una capa adicional sobre ese pipeline.

**Hitos:**

- [x] Generador de vistas 2D en Python: **`draw.ortho_snapshot`** (analítico u OCP) + **`draw.export_dxf_walls`** (analítico). *Pendiente:* integración explícita con `ifcopenshell.draw` donde aporte valor sin duplicar OCC.
- [ ] Aplicación estricta de simbología y grosores del **CCRD Vol. I** (MIVED) — ver `docs/normativa/mived/ccrd-vol-i.md` §3.7.
- [ ] Sustitución de proyecciones “planas” por **simbología técnica** completa (hatches, arcos de puerta, líneas de ventana) según norma.
- [x] UI en Godot: pestañas de vista, modos 2D, export PNG, DXF muros, **Project Browser** con vistas 2D. *Pendiente:* secciones, PDF, checklist MIVED completo.
- [ ] Cajetín y rotulación bajo plantillas MIVED.

**Criterio de salida:** exportar una planta arquitectónica de un proyecto residencial cumpliendo MIVED, lista para presentación oficial.

---

## Fase 4 — Ecosistema y publicación  *(Mes 16–24)*

**Objetivo:** Distribución universal y refinamiento BIM colaborativo.

**Hitos:**

- [x] Navegador de proyecto en Godot (árbol + propiedades básicas). *Pendiente:* estructura espacial IFC según visión de producto completa.
- [ ] Implementación de estados ISO 19650 (WIP / Shared / Published / Rejected / Archive) con trazabilidad SQLite append-only.
- [ ] Congelamiento del entorno Python con PyInstaller o Conda-pack.
- [ ] Empaquetado conjunto Godot + Python en **Flatpak**.
- [ ] AppImage como alternativa portable.
- [ ] Sitio web, documentación de usuario, video tutoriales.
- [ ] **Lanzamiento v1.0**.

**Criterio de salida:** un arquitecto sin conocimientos técnicos descarga un Flatpak, abre AxonBIM, modela una vivienda y exporta planos MIVED — todo sin tocar la terminal.

---

## Más allá de v1.0 (ideas exploratorias)

- Colaboración en tiempo real (CRDT sobre el modelo IFC).
- Integración con motores de renderizado externos (Blender, Cycles).
- Plugin system para normativas de otros países.
- Mobile companion app para revisión en obra.
- IA asistente para clasificación automática de elementos IFC.
