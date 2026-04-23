# Contribuir a AxonBIM

¡Gracias por tu interés! Este documento describe el flujo de trabajo para contribuir código, documentación o reportar issues.

## Antes de empezar

1. Lee [README.md](README.md) para entender la visión.
2. Revisa [ROADMAP.md](ROADMAP.md) para saber en qué fase estamos.
3. Familiarízate con la arquitectura núcleo en [`.cursor/rules/00-architecture.mdc`](.cursor/rules/00-architecture.mdc).

## Setup del entorno

### Backend (Python)

```bash
# Instalar uv si no lo tienes
curl -LsSf https://astral.sh/uv/install.sh | sh

# Clonar y sincronizar
git clone https://github.com/<usuario>/AxonBIM.git
cd AxonBIM
uv sync

# Verificar
uv run pytest -q
uv run ruff check .
uv run mypy --strict src/
```

### Frontend (Godot)

1. Descarga **Godot 4.3+** (Standard, no .NET) desde [godotengine.org](https://godotengine.org/download).
2. Abre `frontend/project.godot`.
3. Para tests headless en CI, instala el addon **GUT** (Godot Unit Test).

### Herramientas auxiliares

```bash
# Lint/format de GDScript
pipx install gdtoolkit
gdformat frontend/scripts
gdlint frontend/scripts

# Pre-commit hooks (recomendado)
uv run pre-commit install
```

## Flujo de trabajo

### Ramas

| Rama | Propósito | Origen |
|------|-----------|--------|
| `main` | Releases firmados | merge desde `develop` |
| `develop` | Integración continua | base de todas las features |
| `feature/<scope>-<descripcion>` | Nueva funcionalidad | desde `develop` |
| `fix/<scope>-<descripcion>` | Bugfix | desde `develop` |
| `refactor/<scope>-...`, `docs/<scope>-...`, `chore/<scope>-...` | Otros | desde `develop` |

`<scope>` es el dominio: `rpc`, `geom`, `ifc`, `draw`, `ui`, `iso19650`, `mived`, `ci`, `pkg`.

### Varias máquinas / mismo autor

Trata `origin/develop` como fuente de verdad: `git pull` al empezar en un clone y, antes de cambiar de PC, commits pequeños verificados y `git push`. Convención detallada (incluida para agentes) en [`.cursor/rules/66-git-sincronizacion-solo-autor.mdc`](.cursor/rules/66-git-sincronizacion-solo-autor.mdc).

### Commits

Formato convencional, en **español imperativo**, ≤72 caracteres en la primera línea:

```
feat(geom): añade fillet en aristas vía OCP
fix(rpc): evita deadlock cuando el cliente cierra durante una llamada
refactor(ifc): extrae lectura de propiedades a módulo separado
docs(mived): completa tabla de grosores de línea para muros
```

Tipos: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `build`, `ci`.

### Pull Requests

Estructura del cuerpo:

```markdown
## Qué
Resumen de los cambios en 2-3 líneas.

## Por qué
Motivación. Issue que resuelve, decisión arquitectónica, etc.

## Cómo probarlo
1. Pasos manuales si aplica.
2. Comandos para reproducir.
```

**Requisitos para mergear:**

- [ ] CI verde (lint + type check + tests + Godot headless).
- [ ] Tests añadidos o actualizados según [`.cursor/rules/40-testing.mdc`](.cursor/rules/40-testing.mdc).
- [ ] Documentación actualizada si cambia API pública o protocolo RPC.
- [ ] Aprobación del BDFL (Arq. Hector Figuereo) para cambios arquitectónicos.

## Código

- Sigue las reglas en `.cursor/rules/`. No las repetimos aquí.
- Cabecera GPLv3 en archivos fuente bajo `src/` y `frontend/scripts/`:
  ```
  © 2026 Arq. Hector Nathanael Figuereo. GPLv3.
  ```
- No introduzcas dependencias nuevas sin justificación en el PR.

## Reportar bugs

Abre un issue con:

1. Versión de AxonBIM, Godot y Python.
2. Distribución Linux y versión.
3. Pasos para reproducir.
4. Comportamiento esperado vs observado.
5. Logs (`~/.local/share/axonbim/logs/`).

## Código de conducta

Sé respetuoso, técnicamente honesto y crítico de las ideas, no de las personas. Las discusiones técnicas se resuelven con datos, benchmarks o referencias normativas — no con autoridad.
