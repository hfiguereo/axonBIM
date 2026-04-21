# ROADMAP — AxonBIM

Hoja de ruta estratégica. Asume una dedicación promedio de **10 horas semanales**.

> Este documento es planificación de producto, **no** una regla para el agente. El código se evalúa por su correctitud actual, no por la fase del roadmap.

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

**Criterio de salida:** un usuario puede crear un muro IFC clickeando un botón, ver la malla, y el muro persiste en disco como `.ifc` válido. **✅ Alcanzado en `v0.1.0-alpha.1`.**

---

## Fase 2 — Modelado interactivo  *(Mes 4–9)*

**Objetivo:** Manipulación geométrica directa y sincronización bidireccional.

**Hitos:**

- [ ] Herramienta gráfica Push/Pull en Godot (selección de cara + arrastre).
- [ ] Backend recibe el vector de extrusión, ejecuta booleana en OCP, actualiza IFC, devuelve nueva topología + mapa de IDs.
- [ ] Sistema de IDs topológicos persistentes (hash B-Rep estable).
- [ ] Undo/Redo con persistencia en SQLite (`axon_internal.db`).
- [ ] Tests de regresión geométrica (snapshots con tolerancia 1e-6).

**Criterio de salida:** un modelo de 50+ paredes editado interactivamente sin perder identidad topológica entre operaciones.

---

## Fase 3 — Normativa y motor 2D  *(Mes 10–15)*

**Objetivo:** Representación técnica bajo estándar dominicano.

**Hitos:**

- [ ] Generador de plantas 2D en Python (`ifcopenshell.draw` → `ezdxf`).
- [ ] Aplicación estricta de simbología y grosores del **CCRD Vol. I** (MIVED) — ver `docs/normativa/mived/ccrd-vol-i.md` §3.7.
- [ ] Sustitución de proyecciones 3D crudas por simbología técnica (hatches, arcos de puerta, líneas de ventana).
- [ ] UI en Godot para gestionar vistas (planta, alzado, sección) y exportar DXF/PDF.
- [ ] Cajetín y rotulación bajo plantillas MIVED.

**Criterio de salida:** exportar una planta arquitectónica de un proyecto residencial cumpliendo MIVED, lista para presentación oficial.

---

## Fase 4 — Ecosistema y publicación  *(Mes 16–24)*

**Objetivo:** Distribución universal y refinamiento BIM colaborativo.

**Hitos:**

- [ ] Navegador de proyecto en Godot (estructura espacial IFC, panel de propiedades).
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
