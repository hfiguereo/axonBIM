# Fase 2 — Sub-hitos complementarios (modelado interactivo)

**Referencia:** [`ROADMAP.md`](../../ROADMAP.md) §Fase 2 · **Cierre documental:** [`docs/phase-reports/phase-2-report.md`](../phase-reports/phase-2-report.md). Post-cierre: oleada «cáscara de vivienda» (**SH-F2-11…13**).

## Sub-hitos ya cubiertos (ROADMAP [x], cierre documental Fase 2)

---

### SH-F2-01 — Herramienta Push/Pull y edición por cara

- **Estado:** Cerrado
- **Qué:** Gesto cara + arrastre en Godot; modo edición por elemento coherente con picking.
- **Cómo:** Herramientas en `frontend/scripts/`, envío de vector al backend.
- **Por qué:** Valida el bucle interactivo sin depender solo de botones de demo.
- **Hecho cuando:** Usuario puede extruir una cara en flujo normal de trabajo.
- **Evidencia / enlaces:** escena principal, handlers `geom.extrude_face`.

---

### SH-F2-02 — `geom.extrude_face` con validación analítica

- **Estado:** Cerrado
- **Qué:** Backend aplica extrusión analítica; devuelve malla + `topo_map` + `debug_mesh_stats` sobre la malla devuelta.
- **Cómo:** `handlers/geom.py`, `wall_extrude`.
- **Por qué:** Mantener una única fuente de verdad geométrica alineada con Godot.
- **Hecho cuando:** RPC estable; tests de geometría y handlers verdes.
- **Evidencia / enlaces:** tests `tests/unit/geometry/`, `test_handlers_*`.

---

### SH-F2-03 — Identidad topológica (`topo_id`, registro de sesión)

- **Estado:** Cerrado
- **Qué:** Caras direccionables entre operaciones; mapas ante cambios de hash.
- **Cómo:** `topo_registry`, `topological-naming.md`.
- **Por qué:** Sin identidad, Push/Pull destruye el modelo mantenible a medio plazo.
- **Hecho cuando:** Extrusión y undo mantienen picking coherente en UI **y** regresiones de malla/topología en tests pasan.
- **Evidencia / enlaces:** `docs/architecture/topological-naming.md`.

---

### SH-F2-04 — Undo / Redo vía RPC en UI

- **Estado:** Cerrado
- **Qué:** `history.undo` / `history.redo` integrados; estados vacíos manejados.
- **Cómo:** `handlers/history.py`, UI Godot.
- **Por qué:** Reversibilidad en dominio, no solo “ocultar malla”.
- **Hecho cuando:** Ciclo extrude → undo → redo verificado manualmente y en tests donde existan.
- **Evidencia / enlaces:** tests integración wall roundtrip (donde aplique).

---

### SH-F2-05 — Persistencia SQLite de la pila de historial

- **Estado:** Cerrado
- **Qué:** Colas undo/redo sobreviven a reinicio del proceso backend (misma ruta de DB).
- **Cómo:** `axonbim/history/sqlite_store.py`, `AXONBIM_HISTORY_DB` opcional.
- **Por qué:** Evita pérdida de trabajo en reinicios accidentales; separa memoria de proceso de intención del usuario.
- **Hecho cuando:** Test `tests/unit/test_sqlite_history_persistence.py` verde.
- **Evidencia / enlaces:** `sqlite_store.py`.

---

### SH-F2-06 — Regresión geométrica numérica

- **Estado:** Cerrado
- **Qué:** Snapshots de malla con tolerancia ~1e-6 donde esté adoptado.
- **Cómo:** Tests bajo `tests/unit/geometry/`.
- **Por qué:** Cambios “pequeños” en float o orden de vértices no deben romper identidad silenciosamente.
- **Hecho cuando:** Suite relevante verde en CI.
- **Evidencia / enlaces:** `test_mesh_snapshots.py`, etc.

---

### SH-F2-07 — Estrés multi-muro (criterio 50+)

- **Estado:** Cerrado
- **Qué:** Decenas de muros + extrusiones dispersas sin corrupción del registro.
- **Cómo:** `tests/integration/test_phase2_many_walls_stress.py` (55 muros).
- **Por qué:** Demostración automática del criterio de salida; evita sorpresas en proyectos medianos.
- **Hecho cuando:** Test verde.
- **Evidencia / enlaces:** ROADMAP criterio Fase 2.

---

## Mejoras aplicadas después del cierre documental Fase 2

### SH-F2-08 — Ampliar tipos de operación en historial

- **Estado:** Cerrado
- **Qué:** Apilar undo para más acciones que `extrude_face` (p. ej. borrado de muro, create encadenado).
- **Cómo:** Contrato uniforme de payload por `op_kind`; validación en `history.py`.
- **Por qué:** Hoy el punto ciego es **inconsistencia de UX** (“a veces deshace, a veces no”).
- **Hecho cuando:** Lista de operaciones soportadas documentada en protocolo + tests.
- **Evidencia / enlaces:** `jsonrpc-protocol.md` §5.5, `tests/unit/test_history_extended.py`.

---

### SH-F2-09 — Historial scoped por proyecto / sesión IFC

- **Estado:** Cerrado
- **Qué:** Al abrir o crear otro IFC, la pila no mezcla operaciones de archivos distintos.
- **Cómo:** Columna `scope` en SQLite + `project.save` / sesión nueva (`__unsaved__`).
- **Por qué:** Persistencia global es simple pero genera **deshacer peligroso** al cambiar de archivo.
- **Hecho cuando:** Comportamiento definido, documentado y testeado.
- **Evidencia / enlaces:** `sqlite_store.py`, test `test_history_scope_isolation`.

---

### SH-F2-10 — Documentar pipeline analítico para contribuyentes

- **Estado:** Cerrado
- **Qué:** Texto breve sobre el pipeline analítico compartido (malla Godot + snapshot 2D).
- **Cómo:** `docs/architecture/geometry-analytical.md`.
- **Por qué:** Evita que cada PR asuma un segundo motor geométrico paralelo.
- **Hecho cuando:** Texto aceptado y enlazado desde `AGENTS.md`.
- **Evidencia / enlaces:** [`docs/architecture/geometry-analytical.md`](../architecture/geometry-analytical.md), `AGENTS.md`.

---

## Oleada «cáscara de vivienda» (post-cierre Fase 2)

Trabajo **posterior** al criterio de salida ya demostrado (50+ muros + extrusiones). Orden sugerido: **niveles → huecos → losas** (cada paso habilita el siguiente sin bloquear el anterior por completo, pero el datum estable simplifica cotas y vistas).

**Referencia:** [`ROADMAP.md`](../../ROADMAP.md) §Fase 2 (bloque “Hacia paridad mínima…”). Simbología 2D de huecos sigue en Fase 3 — [`fase-03-subhitos.md`](fase-03-subhitos.md) (p. ej. SH-F3-04 / SH-F3-06).

---

### SH-F2-11 — Niveles de trabajo e `IfcBuildingStorey`

- **Estado:** Cerrado (niveles + `project.open` + UI «Abrir IFC…» y recarga de mallas / árbol de muros; muros no-caja del IFC se omiten con contador `walls_skipped`).
- **Qué:** Al menos un **forjado/nivel** explícito en producto (además del datum fijo actual), reflejado en IFC como `IfcBuildingStorey` coherente con trazo de muros y con vistas 2D/3D.
- **Cómo:** Sesión IFC (`IfcSession.list_storeys_ordered`, `create_storey`, `set_active_storey`, `open_existing`), RPC `project.list_storeys` / `create_storey` / `set_active_storey` / `project.open`, UI Godot (Propiedades: lista + añadir nivel; cinta: Abrir/Guardar IFC); herramienta muro usa cota Z del nivel activo (`work_plane_elevation_m`).
- **Por qué:** Sin niveles, la paridad **Revit-like** por planta y losas con sentido constructivo quedan artificialmente limitadas; reduce ambigüedad al añadir huecos y losas.
- **Hecho cuando:** Usuario puede asignar o cambiar nivel activo, guardar `.ifc`, **abrir** otro `.ifc` y ver muros rehidratados; documentado en `jsonrpc-protocol.md` si hay RPC nuevo.
- **Evidencia / enlaces:** `session.py`, `handlers/project.py`, `wall_import.py`, `tests/unit/test_handlers_project_storeys.py`, `tests/unit/test_handlers_project_open.py`, `jsonrpc-protocol.md` §5.5, escena principal + `create_wall_tool.gd` + `project_view.gd`.

---

### SH-F2-12 — Huecos hosteados en muro (puerta / ventana MVP)

- **Estado:** Cerrado
- **Qué:** Hueco rectangular en muro caja con ``IfcOpeningElement`` + ``IfcRelVoidsElement`` y malla con recorte analítico en caras ±n.
- **Cómo:** ``ifc.create_wall_opening``, ``axonbim/ifc/opening.py``, ``wall_mesh_for_spec`` / ``tri_logical_face``; botón Propiedades «Hueco demo».
- **Hecho cuando:** RPC + tests + protocolo; flujo manual en UI.
- **Evidencia / enlaces:** ``tests/unit/test_handlers_mvp_shell.py``, ``jsonrpc-protocol.md`` §5.2.

---

### SH-F2-13 — Losas / forjado simple (MVP)

- **Estado:** Cerrado
- **Qué:** Losa prismática por polígono convexo CCW en planta, cara superior en cota configurable (por defecto nivel activo), ``IfcSlab`` + malla Godot.
- **Cómo:** ``ifc.create_slab``, ``axonbim/ifc/slab.py``, ``slab_prism_mesh``; historial ``create_slab`` / ``delete_slab``; botón «Losa demo».
- **Hecho cuando:** RPC + tests + protocolo; elemento en árbol IFC / visor.
- **Evidencia / enlaces:** ``tests/unit/test_handlers_mvp_shell.py``, ``jsonrpc-protocol.md`` §5.2 / §5.5.
