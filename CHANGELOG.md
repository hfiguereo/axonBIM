# Changelog — AxonBIM

Todas las notas relevantes del proyecto se documentan en este archivo.

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y
versionado según [Semantic Versioning](https://semver.org/lang/es/).

## [Unreleased]

### Añadido

- Godot: paquete inicial de iconos SVG propios para acciones de Fase 2
  (Crear muro, Push/Pull, Editar elemento, Guardar IFC, Ping backend, Undo,
  estados de backend y selección), con guía visual y atribuciones bajo
  `frontend/assets/`.
- Godot: modo edición por elemento para Fase 2. Se entra con doble clic sobre
  un elemento seleccionado o desde el botón `Editar elemento` en Propiedades; `Esc`
  o el mismo botón salen del modo. Push/Pull queda limitado al elemento en edición.
- `scripts/dev/install_godot_official.sh`: descarga Godot **4.3-stable** Linux
  oficial a `~/.local/bin/godot` (misma version que CI). Documentado en README
  junto con **desinstalar Flatpak** (`flatpak uninstall org.godotengine.Godot`)
  cuando Vulkan/SIGABRT molesta.
- `Makefile`: `run-godot` prefije `~/.local/bin/godot` si existe.

### Cambiado

- Godot: el renderer por defecto del proyecto pasa de **Forward+** (Vulkan) a
  **GL Compatibility** (OpenGL). En Fedora + Flatpak + GPU NVIDIA (p. ej. RTX
  movil) Vulkan suele terminar en ``SIGABRT`` en el binario ``godot-bin`` (ABRT),
  no en el codigo AxonBIM. Quien necesite Forward+ puede cambiarlo en Ajustes
  del proyecto. Ver ``frontend/project.godot`` comentario en ``config/features``.

### Corregido

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

### Añadido

- CLI: nuevo flag `--tcp` como atajo que habilita TCP en el puerto default
  `5799`. Equivalente a `--tcp-port 5799`. Ahora `uv run python -m axonbim --tcp`
  funciona; antes argparse rechazaba `--tcp` por ambigüedad con
  `--tcp-host`/`--tcp-port`.

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
