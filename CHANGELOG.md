# Changelog — AxonBIM

Todas las notas relevantes del proyecto se documentan en este archivo.

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y
versionado según [Semantic Versioning](https://semver.org/lang/es/).

## [Unreleased]

### Añadido

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
- CLI: nuevo flag `--tcp` como atajo que habilita TCP en el puerto default
  `5799`. Equivalente a `--tcp-port 5799`. Ahora `uv run python -m axonbim --tcp`
  funciona; antes argparse rechazaba `--tcp` por ambigüedad con
  `--tcp-host`/`--tcp-port`.
- Backend: handler RPC `geom.extrude_face` (stub Fase 2: validación Pydantic,
  malla placeholder, `topo_map`) registrado en `python -m axonbim`; tests en
  `tests/unit/test_handlers_geom.py`.
- Godot: herramienta base **Push/Pull** (selección/arrastre simulado, llamada
  RPC al soltar), iconos procedurales en toolbar, entidades transitorias en
  `ProjectView` para preview de resultado.
- Godot: camara **orbit** en viewport (boton medio + arrastre, rueda zoom)
  via ``orbit_camera_3d.gd`` en la escena principal.
- Godot: `AxonLogger` (`frontend/scripts/utils/axon_logger.gd`) para logging
  sin colisión con la clase nativa `Logger` en Godot 4.6+.
- Scripts de simulación headless (`frontend/scripts/dev/*.gd`) y registro de
  fallos de simulación en `docs/phase-reports/simulation-failures.md`.
- Cursor: reglas `65-microtareas-roadmap.mdc` y `66-microtask-simulation-checks.mdc`.
- ROADMAP: directrices UI/UX para Fase 2 (toolbar minimalista, tooltips,
  iconos procedurales, paneles flotantes).

### Documentación

- README y ROADMAP: politica **Flatpak al minimo** en Fedora para desarrollo;
  plan **incremental** para volver a probar **Forward+ / Vulkan** sin bloquear
  el nucleo BIM; Compatibility como fallback hasta aislar el entorno grafico.

### Cambiado

- Godot: el renderer por defecto del proyecto pasa de **Forward+** (Vulkan) a
  **GL Compatibility** (OpenGL). En Fedora + Flatpak + GPU NVIDIA (p. ej. RTX
  movil) Vulkan suele terminar en ``SIGABRT`` en el binario ``godot-bin`` (ABRT),
  no en el codigo AxonBIM. Quien necesite Forward+ puede cambiarlo en Ajustes
  del proyecto. Ver ``frontend/project.godot`` comentario en ``config/features``.

### Corregido

- Backend (Windows): ruta por defecto del socket Unix sin ``os.getuid`` y
  servidor RPC **solo TCP** cuando ``asyncio.start_unix_server`` no existe;
  tests de integración Unix se omiten en esa plataforma.
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

[Unreleased]: https://github.com/hector-figuereo/AxonBIM/compare/v0.1.0-alpha.1...HEAD
[0.1.0-alpha.1]: https://github.com/hector-figuereo/AxonBIM/releases/tag/v0.1.0-alpha.1
