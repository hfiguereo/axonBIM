# ROADMAP — AxonBIM

Hoja de ruta estratégica. Asume una dedicación promedio de **10 horas semanales**.

> Este documento es planificación de producto, **no** una regla para el agente. El código se evalúa por su correctitud actual, no por la fase del roadmap.

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

**Directrices UI/UX (alcance de Fase 2):**

- [ ] Toolbar minimalista orientada a iconos (texto visible minimo).
- [ ] Tooltip al pasar el cursor por cada herramienta (nombre corto + accion).
- [ ] Iconografia procedimental generada por codigo en el **frontend (Godot)** para evitar assets manuales.
- [ ] Iconos de tamaño legible en monitor de laptop/escritorio (no miniatura).
- [ ] Layout de texto secundario adaptable para no saturar la interfaz.
- [ ] Paneles laterales flotantes y autoajustables (dock/undock, resize y colapso).

**Desarrollo en Fedora (Godot / Flatpak / render):**

- [ ] Flatpak solo al minimo necesario; Godot de trabajo con **binario oficial**
  (u otra via sin sandbox) como norma.
- [ ] Revalidar **Forward+ / Vulkan** por **micro-bloques** en la maquina Fedora
  de referencia; mantener **GL Compatibility** como fallback documentado hasta
  aislar el entorno grafico. No bloquea el nucleo BIM del roadmap.

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
