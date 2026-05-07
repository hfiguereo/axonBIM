# AGENTS.md — AxonBIM

Punto de entrada estándar para agentes de IA (Cursor, Codex, Claude Code, otros).

## Cómo trabajar en este repo

1. **Lee primero las reglas activas** en `.cursor/rules/`. Están organizadas por dominio:
   - `00-architecture.mdc` — núcleo de la arquitectura (siempre cargado).
   - `10-anti-patterns.mdc` — comportamiento esperado del agente (siempre cargado).
   - `11-validacion-previa-reglas.mdc` — meta-regla: validar reglas aplicables antes de cualquier cambio material.
   - `12-protocolo-cambios-riesgo.mdc` — alcance, confirmación y sin cambios destructivos por iniciativa propia.
   - `13-diagnostico-evidencia-runtime.mdc` — incidentes: evidencia antes de “arreglar”; sin inventar causa.
   - `14-seguridad-repositorio-y-despliegue.mdc` — secretos, logs, TLS razonable, firma de artefactos.
   - `20-backend-python.mdc` — al editar Python.
   - `21-frontend-godot.mdc` — al editar GDScript / escenas.
   - `22-jsonrpc-bridge.mdc` — al tocar el puente RPC.
   - `30-bim-normativa.mdc` — al trabajar en planos / estados de proyecto.
   - `40-testing.mdc` — al escribir o modificar tests.
   - `50-git-commits.mdc` — al proponer commits o PRs.
   - `66-git-sincronizacion-solo-autor.mdc` — mismo autor / varias PCs; evitar divergencias; ramas remotas múltiples (Cloud Agent, PRs).
   - `67-manual-de-axonbim.mdc` — mantener `docs/manual-de-axonbim.md` alineado con la UI y flujos de usuario.

2. **Documentación de referencia** (no son reglas, son specs):
   - `docs/architecture/jsonrpc-protocol.md` — esquema completo del puente.
   - `docs/architecture/geometry-analytical-vs-ocp.md` — cuándo el tronco usa geometría analítica vs OCP.
   - `docs/roadmap/README.md` — desglose por fases (sub-hitos: qué / cómo / por qué); complementa `ROADMAP.md`.
   - `docs/architecture/topological-naming.md` — generación de hashes B-Rep.
   - `docs/architecture/iso-19650.md` — estados y trazabilidad.
   - `docs/normativa/README.md` — índice maestro de normativas (MIVED, MOPC, otros).
   - `docs/normativa/mived/ccrd-vol-i.md` — extracto operativo del Código de Construcción RD.
   - `docs/normativa/glosario-organismos.md` — siglas (MIVED, MOPC, CONARTED, CODIA, etc.).
   - `docs/packaging/flatpak-pyinstaller.md` — distribución silenciosa.
   - `docs/manual-de-axonbim.md` — manual de usuario (herramientas, flujos; debe mantenerse con cambios visibles).

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

# Worker Godot headless (opcional, ADR-0003): mismo JSON-RPC en puerto auxiliar (default 5800).
# AXONBIM_SPAWN_GODOT_WORKER=1 AXONBIM_GODOT_BIN=/ruta/godot4 uv run python -m axonbim --tcp

# App (Godot + backend RPC en un solo comando)
./start                          # uv sync + backend TCP + Godot (un comando)

# Frontend — tests GUT headless (requiere godot 4.x)
godot --headless --path frontend -s addons/gut/gut_cmdln.gd -gtest=res://tests/
```

## Cuando dudes

- Sobre arquitectura → `.cursor/rules/00-architecture.mdc`.
- Sobre cómo se comporta el agente → `.cursor/rules/10-anti-patterns.mdc`.
- Sobre qué reglas aplican antes de tocar archivos → `.cursor/rules/11-validacion-previa-reglas.mdc`.
- Sobre cambios delicados o ambiguos → `.cursor/rules/12-protocolo-cambios-riesgo.mdc`.
- Sobre fallos en ejecución sin contexto → `.cursor/rules/13-diagnostico-evidencia-runtime.mdc`.
- Sobre secretos, logs o release → `.cursor/rules/14-seguridad-repositorio-y-despliegue.mdc`.
- Sobre normativa → pregunta antes de inventar.
- Sobre el roadmap → `ROADMAP.md`, no es información de codificación.
- Sobre el manual de usuario → `docs/manual-de-axonbim.md` y `.cursor/rules/67-manual-de-axonbim.mdc`.

## Cursor Cloud specific instructions

### Entorno

- **Python 3.12+** ya disponible en la VM. `uv` se instala con `curl -LsSf https://astral.sh/uv/install.sh | sh` si no está en PATH; el update script lo maneja.
- **Godot Engine** no está disponible en la VM Cloud (headless, sin GPU). El frontend Godot no se puede ejecutar ni probar aquí. Solo el backend Python es testeable end-to-end.
- El backend RPC no requiere servicios externos (ni Docker, ni PostgreSQL, ni Redis). Usa SQLite embebido.

### Backend: arranque y verificación

```bash
# Instalar deps y correr tests
uv sync --all-extras
uv run pytest -q

# Lint + typecheck
uv run ruff check .
uv run ruff format --check .
uv run mypy --strict src/

# Iniciar backend RPC (TCP 127.0.0.1:5799)
uv run python -u -m axonbim --tcp
```

Para verificar que el backend responde, enviar un ping JSON-RPC por TCP al puerto 5799 con framing `Content-Length` (protocolo LSP). Los puntos (`p1`, `p2`) para `ifc.create_wall` deben pasarse como diccionarios `{"x": ..., "y": ..., "z": ...}`, no como arrays.

### Gotchas

- `ruff format --check` puede reportar archivos que necesitan reformateo; esto no bloquea `ruff check` (lint) ni `mypy`.
- El test `test_worker_manager` se salta por defecto (requiere `AXONBIM_RUN_GODOT_WORKER_TEST=1` + binario Godot).
- La rama `temporal` tiene commits WIP divergentes de `develop` con conflictos de merge en 7 archivos del frontend; fusionar requiere resolución manual.
