# Fase 2 — Sub-hitos complementarios (modelado interactivo)

**Referencia:** [`ROADMAP.md`](../../ROADMAP.md) §Fase 2 · **Cierre documental:** [`docs/phase-reports/phase-2-report.md`](../phase-reports/phase-2-report.md).

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

### SH-F2-02 — `geom.extrude_face` con validación y sonda OCP

- **Estado:** Cerrado
- **Qué:** Backend aplica extrusión analítica; devuelve malla + `topo_map` + métricas OCP de apoyo.
- **Cómo:** `handlers/geom.py`, `wall_extrude`, `ocp_brep` como verificación paralela.
- **Por qué:** Preparar terreno B-Rep sin bloquear el camino analítico; detectar divergencias temprano.
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

### SH-F2-10 — Documentar límites de OCP vs analítico para contribuyentes

- **Estado:** Cerrado
- **Qué:** Una sección breve “cuándo tocar OCP” en docs de geometría.
- **Cómo:** `docs/architecture/` o ampliar `phase-2-report.md`.
- **Por qué:** Evita que cada PR asuma que OCC es obligatorio para Fase 2.
- **Hecho cuando:** Texto aceptado y enlazado desde README de geometría interna.
- **Evidencia / enlaces:** [`docs/architecture/geometry-analytical-vs-ocp.md`](../architecture/geometry-analytical-vs-ocp.md), `AGENTS.md`.
