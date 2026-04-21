# AxonBIM

> Software BIM open-source para Linux que combina la fluidez gráfica de SketchUp con el rigor paramétrico de Revit.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Status](https://img.shields.io/badge/status-alpha-orange)]()
[![CI](https://github.com/hector/AxonBIM/actions/workflows/ci.yml/badge.svg)](https://github.com/hector/AxonBIM/actions/workflows/ci.yml)
[![Python](https://img.shields.io/badge/python-3.12%2B-blue)](pyproject.toml)
[![Godot](https://img.shields.io/badge/godot-4.3%2B-478cbf)](frontend/project.godot)

**Autor:** Arq. Hector Nathanael Figuereo
**Licencia:** GNU GPL v3
**Plataforma objetivo:** Linux (Flatpak / AppImage)

---

## Visión

La industria BIM en Linux está dominada por herramientas pesadas, propietarias o académicas. AxonBIM nace para ofrecer:

- **Fluidez gráfica de nivel SketchUp** — push/pull, manipulación directa, viewport responsivo.
- **Rigor paramétrico de nivel Revit** — geometría sólida B-Rep, IFC nativo, normativa estricta.
- **Cumplimiento normativo dominicano (MIVED)** — exportación de planos lista para entrega oficial.
- **Cero fricción de instalación** — un único Flatpak con todo el entorno Python congelado dentro.

## Filosofía: Director de Orquesta

AxonBIM **no reinventa**. Integra tecnologías maduras y las orquesta:

| Pieza | Rol |
|-------|-----|
| **Godot Engine 4.x** | Motor gráfico (Vulkan) — UI, viewport, interacción |
| **Python 3.12+** | Cerebro — geometría, IFC, normativa, persistencia |
| **OCP / OpenCASCADE** | Geometría sólida y NURBS |
| **IfcOpenShell** | Lectura/escritura IFC, generación 2D |
| **ezdxf** | Exportación DXF bajo simbología MIVED |
| **SQLite** | Persistencia local, ISO 19650, undo/redo |

La separación es estricta: **Godot muestra, Python decide**. Hablan por JSON-RPC sobre socket Unix.

## Arquitectura en una línea

```
┌────────────┐   JSON-RPC 2.0    ┌─────────────┐
│   Godot    │◄─────socket──────►│   Python    │
│ (frontend) │      Unix          │  (backend)  │
└────────────┘                    └─────────────┘
   GPU 100%                       CPU + persistencia
```

Detalle completo en [`.cursor/rules/00-architecture.mdc`](.cursor/rules/00-architecture.mdc) y [`docs/architecture/`](docs/architecture/).

## Estado

Proyecto en **Fase 1** (puente de comunicación). Ver [ROADMAP.md](ROADMAP.md).

## Cómo empezar (desarrollo)

### Prerrequisitos

- **Python 3.12+**
- **[uv](https://docs.astral.sh/uv/)** como gestor de entorno (`curl -LsSf https://astral.sh/uv/install.sh | sh`)
- **Godot 4.3+** desde [godotengine.org](https://godotengine.org)
- **Git LFS** (`git lfs install` tras clonar, necesario para PDFs normativos)
- Opcional: **[gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit)** para linting GDScript (`pipx install gdtoolkit`)

### Setup inicial

```bash
git clone https://github.com/<usuario>/AxonBIM.git
cd AxonBIM
git lfs pull
make install          # uv sync
```

### Comandos de desarrollo (via Makefile)

```bash
make format           # ruff format + gdformat
make lint             # ruff check + gdlint
make typecheck        # mypy --strict src/
make test             # pytest -q
make test-cov         # pytest con cobertura (falla < 80%)
make run-backend      # python -m axonbim (servidor RPC)
make run-godot        # abre el proyecto Godot
```

Ver `make help` para la lista completa.

### Ejecutar la demo end-to-end desde fuente (Sprint 1.4)

La demo levanta el backend Python en TCP loopback, abre Godot apuntando a ese
puerto y permite crear un muro IFC desde la UI.

```bash
# 1. Terminal A: lanzar el backend escuchando en TCP (puerto default 5799)
uv run python -m axonbim --tcp --log-level INFO
# Equivalente explicito:
#   uv run python -m axonbim --tcp-port 5799 --tcp-host 127.0.0.1 --log-level INFO

# 2. Terminal B: abrir Godot (el cliente ya intenta 127.0.0.1:5799 por defecto)
godot --path frontend
# Si usas otro puerto en el backend, fuerza la variable:
#   AXONBIM_RPC_PORT=9000 godot --path frontend
#
# Flatpak (la variable del shell NO siempre entra al sandbox; usa --env):
#   flatpak run --env=AXONBIM_RPC_PORT=5799 org.godotengine.Godot --path "$PWD/frontend"
```

Flujo en la UI:

1. Pulsa **Ping backend** — el campo *RTT* debe mostrar milisegundos.
2. Pulsa **Crear muro** y haz dos clics sobre el grid — Godot envía
   `ifc.create_wall` al backend y dibuja la malla del muro.
3. Pulsa **Guardar IFC...** y elige un archivo — el backend serializa un
   `.ifc` ISO 10303-21 válido que puedes abrir en BIMcollab Zoom, Solibri,
   FreeCAD, Blender (BlenderBIM), etc.

Si el backend cae, el `RpcClient` reintenta la conexión con backoff
exponencial (500 ms → 10 s). Las notificaciones `system.warning` /
`system.info` emitidas por el backend aparecen en el log.

#### Godot Flatpak + NVIDIA (RTX): cierre inesperado o Vulkan

Si al cerrar Godot sigue apareciendo el informe de **cierre inesperado** con GPU
NVIDIA (p. ej. RTX 4070 Mobile), suele ser el stack **Vulkan + driver** dentro
del sandbox de Flatpak, no un bug de AxonBIM. Prueba, en este orden:

1. Arrancar con variable de entorno (a veces reduce crashes al salir):
   `flatpak run --env=__GL_THREADED_OPTIMIZATIONS=0 org.godotengine.Godot --path frontend`
2. En `frontend/project.godot`, sección `[rendering]`, cambiar temporalmente a
   OpenGL: `renderer/rendering_method="gl_compatibility"` (más estable en
   algunas laptops híbridas; peor rendimiento PBR que Forward+).

#### "Crear muro" no hace nada

Comprueba que el backend esté en marcha (`uv run python -m axonbim --tcp`) y que
el log de Godot muestre `RpcClient conectado`. Con Flatpak, si no pasas
`--env=AXONBIM_RPC_PORT=...`, el cliente usa el puerto **5799**
por defecto igualmente; si cambias el puerto del backend, usa `--env` como
arriba. Los clics del muro se leen **dentro del SubViewport 3D** (no del panel
lateral); debes hacer clic sobre el área del viewport, no sobre el botón.

### Estructura del repositorio

```
AxonBIM/
├── src/axonbim/          # backend Python (RPC, IFC, geometria, normativa)
├── frontend/             # proyecto Godot 4 (UI, viewport 3D)
├── tests/                # pytest (unit + integration + fixtures)
├── docs/                 # arquitectura, normativa, protocolo RPC
├── .cursor/rules/        # reglas del agente IA
└── ROADMAP.md            # hoja de ruta de desarrollo
```

## Contribuir

Lee [CONTRIBUTING.md](CONTRIBUTING.md). Resumen:

- Ramas: `feature/<scope>-…`, `fix/<scope>-…` desde `develop`.
- Commits convencionales en español: `feat(geom): añade fillet en aristas`.
- PRs requieren CI verde (lint + type check + tests).

## Licencia

GNU General Public License v3.0 — ver [LICENSE](LICENSE).

Todo archivo fuente bajo `src/` y `frontend/scripts/` lleva la cabecera:

```
© 2026 Arq. Hector Nathanael Figuereo. GPLv3.
```
