# AGENTS.md — AxonBIM

Punto de entrada estándar para agentes de IA (Cursor, Codex, Claude Code, otros).

## Cómo trabajar en este repo

1. **Lee primero las reglas activas** en `.cursor/rules/`. Están organizadas por dominio:
   - `00-architecture.mdc` — núcleo de la arquitectura (siempre cargado).
   - `10-anti-patterns.mdc` — comportamiento esperado del agente (siempre cargado).
   - `20-backend-python.mdc` — al editar Python.
   - `21-frontend-godot.mdc` — al editar GDScript / escenas.
   - `22-jsonrpc-bridge.mdc` — al tocar el puente RPC.
   - `30-bim-normativa.mdc` — al trabajar en planos / estados de proyecto.
   - `40-testing.mdc` — al escribir o modificar tests.
   - `50-git-commits.mdc` — al proponer commits o PRs.
   - `66-git-sincronizacion-solo-autor.mdc` — mismo autor / varias PCs; evitar divergencias.

2. **Documentación de referencia** (no son reglas, son specs):
   - `docs/architecture/jsonrpc-protocol.md` — esquema completo del puente.
   - `docs/architecture/topological-naming.md` — generación de hashes B-Rep.
   - `docs/architecture/iso-19650.md` — estados y trazabilidad.
   - `docs/normativa/README.md` — índice maestro de normativas (MIVED, MOPC, otros).
   - `docs/normativa/mived/ccrd-vol-i.md` — extracto operativo del Código de Construcción RD.
   - `docs/normativa/glosario-organismos.md` — siglas (MIVED, MOPC, CONARTED, CODIA, etc.).
   - `docs/packaging/flatpak-pyinstaller.md` — distribución silenciosa.

3. **Visión y planificación** (lectura humana, no para generar código):
   - `README.md` — qué es AxonBIM y por qué existe.
   - `ROADMAP.md` — fases, hitos, estado.
   - `CONTRIBUTING.md` — flujo de trabajo, ramas, PRs.

## Comandos canónicos

```bash
# Backend
uv sync                          # instalar dependencias
uv run pytest -q                 # tests
uv run ruff check . && uv run mypy --strict src/

# App (Godot + backend RPC en un solo comando)
make run                         # scripts/dev/run_dev.sh

# Frontend — tests GUT headless (requiere godot 4.x)
godot --headless --path frontend -s addons/gut/gut_cmdln.gd -gtest=res://tests/
```

## Cuando dudes

- Sobre arquitectura → `.cursor/rules/00-architecture.mdc`.
- Sobre cómo se comporta el agente → `.cursor/rules/10-anti-patterns.mdc`.
- Sobre normativa → pregunta antes de inventar.
- Sobre el roadmap → `ROADMAP.md`, no es información de codificación.
