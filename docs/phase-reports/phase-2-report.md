# Fase 2 — Modelado interactivo

**Release de referencia:** `v0.1.0-alpha.2` · **Fecha de cierre documental:** 2026-05-07

> Reporte de cierre de la Fase 2 según [`ROADMAP.md`](../../ROADMAP.md): modelado directo, topología direccionable, deshacer/rehacer con respaldo en SQLite y prueba de estrés multi-muro. **No** sustituye la documentación de protocolo ni de normativa MIVED (Fase 3).

---

## 1. Resumen ejecutivo

- **Se consolidó** el ciclo *editar muro en 3D* → `geom.extrude_face` en Python → malla + `topo_map` de vuelta a Godot, con **Push/Pull** y edición por elemento en la UI.
- **Historial:** `history.undo` / `history.redo` por RPC; la pila vive en **SQLite** (`session_history.db` bajo el directorio de datos de AxonBIM, o ruta en `AXONBIM_HISTORY_DB`).
- **Verificación automática:** test de integración con **55 muros** y extrusiones en subconjunto (`tests/integration/test_phase2_many_walls_stress.py`), alineado al criterio de “50+ paredes” del roadmap.
- **Queda fuera de esta fase** (y sigue en roadmap): planos **MIVED** completos, **ISO 19650** en producto, empaquetado Flatpak y **v1.0**. Ver [`fases-3-y-4-inventario-pendientes.md`](fases-3-y-4-inventario-pendientes.md).

---

## 2. Qué puedes hacer hoy (demo corta)

1. Arranca backend y frontend como en el [`README.md`](../../README.md) o con `./start`.
2. Crea varios muros (herramienta de muro / cuadrícula).
3. Activa **Push/Pull** o extruye una cara: el backend devuelve malla actualizada y mapa de identidades.
4. Usa **Deshacer / Rehacer** en la UI: las operaciones soportadas (p. ej. `extrude_face`) se apilan en SQLite.
5. Opcional: reinicia solo el proceso Python y vuelve a conectar el cliente: la pila de deshacer **persiste** en disco mientras no borres la base ni llames a `reset_session()` (los tests de desarrollo sí resetean sesión a propósito).

---

## 3. Por dentro: módulos relevantes

| Zona | Rol |
|------|-----|
| `src/axonbim/handlers/geom.py` | `geom.extrude_face`: valida `topo_id`, extruye con cadena analítica + sonda OCP, registra undo. |
| `src/axonbim/handlers/history.py` | `history.undo` / `history.redo` aplican snapshots de muro. |
| `src/axonbim/history/sqlite_store.py` | Tablas `undo_stack` / `redo_stack` en SQLite. |
| `src/axonbim/geometry/topo_registry.py` | `guid` ↔ malla ↔ `WallSpec`; resolución de cara por `topo_id`. |
| `docs/architecture/topological-naming.md` | Convención de hashes de cara en Fase 2. |
| `frontend/scripts/main/main_scene.gd` (y herramientas) | Gestos, RPC y UI de historial. |

**Metáfora:** el backend es la **oficina técnica** que firma cada cambio geométrico; Godot es el **trazador** que obedece y muestra. La base SQLite es el **cuaderno de borradores** donde se apilan las últimas decisiones reversibles.

---

## 4. Recorrido de un flujo (extruir cara)

1. El usuario selecciona una cara en el viewport; Godot conoce el `topo_id` asociado a esa cara en la malla serializada.
2. Se envía `geom.extrude_face` con vector en metros.
3. El handler carga `WallSpec` y `Mesh` desde `topo_registry`, ejecuta `extrude_wall_face`, guarda snapshot anterior en SQLite (`push_undo`), actualiza IFC en memoria y sustituye malla en registro.
4. La respuesta incluye `mesh`, `topo_map` y estadísticas opcionales de malla OCP de apoyo.
5. Godot refresca el nodo de malla y re-enlaza picking con los nuevos `topo_id` según `topo_map`.

---

## 5. Decisiones y límites honestos

- **Una sola fuente de verdad:** toda mutación geométrica relevante pasa por Python; coincide con [`00-architecture.mdc`](../../.cursor/rules/00-architecture.mdc).
- **Persistencia del historial:** es **por máquina y proceso de backend**, no un “repositorio de proyecto” multiusuario. Cambiar de archivo IFC sin una política explícita puede dejar entradas de undo incoherentes; eso es mejora de producto futura (Fase 4 / contenedores).
- **Alcance de undo:** hoy centrado en operaciones tipo extrusión de cara; otras mutaciones pueden no apilarse aún.

---

## 6. Números de la fase (orientativos)

- **Prueba de estrés:** 55 muros IFC + 3 extrusiones; tiempo de ejecución del orden de segundos en CI local (`pytest`).
- **Líneas de código:** ver `git log` y estadísticas del repositorio; este reporte no sustituye métricas de release.

---

## 7. Lo que todavía no hace (Fase 2 vs producto completo)

- No hay **planos de presentación MIVED** automáticos.
- No hay **estados ISO 19650** aplicados al contenedor de entrega.
- No hay **instalador único** para usuario final sin terminal.

---

## 8. Qué viene después

- **Fase 3:** capa normativa y gráfica 2D de entrega; ver inventario en [`fases-3-y-4-inventario-pendientes.md`](fases-3-y-4-inventario-pendientes.md).
- **Fase 4:** empaquetado, trazabilidad de estados y release pública.

---

## 9. Glosario breve

| Término | Significado aquí |
|---------|------------------|
| **topo_id** | Identificador estable de una cara lógica en la malla expuesta al cliente. |
| **topo_map** | Diccionario cara-antigua → cara-nueva tras una edición. |
| **Push/Pull** | Gesto de extruir o acortar un volumen empujando una cara. |
| **OCP** | OpenCASCADE vía bindings Python; usado para validación y métricas paralelas a la malla analítica. |
| **SQLite undo** | Persistencia LIFO de snapshots de muro para deshacer/rehacer. |
| **RPC** | JSON-RPC 2.0 sobre TCP/socket entre Godot y Python. |
