# Empaquetado silencioso — Flatpak + Python congelado

**Objetivo:** el usuario final descarga **un único archivo** y abre AxonBIM. No instala Python, no instala dependencias, no toca la terminal.

---

## 1. Estrategia general

```
┌─────────────────────────────────────────┐
│            Flatpak (sandbox)             │
│  ┌─────────────────────────────────────┐ │
│  │    Godot 4.x (binario standalone)    │ │
│  │            ▲                          │ │
│  │            │ JSON-RPC sobre socket    │ │
│  │            ▼                          │ │
│  │  Python 3.12 congelado (PyInstaller) │ │
│  │   + IfcOpenShell, OCP, ezdxf,        │ │
│  │     todas las wheels resueltas       │ │
│  └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

## 2. Decisión: PyInstaller vs Conda-pack

| Criterio | PyInstaller | Conda-pack |
|----------|-------------|------------|
| Tamaño final | Menor (~80–150 MB) | Mayor (~500 MB+) |
| Portabilidad | Excelente | Buena |
| Manejo de C-extensions complejas (OCP, IfcOpenShell) | Requiere hooks custom | Funciona out-of-the-box |
| Velocidad de arranque | Rápida tras "warm-up" | Idéntica a Python normal |
| Curva de aprendizaje | Media | Baja |

**Decisión inicial:** **PyInstaller** con hooks custom para OCP. Si los hooks resultan inviables, fallback a Conda-pack.

## 3. Build pipeline (esbozo)

### 3.1 Backend congelado

```bash
# En CI (GitHub Actions, runner Linux x86_64)
uv sync --frozen
uv run pyinstaller \
  --onedir \
  --name axonbim-backend \
  --collect-all ifcopenshell \
  --collect-all OCP \
  --collect-all ezdxf \
  --hidden-import sqlite3 \
  src/axonbim/__main__.py
```

Output: `dist/axonbim-backend/` con ejecutable + libs vendoradas.

### 3.2 Godot exportado

```bash
godot --headless --path frontend --export-release "Linux/X11" build/axonbim-frontend
```

### 3.3 Manifiesto Flatpak

`packaging/flatpak/io.axonbim.AxonBIM.yaml`:

```yaml
app-id: io.axonbim.AxonBIM
runtime: org.freedesktop.Platform
runtime-version: '23.08'
sdk: org.freedesktop.Sdk
command: axonbim-launcher
finish-args:
  - --share=ipc
  - --socket=fallback-x11
  - --socket=wayland
  - --device=dri
  - --filesystem=home          # acceso a proyectos del usuario
modules:
  - name: axonbim
    buildsystem: simple
    build-commands:
      - install -Dm755 axonbim-launcher /app/bin/axonbim-launcher
      - cp -r axonbim-backend  /app/lib/axonbim/
      - cp -r axonbim-frontend /app/lib/axonbim/
      - install -Dm644 io.axonbim.AxonBIM.desktop /app/share/applications/io.axonbim.AxonBIM.desktop
      - install -Dm644 icons/axonbim-256.png /app/share/icons/hicolor/256x256/apps/io.axonbim.AxonBIM.png
    sources:
      - type: dir
        path: ../../build
```

### 3.4 Launcher

`packaging/flatpak/axonbim-launcher` (script bash mínimo):

```bash
#!/usr/bin/env bash
set -euo pipefail
LIB=/app/lib/axonbim

# Arranca backend en background
"$LIB/axonbim-backend/axonbim-backend" &
BACKEND_PID=$!
trap "kill $BACKEND_PID 2>/dev/null || true" EXIT

# Espera a que el socket exista (max 5s)
for _ in {1..50}; do
  [ -S "${XDG_RUNTIME_DIR}/axonbim.sock" ] && break
  sleep 0.1
done

# Lanza Godot (proceso principal del Flatpak)
exec "$LIB/axonbim-frontend/axonbim-frontend" "$@"
```

## 4. AppImage (alternativa portable)

Para usuarios que no quieran Flatpak: empaquetar el mismo árbol con `appimagetool`. Mismo launcher, distinto wrapper.

## 5. CI

Workflow `.github/workflows/release.yml` se dispara en tags `v*`:

1. Build backend con PyInstaller.
2. Export Godot release.
3. `flatpak-builder` para Flatpak.
4. `appimagetool` para AppImage.
5. Sube ambos artefactos al GitHub Release.

## 6. Validación

Cada build de release ejecuta un **smoke test** automático:

```bash
xvfb-run -a flatpak run --command=axonbim-launcher io.axonbim.AxonBIM --self-test
```

El flag `--self-test` arranca el backend, abre un IFC de prueba, ejecuta una booleana, exporta un DXF mínimo y cierra. Si el código de salida no es 0, el release se aborta.

## 7. Pendientes para Fase 4

- [ ] Resolver hooks de PyInstaller para OCP (probable necesidad de `--collect-binaries`).
- [ ] Decidir si firmar el Flatpak (requiere clave GPG del autor).
- [ ] Publicar en Flathub (proceso de revisión ~2-4 semanas).
- [ ] Generar reproducible builds (idealmente).
