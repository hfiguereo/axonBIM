# Changelog — AxonBIM

Todas las notas relevantes del proyecto se documentan en este archivo.

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y
versionado según [Semantic Versioning](https://semver.org/lang/es/).

## [Unreleased]

### Añadido

- Parámetro RPC opcional ``join_end_guid`` en ``ifc.create_wall``: ajuste de **cierre de habitación** (extiende ``p2`` cuando vuelve al primer muro del contorno, ortogonal). Herramienta Godot **Crear muro**: snap al primer vértice (~0,45 m) y envío de ``join_end_guid``.
- Convención interna de **capas DXF** arquitectónicas (``DXF_ARCH_LAYER_SPECS``, prefijo ``AXON_*`` reservado); el export de muros **registra** todas las capas canónicas aunque solo escriba geometría en ``WALLS``; test de lectura DXF en ``test_handlers_draw.py``.
- Historial SQLite por **ámbito** (`__unsaved__` hasta el primer `project.save`, luego ruta canónica del `.ifc`); migración automática columna `scope` en `session_history.db`.
- Operaciones en **deshacer/rehacer**: `create_wall`, `delete_wall`, `set_wall_typology` además de `geom.extrude_face`; restauración de muro borrado con el mismo `GlobalId` (`restore_wall`).
- Módulo `axonbim.history.recording` (`suppressed`) para no re-apilar al aplicar historial.
- Doc [`docs/architecture/draw-delivery-layers.md`](docs/architecture/draw-delivery-layers.md) (evolución Fase 3 capas).
- Doc [`docs/architecture/geometry-analytical-vs-ocp.md`](docs/architecture/geometry-analytical-vs-ocp.md) para contribuyentes.
- Tests unitarios `tests/unit/test_history_extended.py`; tests de persistencia/estrés de historial (entradas previas de esta sección).

### Documentación

- Manual y [`jsonrpc-protocol.md`](docs/architecture/jsonrpc-protocol.md): `join_end_guid`, cierre de habitación en **Crear muro**; export DXF y capas `AXON_*`.
- Manual: §2.1 **runbook** de fallos RPC / historial por archivo; tabla `project.save` y notas de `history.*` en [`jsonrpc-protocol.md`](docs/architecture/jsonrpc-protocol.md); [`CONTRIBUTING.md`](CONTRIBUTING.md) (plataforma e integración RPC).
- Cierre documental **Fase 2** e inventario Fases 3–4: [`docs/phase-reports/phase-2-report.md`](docs/phase-reports/phase-2-report.md), [`docs/phase-reports/fases-3-y-4-inventario-pendientes.md`](docs/phase-reports/fases-3-y-4-inventario-pendientes.md); índice [`docs/phase-reports/README.md`](docs/phase-reports/README.md); desglose ROADMAP [`docs/roadmap/README.md`](docs/roadmap/README.md), plantilla [`docs/roadmap/00-guia-estructura-subhitos.md`](docs/roadmap/00-guia-estructura-subhitos.md). [`ROADMAP.md`](ROADMAP.md) alineado (SQLite, criterio 50+ muros).

### Cambiado

- `project.save` actualiza el ámbito del historial a la ruta del IFC guardado.

## [0.1.0-alpha.2] — 2026-05-07

Segunda alpha técnica: **vistas 2D** (`draw.ortho_snapshot` analítico u OCP, canvas OCC), **export DXF de muros**, **UI** (tema raíz, subventanas nativas, EventBus piloto, ViewportManager), **worker Godot headless** opcional (ADR-0003, puerto auxiliar) y **ROADMAP** actualizado frente al tronco real.

### Arreglado

- Godot: carga estable de `ViewportManager` en `main_scene.gd` usando **preload** del script (evita fallo de parseo cuando `class_name` aún no está en alcance).
- Godot: **vista flotante** — `apply_view_state` del rig en **ventana auxiliar** se difiere hasta que el `Window` está en el árbol (evita error `!is_inside_tree()` / `get_global_transform`).
- Godot: el **viewport** queda **recortado** al panel central (`clip_contents` en el contenedor y la capa overlay); el `SubViewport` deja de usar **`UPDATE_ALWAYS`** por defecto (menos carga GPU) y en pestañas **2D OCC** el render 3D se **pausa** (`UPDATE_DISABLED`) mientras la vista 2D cubre el área.
- Godot: tras **crear un muro** en vista 2D, el refresco OCC va **difuso (~120 ms)** para reducir parpadeos o saltos de layout.
- Backend: **`draw.ortho_snapshot`** con **ningún muro** en sesión devuelve `lines_px` vacío y `world_bounds_uv` del **espacio de trabajo** (ya se puede alinear el trazo 2D sin crear antes un muro en 3D).

### Añadido

- ADR-0003 y contrato JSON-RPC del **worker Godot** headless (puerto auxiliar default `5800`, métodos `worker.ping` y `worker.aabb_intersects`); módulo `WorkerManager` y apagado automático con el servidor RPC; activación opcional con `AXONBIM_SPAWN_GODOT_WORKER=1` (también `AXONBIM_GODOT_BIN`, `AXONBIM_WORKER_PORT`).
- Godot: autoload **EventBus** que reexpone notificaciones RPC como señales tipadas (pilotos en la escena principal).
- Godot: tema base **axon_theme.tres** aplicado al contenedor raíz del layout.
- Godot: **subventanas nativas** del sistema (`embed_subwindows=false` en ajustes de ventana).
- Backend: RPC **`draw.export_dxf_walls`** (ezdxf) exporta la proyección **analítica** de muros a DXF (planta `top` por defecto; capa `WALLS`).
- Backend / contrato: **`draw.ortho_snapshot`** acepta **`projection_engine`** (`analytical` por defecto u `ocp`) para elegir proyección de aristas desde caja analítica o malla OCP.
- Godot: botón **Exportar muros DXF (planta)…** en Proyecto llama a `draw.export_dxf_walls` (ruta `.dxf` elegida por el usuario).
- Godot: botón **Modo 2D** (`Auto`, `Plano vectorial`, `Modelo ortográfico`) para enrutar vistas 2D: en `Auto`, snapshot analítico con fallback automático a ortográfico si falla o viene vacío.
- Godot / backend: borrar **`IfcWall`** con RPC `ifc.delete`, botón **Eliminar muro** en Propiedades y **Supr**
  con foco sobre el viewport (respeta foco en cuadros de texto). El árbol del proyecto y el visor 3D
  se mantienen alineados.
- Godot: postprocesado del visor tipo taller: **tonemap ACES**, **MSAA 4×**, rejilla amplia en suelo y panel gizmo de vistas; **fondo plano** sin domo de cielo (evita líneas de horizonte artefacto).
- Backend: nuevo endpoint RPC **`draw.ortho_snapshot`** (OCC) para vistas ortogonales `top/front/right`, con payload de líneas 2D rasterizables y metadatos de escala/encuadre por vista.
- Frontend: canvas 2D OCC con estados de vista **`loading` / `ready` / `error` / `fallback`** y fallback automático a preset ortográfico legacy si el backend OCC falla.
- Frontend (OCC 2D): navegación directa en canvas (`rueda=zoom`, `MMB=pan`) y bloqueo de navegación de cámara 3D durante trazado de muros en vistas 2D.
- Frontend/Backend: `draw.ortho_snapshot` acepta `view_range` (`cut_plane_m`, `top_m`, `bottom_m`, `depth_m`) y la planta OCC lo usa para filtrar geometría visible.
- CLI: nuevo flag `--tcp` como atajo que habilita TCP en el puerto default
  `5799`. Equivalente a `--tcp-port 5799`. Ahora `uv run python -m axonbim --tcp`
  funciona; antes argparse rechazaba `--tcp` por ambigüedad con
  `--tcp-host`/`--tcp-port`.

### Cambiado

- Documentación / contrato de producto: **nivel base fijo 00** hasta niveles y desfases; **trazar muro en vista 2D OCC** alineado a **huella X/Y** en ese datum (la cámara 3D no define el dibujo). Constante compartida ``BASE_STOREY_ELEVATION_M`` en ``main_scene.gd`` / ``create_wall_tool.gd``; manual de usuario actualizado.
- Godot: menos microcortes CPU en la rejilla de suelo: solo reaplica translucido cuando cambia **el tipo de vista** (bucket de planitud), no en cada ``_process``.
- Godot: HUD **WorkspaceHud** en el visor con **medias del espacio IFC en planta** (desde ``workspace_xy_half_m`` en ``ifc.create_wall``) y pista grosera de **escala visual** orto/perspectiva desde el rig.
- Backend/Sesión: ``WorkspaceXYHalfExtents`` vivo en ``IfcSession``; cada muro válido **amplía** proporcionalmente (×1,12) las medias X/Y cuando el segmento las supera (`workspace_xy.py`, ``ifc.create_wall``).
- Godot: botón **Generar vistas 2D...** en Proyecto exporta capturas ortográficas **top/front/right** a PNG en una carpeta elegida por el usuario (manteniendo el preset de cámara previo al finalizar).
- Godot: **Generar vistas 2D...** usa OCC por defecto (si está habilitado) y guarda `vista_top/front/right.png`; mantiene opción legacy temporal como degradación automática.
- Godot: al crear muros en `Planta 2D` OCC, la vista se refresca en caliente sin necesidad de cambiar de pestaña.
- Godot: sistema base de **pestañas de vistas** en el viewport (`Modelado`, `Planta 2D`, `Frente 2D`, `Derecha 2D`) y **ventana auxiliar por vista** para preparar la conexión OCC por tab sin romper el flujo actual.
- Godot: vistas 2D movidas al **Project Browser** (`Vistas 2D`), con acciones `+ Vista 2D` y `Eliminar vista`; selección en árbol activa la previsualización ortográfica del tab correspondiente (sin OCC aún).
- Godot: **orto y perspectiva** usan **solo color de fondo uniforme** (`BG_CLEAR_COLOR`; perspectiva algo más clara) y ambiente por color; ya no hay **cielo procedural** (`OrbitCameraRig.viewport_projection_mode_changed`, `main_scene.gd`).
- Godot: ``SubViewportContainer`` **sin márgenes interior ni borde** (~10px antes + trazo azul) y **SplitContainer** del área de trabajo con **``dragger_visibility = DRAGGER_HIDDEN``** (sin icono de agarre; sigue pudiendo arrastrarse la franja de separación).
- Godot: **Crear muro** — el **primer** trazo usa P1+P2; los siguientes continúan desde el extremo anterior
  (clave **P2**, un clic habitual). **Alt + clic** fija nuevo P1 sin desactivar la herramienta. Se mantienen
  snap orthogonal, guías, tipología desde **Propiedades**, envolvente y heurísticas posteriores a Push/Pull.

- Backend: RPC ``ifc.get_wall_spec`` y ``ifc.set_wall_typology`` (misma sesión;
  conserva eje P1–P2, regenera IFC y malla).
- Godot: **navegación de viewport** — convención **Z arriba** (plano XY), órbita
  (botón central + arrastre), pan (Mayús + botón central), zoom (rueda y
  pellizco), trackpad (**Alt+LMB**, **Mayús+LMB**, **Ctrl/Meta+LMB** vertical),
  atajos **1–4** e **Inicio/R** con el ratón sobre el visor, teclado numérico
  **7/1/3/0**, y panel **Planta / Frente / Derecha / Persp / Inicio** en la
  esquina del visor (`OrbitCameraRig`, `NavViewportGizmo`).
- Godot: hover de **Push/Pull** resalta la **cara lógica** completa (todos los
  triángulos con el mismo `topo_id`), no solo el triángulo interceptado por el
  rayo (`project_view.gd`).
- Documentación: **Manual de AxonBIM** (`docs/manual-de-axonbim.md`) como guía de usuario de herramientas y flujos; regla de mantenimiento en `.cursor/rules/67-manual-de-axonbim.mdc` y enlace desde el README.
- Backend: `geom.extrude_face` ahora sondea la malla equivalente generada con
  OCP/OpenCASCADE y reporta métricas `debug_ocp_mesh_stats` para validar la
  ruta B-Rep de Fase 2 sin romper la malla analítica existente.
- Tests: snapshots geométricos versionados para muro caja y extrusión superior
  con tolerancia `1e-6`, más regresión RPC de 52 muros editados y guardados.
- Geometría: `topo_id` migra al formato Fase 2 de 16 hex sobre firma canónica
  con tipo de entidad, GUID padre y firma de operación.
- Backend/UI: `history.redo` rehace la última extrusión deshecha y Godot lo
  invoca con `Ctrl+Shift+Z`, manteniendo malla, IFC y topología sincronizadas.
- Godot: entrada numérica de distancia para Push/Pull en el panel Propiedades,
  aplicable tras fijar una cara en modo edición.
- Godot: paquete inicial de iconos SVG propios para acciones de Fase 2
  (Crear muro, Push/Pull, Editar elemento, Guardar IFC, Ping backend, Undo,
  estados de backend y selección), con guía visual y atribuciones bajo
  `frontend/assets/`.
- Godot: tema visual inicial de AxonBIM con paneles más suaves, mejor contraste
  en botones/árbol/estado y un entorno 3D azul oscuro más estilizado.
- Godot: modo edición por elemento para Fase 2. Se entra con doble clic sobre
  un elemento seleccionado o desde el botón `Editar elemento` en Propiedades; `Esc`
  o el mismo botón salen del modo. Push/Pull queda limitado al elemento en edición.
- `scripts/dev/install_godot_official.sh`: descarga Godot **4.3-stable** Linux
  oficial a `~/.local/bin/godot` (misma version que CI). Documentado en README
  junto con **desinstalar Flatpak** (`flatpak uninstall org.godotengine.Godot`)
  cuando Vulkan/SIGABRT molesta.
- `Makefile`: `run-godot` prefije `~/.local/bin/godot` si existe.
- Godot: vistas **Planta / Frente / Derecha** en **proyección ortogonal**; **Persp** y
  órbita (MMB o Alt+LMB) en perspectiva. Cielo procedural del viewport más **claro**,
  sin bloom; cuadrícula en **plano XY** con opacidad según inclinación
  (`OrbitCameraRig`, `workspace_floor_grid.gd`).
- Godot: el renderer por defecto del proyecto pasa de **Forward+** (Vulkan) a
  **GL Compatibility** (OpenGL). En Fedora + Flatpak + GPU NVIDIA (p. ej. RTX
  movil) Vulkan suele terminar en ``SIGABRT`` en el binario ``godot-bin`` (ABRT),
  no en el codigo AxonBIM. Quien necesite Forward+ puede cambiarlo en Ajustes
  del proyecto. Ver ``frontend/project.godot`` comentario en ``config/features``.
- **ROADMAP.md**: tabla de estado del tronco (OCC/2D, DXF, worker, UI) y hitos de Fases 2–4 alineados con lo ya implementado frente a lo pendiente normado (MIVED, SQLite undo, etc.).

### Corregido

- Backend (Windows): ruta por defecto del socket Unix sin ``os.getuid`` y
  servidor RPC **solo TCP** cuando ``asyncio.start_unix_server`` no existe;
  tests de integración Unix se omiten en esa plataforma.
- Godot **4.6+**: el autoload ``Logger`` chocaba con la clase nativa ``Logger``
  del motor (errores de parseo en ``rpc_client.gd``, escena principal y
  ``project_view.gd``). Se retira ``scripts/autoload/logger.gd`` del proyecto;
  el frontend usa solo ``AxonLogger`` (`frontend/scripts/utils/axon_logger.gd`).
- Tests integracion RPC: en macOS los ``tmp_path`` de pytest generan rutas
  Unix demasiado largas (``AF_UNIX path too long``). Los fixtures usan ahora
  sockets bajo ``tempfile.gettempdir()`` via ``tests/unix_socket_path.py``.
- Godot: la herramienta **Crear muro** no recibia clics: con
  ``SubViewport.handle_input_locally = false`` los eventos van al viewport 3D,
  no al ``gui_input`` del ``SubViewportContainer``. Los clics se capturan ahora
  en ``AxonProjectView._unhandled_input`` y se reenvian a la herramienta.
- Godot + Flatpak: ``RpcClient`` usaba puerto ``0`` si Flatpak no heredaba
  ``AXONBIM_RPC_PORT`` del shell (conexion imposible). El puerto TCP por defecto
  del cliente pasa a ser ``5799`` (mismo que ``python -m axonbim --tcp``);
  ``AXONBIM_RPC_PORT=0`` sigue desactivando TCP.
- Godot (Linux): cierre mas limpio del frontend. ``RpcClient`` ahora corta
  el ``StreamPeerTCP`` en ``_exit_tree()`` (desactiva reconexion, ``set_process(false)``,
  ``disconnect_from_host()``) para reducir reportes de "cierre inesperado"
  al salir con Vulkan/TCP aun activo. Tras ``await`` RPC, las escenas ignoran
  el resultado si el arbol ya se destruyo (``is_inside_tree()``).
- Documentación: `docs/phase-reports/phase-1-report.md` referenciaba el flag
  inexistente `--tcp --port 7878`. Sustituido por el atajo nuevo `--tcp` y se
  unifica el puerto a `5799` (alineado con el README).
- Documentación: se restaura `docs/architecture/app-gui-viewport-patterns.md`,
  citada desde `project_view.gd` y ausente en el árbol tras limpieza de ramas.

## [0.1.0-alpha.1] — 2026-04-20

Primera release técnica (Fase 1 del ROADMAP): **el puente de comunicación**
Godot ↔ Python y el flujo mínimo para crear un muro IFC y guardarlo en disco.

### Añadido

- Scaffolding Python (`uv` + `pyproject.toml`) con `ruff`, `mypy --strict`,
  `pytest`, `pytest-cov` (>80% cobertura gating en CI).
- Proyecto Godot 4.x (`frontend/`) Forward+, autoloads `Logger` y `RpcClient`.
- Servidor JSON-RPC 2.0 asyncio escuchando simultáneamente sobre **socket
  Unix** (CLI/tests) y **TCP loopback** (Godot), con framing LSP
  `Content-Length`.
- Dispatcher con registro declarativo de handlers, validación Pydantic v2 de
  `params`/`result`, mapeo de excepciones a códigos de error JSON-RPC.
- Handlers iniciales:
  - `system.ping`, `system.version`, `system.shutdown`
  - `ifc.create_wall` (IfcOpenShell + mesh analítico compatible con
    `ArrayMesh` de Godot)
  - `project.save` (escribe `.ifc` ISO 10303-21 válido)
- Stub de IDs topológicos persistentes (`geometry/topology.py`, SHA-1 sobre
  centroide+área+normal redondeados).
- Sesión IFC thread-safe (`ifc/session.py`) que inicializa un `IfcProject`
  mínimo con unidades del SI.
- Escena Godot `main.tscn` con viewport 3D integrado, toolbar
  (*Ping backend*, *Crear muro*, *Guardar IFC...*), grid Z=0 y cámara
  isométrica.
- Herramienta `create_wall_tool.gd`: captura de dos clics en el viewport +
  llamada RPC + adición del muro al `ProjectView`.
- `MeshBuilder` convierte el payload RPC `{vertices, indices, normals}` a
  `ArrayMesh` nativo.
- Reconexión automática del `RpcClient` con backoff exponencial
  (500 ms → 10 s) y procesamiento de notificaciones `system.warning` /
  `system.info`.
- CI (`.github/workflows/ci.yml`): lint/type/tests Python (matrix 3.12/3.13),
  lint/format GDScript, tests Godot headless condicionales, chequeo Git LFS.
- Validación de títulos de PR bajo Conventional Commits
  (`.github/workflows/pr-checks.yml`) y Dependabot para Actions y `pip`.
- Documentación:
  - `docs/architecture/jsonrpc-protocol.md` (protocolo, transportes, errores).
  - `docs/architecture/iso-19650.md` (estrategia de implementación, sin
    copiar texto del estándar oficial).
  - `README.md` con Quick Start y badges de CI.

### Decidido (ADR implícitos)

- **Persistencia interna:** `sqlite3` (stdlib) para `axon_internal.db`.
- **Modelos RPC:** Pydantic v2 para la frontera RPC (entrada/salida);
  `dataclasses` para estructuras geométricas internas (`Mesh`).
- **Transporte Godot:** TCP loopback, tras confirmar que Godot 4.x no expone
  `StreamPeerUnix`. Unix sockets se conservan para CLI y pruebas.
- **Empaquetado Fase 4:** Conda-pack como primario, PyInstaller como
  alternativa.

### Conocido / diferido

- La geometría del muro se genera como caja analítica (suficiente para
  Fase 1). Operaciones booleanas reales con OpenCASCADE quedan para Fase 2.
- El servidor aún no hace *broadcast* proactivo de notificaciones al cliente
  (el cliente ya sabe recibirlas). Se abordará junto con el sistema de
  eventos de Fase 2.

[Unreleased]: https://github.com/hector-figuereo/AxonBIM/compare/v0.1.0-alpha.2...HEAD
[0.1.0-alpha.2]: https://github.com/hector-figuereo/AxonBIM/compare/v0.1.0-alpha.1...v0.1.0-alpha.2
[0.1.0-alpha.1]: https://github.com/hector-figuereo/AxonBIM/releases/tag/v0.1.0-alpha.1
