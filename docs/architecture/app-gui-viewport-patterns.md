# Patrones App/Gui y viewport único

Referencia de diseño para AxonBIM, alineada con prácticas probadas en software libre de CAD/CAE (p. ej. **FreeCAD**: capa `App` vs `Gui`, visor 3D como dueño del picking). No implica adoptar Coin3D ni el mismo binario monolítico; solo **separación de responsabilidades** y **entrada 3D explícita**.

---

## 1. Inspiración: App vs Gui (FreeCAD y similares)

En proyectos como **FreeCAD**:

- **`App`** — documento, objetos de datos, geometría y lógica que pueden existir **sin ventana** (consola, tests, batch).
- **`Gui`** — representación visual, vistas, selección, herramientas modales; depende de `App`, no al revés.

**Beneficio:** la “verdad” del modelo no vive en widgets; la UI es reemplazable y testeable por capas.

---

## 2. Mapeo en AxonBIM

| Patrón libre | AxonBIM |
|--------------|---------|
| Capa **App** (datos + reglas) | **Backend Python**: IFC, geometría, validación, `system.*`, `ifc.*`, `project.*`. |
| Capa **Gui** (vista + input) | **Frontend Godot**: escenas, `RpcClient`, herramientas de usuario, render. |
| Frontera estable | **JSON-RPC 2.0** (framing LSP, transporte en [jsonrpc-protocol.md](jsonrpc-protocol.md)). |
| “ViewProvider” (vista del objeto) | Nodos que **muestran** entidades devueltas por el backend (`guid` → malla en el viewport), sin duplicar reglas de negocio. |

Reglas de proyecto: [`.cursor/rules/00-architecture.mdc`](../../.cursor/rules/00-architecture.mdc).

---

## 3. Viewport único (entrada 3D)

En CAD libre, el **visor 3D** concentra el ratón, el ray-pick y los modos de selección; no se reparte el input entre nodos 3D arbitrarios sin contrato.

En Godot, un **SubViewport** embebido en UI **no** debe asumir que `Node3D._unhandled_input` recibirá el ratón de forma fiable. Patrón **funcional** en AxonBIM:

1. **Un control** que envuelve el viewport (`SubViewportContainer`) recibe `gui_input`.
2. Las coordenadas para rayos de cámara salen del **`SubViewport`** (`get_mouse_position()`), coherentes con `Camera3D.project_ray_origin` / `project_ray_normal`.
3. La herramienta activa (p. ej. crear muro) interpreta esos clics y llama al backend por **RPC**; la geometría definitiva la resuelve Python.

Así el “viewport” es **único canal de entrada** hacia las herramientas 3D, análogo a centralizar el pick en un `View3DInventorViewer` en lugar de repartir eventos opacos por el grafo.

**Navegación de cámara (Fase 2):** el `SubViewportContainer` primero delega en `OrbitCameraRig` (rueda, MMB, Mayús+MMB, gestos de pellizco y equivalentes trackpad Alt/Mayús/Ctrl+LMB); la cámara usa **Z arriba** para alinear el visor con el plano de trabajo XY. Si el rig no consume el evento, siguen el hover de Push/Pull (cara lógica por `topo_id`) y las herramientas con **LMB**. Los atajos de vista (p. ej. teclas **1–4**, **Inicio/R**, teclado numérico) se leen en `_unhandled_input` cuando el ratón está sobre el contenedor del viewport.

---

## 4. Herramientas como estado + manejador

Patrón cercano a **editores con herramientas** (Blender, KiCad): una **herramienta activa** define qué significa cada clic en el lienzo/vista.

- El botón de la barra solo **activa** o **cancela** la herramienta.
- Los clics en el área 3D los procesa la herramienta (dos puntos → `ifc.create_wall`, etc.).
- Tras éxito o error RPC, la herramienta **termina** o deja el estado coherente con la UI.

---

## 5. Depuración por capas

Cuando algo falla, aplicar [`.cursor/rules/80-debug-troubleshooting.mdc`](../../.cursor/rules/80-debug-troubleshooting.mdc): separar **parse GDScript**, **transporte RPC**, **backend Python** y **render/GPU** antes de cambiar código en varias capas a la vez.

---

## 6. Primera cara: de FreeCAD (SubElement → comando) a AxonBIM

En **FreeCAD**, el flujo típico es: el usuario selecciona una **cara** (sub-elemento de un `Part::Feature`); el comando en **Gui** envía a **App** la referencia al objeto de documento + la cara; **App** ejecuta la operación y actualiza el modelo; **Gui** refresca la vista.

En AxonBIM el paralelo operativo es:

| FreeCAD (idea) | AxonBIM |
|----------------|---------|
| `App::DocumentObject` + cara | Producto IFC identificado por `guid` + **cara** identificada por `topo_id` (hash estable por cara en la malla RPC, ver [meshing.py](../../src/axonbim/geometry/meshing.py)). |
| Selección en el visor 3D | **Gui:** rayo desde la cámara → triángulo → índice `i` → `topo_ids[i]` del diccionario de malla (cuando el frontend envíe `topo_ids` en el modelo de escena). |
| Comando (extruir, etc.) | **App:** método RPC `geom.extrude_face` con `{ "topo_id", "vector" }`. Errores tipados, p. ej. `-32002` si el id no existe en la sesión. |
| ViewProvider | Nodos Godot que muestran la malla devuelta; no recalculan geometría. |

**Estado actual (transición Fase 1 → 2):**

- Tras `ifc.create_wall`, el backend **registra** cada `topo_id` de la malla en [`topo_registry`](../../src/axonbim/geometry/topo_registry.py) y asocia la malla al `guid` del muro.
- `geom.extrude_face` **resuelve** el `topo_id`, valida sesión y hoy devuelve la **misma malla** con `topo_map` vacío (**stub** hasta OCP/BRep en Fase 2). Así el **primer camino RPC** “cara → operación” ya es coherente con el protocolo y los tests.
- El siguiente paso en **Gui** es **picking**: raycast contra la malla en Godot, leer `topo_id` del triángulo, y llamar a `geom.extrude_face` (o herramienta modal equivalente).

---

## Ver también

- [jsonrpc-protocol.md](jsonrpc-protocol.md) — transporte, framing, métodos (`geom.extrude_face`).
- [topological-naming.md](topological-naming.md) — identidad topológica desde el backend.
- [iso-19650.md](iso-19650.md) — estados de proyecto y trazabilidad (cuando aplique a fases posteriores).
