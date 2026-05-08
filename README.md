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
- **Rigor paramétrico de nivel Revit** — semántica **IFC** en sesión, malla **analítica** alineada con el viewport (misma geometría que alimenta vistas 2D); normativa estricta en la senda documental. Sólidos B-Rep booleanos completos entran solo cuando un **ADR** lo autorice.
- **Cumplimiento normativo dominicano (MIVED)** — exportación de planos lista para entrega oficial.
- **Cero fricción de instalación** — un único Flatpak con todo el entorno Python congelado dentro.
- **Principios de modelado** — equilibrio gesto / IFC / historial; [texto operativo en `ROADMAP.md`](ROADMAP.md#principios-de-modelado).

## Filosofía: Director de Orquesta

AxonBIM **no reinventa**. Integra tecnologías maduras y las orquesta:

| Pieza | Rol |
|-------|-----|
| **Godot Engine 4.x** | Motor gráfico (GL Compatibility por defecto; Forward+/Vulkan opcional en ajustes) — UI, viewport |
| **Python 3.12+** | Cerebro — geometría **analítica**, IFC, normativa, persistencia |
| **IfcOpenShell** | Lectura/escritura IFC y soporte al modelo semántico |
| **ezdxf** | Exportación DXF bajo simbología MIVED |
| **SQLite** | Persistencia local, ISO 19650, undo/redo |

La separación es estricta: **Godot muestra, Python decide**. Hablan por **JSON-RPC** (TCP loopback **127.0.0.1** para Godot en desarrollo típico; socket Unix para tests y CLI — ver [`docs/architecture/jsonrpc-protocol.md`](docs/architecture/jsonrpc-protocol.md)).

## Arquitectura en una línea

```
┌────────────┐   JSON-RPC 2.0    ┌─────────────┐
│   Godot    │◄──TCP loopback────►│   Python    │
│ (frontend) │   (+ Unix tests)   │  (backend)  │
└────────────┘                    └─────────────┘
   GPU 100%                       CPU + persistencia
```

Detalle completo en [`.cursor/rules/00-architecture.mdc`](.cursor/rules/00-architecture.mdc) y [`docs/architecture/`](docs/architecture/).

## Estado

**Alpha técnica** (p. ej. `v0.1.0-alpha.2`): puente RPC estable, modelado interactivo de **muros + Push/Pull**, niveles IFC, huecos y losas demo, vistas 2D vectoriales y export DXF — ver [`CHANGELOG.md`](CHANGELOG.md). En [`ROADMAP.md`](ROADMAP.md), las **Fases 1 y 2** están cerradas en sus hitos principales; el trabajo visible siguiente es **Fase 3** (planimetría MIVED / motor 2D normado) y **Fase 4** (distribución / ISO 19650 completo).

## Manual de usuario

Guía de herramientas y flujos en la aplicación: [**Manual de AxonBIM**](docs/manual-de-axonbim.md).

## Cómo empezar (desarrollo)

### Prerrequisitos

- **Python 3.12+**
- **[uv](https://docs.astral.sh/uv/)** como gestor de entorno (`curl -LsSf https://astral.sh/uv/install.sh | sh`)
- **Godot 4.3+** — **recomendado: binario oficial** (mismo que CI); ver [Godot sin Flatpak](#godot-sin-flatpak-recomendado) más abajo.
- **Git LFS** (`git lfs install` tras clonar, necesario para PDFs normativos)
- Opcional: **[gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit)** para linting GDScript (`pipx install gdtoolkit`)

### Godot sin Flatpak (recomendado)

En Fedora, **Flatpak** (`org.godotengine.Godot`) a veces provoca **SIGABRT** con GPU
NVIDIA (Vulkan/sandbox), no por el proyecto AxonBIM. Lo más estable para desarrollo
es el **binario oficial** Linux x86_64 (el mismo que usa GitHub Actions), instalado
en tu usuario:

```bash
# 1) (Opcional) Quitar Godot Flatpak
flatpak uninstall -y org.godotengine.Godot

# 2) Instalar Godot 4.3 estable en ~/.local/bin/godot
chmod +x scripts/dev/install_godot_official.sh
./scripts/dev/install_godot_official.sh

# 3) Asegurar que tu shell use primero ~/.local/bin (Fedora suele hacerlo ya)
export PATH="$HOME/.local/bin:$PATH"
hash -r
godot --version
```

A partir de ahí, `make run-godot` detecta `~/.local/bin/godot` automáticamente. Si
también tienes `/usr/bin/godot` (paquete `dnf`), el de `~/.local/bin` tiene
prioridad si PATH está bien ordenado.

**Alternativas:** [AppImage](https://godotengine.org/download/linux/) en la misma
página de descargas, o extraer el `.zip` a mano desde
[releases](https://github.com/godotengine/godot/releases) (misma URL que el script).

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
./start               # dependencias + backend + Godot (un solo comando; recomendado)
make start            # equivalente al anterior
make run-backend      # solo Python RPC (sin ventana Godot; TCP 5799)
make run-godot        # solo Godot (levantar antes make run-backend en otra terminal)
```

Ver `make help` para la lista completa.

### Ejecutar la demo end-to-end desde fuente (Sprint 1.4)

**Recomendado — un solo comando** (instala/actualiza dependencias con `uv sync`, levanta el backend en TCP y abre Godot; al cerrar Godot se detiene el backend):

```bash
cd AxonBIM
./start
```

Equivalente: `make start` (o `make run`, mismo objetivo).

Siguen existiendo dos procesos en el SO (Python + Godot), pero **un único punto de entrada** para el desarrollador.

**Alternativa — dos terminales** (depuración manual). `make run-backend` **no abre la aplicación gráfica**: solo deja escuchando el servidor RPC hasta que pulses Ctrl+C.

```bash
# 1. Terminal A: backend en TCP (puerto default 5799)
make run-backend
# Equivalente: uv run python -m axonbim --tcp --log-level INFO

# 2. Terminal B: Godot
make run-godot
# Equivalente: AXONBIM_RPC_PORT=5799 godot --path frontend
```

Si usas otro puerto: `AXONBIM_RPC_PORT=9000` en ambos lados o `AXONBIM_RPC_PORT=9000 make run` con el script ajustado vía variable.

En Linux/Fedora, `./start` aplica un perfil de ejecución y valida versión de
Godot al arrancar:

- versión mínima por defecto: `4.6.2`
- si falta o está por debajo, auto-instala/actualiza el binario oficial en
  `~/.local/bin/godot`
- puedes ajustar con:
  - `AXONBIM_GODOT_REQUIRED_VERSION` (ej. `4.6.2`)
  - `AXONBIM_GODOT_AUTO_UPDATE=0` para desactivar auto-actualización
  - `AXONBIM_FORCE_X11=1` para forzar X11 (útil en algunos casos Wayland)

**Flatpak** (la variable del shell no siempre entra al sandbox; usa `--env`):

```bash
flatpak run --env=AXONBIM_RPC_PORT=5799 org.godotengine.Godot --path "$PWD/frontend"
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

#### Godot Flatpak + NVIDIA (RTX): cierre inesperado (ABRT / SIGABRT)

El proyecto ya usa **GL Compatibility** (OpenGL) por defecto en
`frontend/project.godot` para evitar el camino **Vulkan (Forward+)** que en
muchas laptops NVIDIA + Flatpak termina en ``godot-bin killed by SIGABRT`` (no
es un fallo de nuestro GDScript).

Si **aun asi** crashea o ABRT sigue generando volcados:

1. Arranca con:
   `flatpak run --env=__GL_THREADED_OPTIMIZATIONS=0 org.godotengine.Godot --path frontend`
2. Actualiza drivers NVIDIA y `flatpak update`.
3. Prueba el **binario oficial** de [godotengine.org](https://godotengine.org/download/linux/)
   (mismo `--path frontend`) para ver si el problema es solo el sandbox Flatpak.
4. Solo si necesitas Forward+/Vulkan: *Project → Project Settings → Rendering →
   Method → Forward+*, sabiendo que puede volver a inestabilidad en tu GPU.

Decisión y matriz detallada: [**ADR-0005**](docs/architecture/decisions/0005-renderizado-godot-gl-default-y-perfiles-gpu.md).

#### Matriz resumida (entorno × API × GPU)

| Entorno típico | API en `project.godot` | Perfil `AXONBIM_GPU_PROFILE` | Notas |
|----------------|------------------------|------------------------------|--------|
| Fedora, binario oficial, laptop híbrida | **GL Compatibility** (default) | `auto` (default) | Sin tocar PRIME; Mesa suele elegir iGPU para la ventana. |
| Mismo, forzar dGPU (NVIDIA lista) | GL default u opt-in Forward+ | `dedicated` | Exporta `DRI_PRIME=1` vía `linux_profile.sh`; requiere drivers propietarios operativos. |
| Flatpak Godot + NVIDIA | GL default | `auto` | Preferir pruebas con binario oficial si hay SIGABRT; Forward+ más riesgoso en sandbox. |
| Mensajes GLX / sondas NVIDIA molestas | GL default | `integrated` | No fuerza PRIME; prueba manual `__GLX_VENDOR_LIBRARY_NAME=mesa ./start` si usas GLX (ver abajo). |

**Contrato aplicación (no solo driver):** el `SubViewport` principal puede pausar el render 3D cuando una **vista 2D vectorial** cubre el lienzo (`ViewportManager`); el visor usa MSAA configurable en la escena principal. Enlaces en el ADR-0005.

#### Variables: `AXONBIM_GPU_PROFILE` (Linux, vía `./start` / `run_dev.sh`)

- **`auto`** (default): no se exportan variables de selección de GPU; se respeta `DRI_PRIME` u otras que **tú** hayas definido en el shell.
- **`integrated`**: no exporta PRIME; pensado para “dejar al SO” o combinar con variables manuales del README.
- **`dedicated`**: exporta **`DRI_PRIME=1`** para solicitar la GPU discreta en portátiles híbridos (PRIME offload).

Ejemplo: `AXONBIM_GPU_PROFILE=dedicated ./start`

- Archivo opcional **`.env.axonbim`** en la raíz del repo (mismo nivel que `frontend/`): `./start` lo carga antes de `linux_profile.sh`. Plantilla: [`scripts/dev/env.axonbim.example`](scripts/dev/env.axonbim.example). La pestaña **Preferencias** de la cinta en Godot también puede escribir este archivo.

#### Consola: `failed to load driver: nvidia-drm`, `glx: failed to create dri3 screen`, `pci id … driver (null)`

En **portátiles híbridos** (Intel integrada + NVIDIA), el binario de Godot a veces
**sondea la NVIDIA** antes de quedarse con **Mesa en Intel**; por eso ves avisos
aunque al final diga algo como *Using Device: Intel … Mesa*. **No indica que
AxonBIM esté roto** si la ventana abre y el viewport responde.

- **Ya no** se exporta `DRI_PRIME=0` por defecto (valor inválido en Mesa y aviso *Invalid value (0) for DRI_PRIME*). Usa `AXONBIM_GPU_PROFILE` o define tú `DRI_PRIME` si tu distro lo documenta así.
- Si quieres forzar **solo el stack Mesa** en GLX (otro caso de mensajes
  persistentes): prueba una vez
  `__GLX_VENDOR_LIBRARY_NAME=mesa ./start` (no lo fijamos por defecto porque
  en algunos equipos querrás la NVIDIA con `DRI_PRIME=1` o `AXONBIM_GPU_PROFILE=dedicated`).
- Para usar la **NVIDIA** de verdad con drivers propietarios, instálalos y
  configura PRIME/offload según la guía de Fedora/RPM Fusion; hasta entonces es
  normal que la dGPU no cargue como DRI3 principal.

#### Verificación rápida (render + GPU + RPC)

1. Arranca `./start` (o `godot --path frontend` con backend en marcha).
2. En consola de Godot debe aparecer traza **OpenGL** / **GL Compatibility** (no se exige Vulkan).
3. Pulsa **Ping backend**: el RTT debe mostrar milisegundos.
4. Orbita el viewport 3D (MMB / atajos de vista) sin errores continuos.
5. Cierra la ventana: no debe terminar en SIGABRT habitual (si Flatpak+NVIDIA falla, prueba binario oficial; ver sección anterior).

Humo opcional (CI local, requiere `godot` en PATH): `bash scripts/dev/smoke_godot.sh`.

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
- Commits convencionales en español: `feat(draw): añade margen configurable en snapshot`.
- PRs requieren CI verde (lint + type check + tests).

## Licencia

GNU General Public License v3.0 — ver [LICENSE](LICENSE).

Todo archivo fuente bajo `src/` y `frontend/scripts/` lleva la cabecera:

```
© 2026 Arq. Hector Nathanael Figuereo. GPLv3.
```
