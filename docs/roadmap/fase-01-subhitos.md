# Fase 1 — Sub-hitos complementarios (puente de comunicación)

**Referencia:** [`ROADMAP.md`](../../ROADMAP.md) §Fase 1 · **Criterio de salida:** muro IFC desde UI, malla visible, `.ifc` válido en disco (`v0.1.0-alpha.1`).

## Sub-hitos ya cubiertos (ROADMAP [x])

Lo siguiente describe **qué hay en el tronco** con el mismo esquema (qué / cómo / por qué), no trabajo futuro.

---

### SH-F1-01 — Entorno dual reproducible (Python + Godot)

- **Estado:** Cerrado
- **Qué:** Cualquier colaborador puede instalar backend con `uv` y abrir el proyecto Godot 4.x con versiones acotadas en documentación.
- **Cómo:** `pyproject.toml`, `README.md` / `AGENTS.md`, proyecto en `frontend/project.godot`.
- **Por qué:** Sin esto, el puente no es debuggable ni enseñable; es el suelo de CI y de soporte.
- **Hecho cuando:** Quick Start del README verificado en Linux; dependencias declaradas.
- **Evidencia / enlaces:** `README.md`, `AGENTS.md`.

---

### SH-F1-02 — CI: calidad mínima en cada push

- **Estado:** Cerrado
- **Qué:** Lint, tipos y tests Python; Godot headless donde aplique.
- **Cómo:** GitHub Actions (`.github/`).
- **Por qué:** El RPC y el framing son frágiles ante regresiones; CI es red de seguridad barata.
- **Hecho cuando:** Workflow verde en el tronco principal.
- **Evidencia / enlaces:** `.github/workflows/`.

---

### SH-F1-03 — Servidor JSON-RPC (Unix + TCP)

- **Estado:** Cerrado
- **Qué:** Proceso Python escucha mensajes LSP-style; Godot usa TCP loopback; herramientas pueden usar Unix socket.
- **Cómo:** `src/axonbim/rpc/server.py`, framing, `Dispatcher`.
- **Por qué:** Separación de procesos y stack (regla de arquitectura núcleo); TCP por limitación de Godot con Unix nativo.
- **Hecho cuando:** `system.ping` responde por ambos transportes en desarrollo Linux.
- **Evidencia / enlaces:** `docs/architecture/jsonrpc-protocol.md`, tests RPC.

---

### SH-F1-04 — Cliente `RpcClient` en Godot

- **Estado:** Cerrado
- **Qué:** Autoload que reconecta, timeouts y errores legibles en UI.
- **Cómo:** Script autoload + integración en escena principal.
- **Por qué:** Resiliencia entre procesos; la UI debe sobrevivir a caídas del backend.
- **Hecho cuando:** Demo “Ping backend” estable tras reiniciar Python.
- **Evidencia / enlaces:** `frontend/scripts/` (RpcClient), manual si aplica.

---

### SH-F1-05 — Demo end-to-end `ifc.create_wall`

- **Estado:** Cerrado
- **Qué:** Botón o flujo en Godot → RPC → malla en viewport → `project.save` a `.ifc`.
- **Cómo:** Handlers `ifc.*`, `project.save`, malla en Godot.
- **Por qué:** Prueba que el **contrato** y el **IFC** son la espina dorsal real, no un mock.
- **Hecho cuando:** Pasos reproducibles documentados; archivo abrible en visor IFC externo.
- **Evidencia / enlaces:** `docs/phase-reports/phase-1-report.md`.

---

### SH-F1-06 — Protocolo RPC documentado como spec

- **Estado:** Cerrado
- **Qué:** Tabla de métodos, errores y ejemplos JSON alineados al código.
- **Cómo:** `docs/architecture/jsonrpc-protocol.md` mantenido en PRs que tocan RPC.
- **Por qué:** Evita que Godot y Python “inventen” el contrato por separado (punto ciego clásico).
- **Hecho cuando:** Revisión cruzada código ↔ doc sin divergencias conocidas.
- **Evidencia / enlaces:** `jsonrpc-protocol.md`.

---

### SH-F1-07 — Worker Godot headless (extensión opcional)

- **Estado:** Cerrado
- **Qué:** Proceso auxiliar en puerto dedicado; métodos `worker.*` piloto; apagado coordinado desde Python.
- **Cómo:** ADR-0003, `WorkerManager`, escena worker en Godot.
- **Por qué:** Desacoplar tareas auxiliares sin mezclar IfcOpenShell en el motor; no sustituye la autoridad del backend principal.
- **Hecho cuando:** Documentación §5.7 + activación por variable de entorno documentada.
- **Evidencia / enlaces:** `docs/architecture/decisions/0003-godot-worker-headless-auxiliar.md`.

---

## Mejoras aplicadas después del cierre formal (también cerradas)

### SH-F1-08 — Runbook de incidentes RPC para usuarios beta

- **Estado:** Cerrado
- **Qué:** Una página corta (manual o docs): puerto ocupado, firewall loopback, Flatpak y variables `AXONBIM_*`.
- **Cómo:** `docs/manual-de-axonbim.md` o anexo técnico.
- **Por qué:** El puente ya funciona en desarrollo; el punto ciego está en **soporte** y entornos no estándar.
- **Hecho cuando:** Checklist reproducible para 3 fallos frecuentes.
- **Evidencia / enlaces:** [`docs/manual-de-axonbim.md`](../manual-de-axonbim.md) §2.1.

---

### SH-F1-09 — CI multi-plataforma o documentación explícita de exclusión

- **Estado:** Cerrado
- **Qué:** Comportamiento de tests Unix socket en macOS/Windows documentado o cubierto en CI.
- **Cómo:** Matriz de jobs o `skipif` documentados en `CONTRIBUTING.md`.
- **Por qué:** Evita falsos “rojos” locales que desmotivan sin reflejar calidad del tronco Linux.
- **Hecho cuando:** Contribuyente sabe antes de clonar qué plataforma es soportada para RPC integration.
- **Evidencia / enlaces:** [`CONTRIBUTING.md`](../../CONTRIBUTING.md) §Verificación local y plataforma.
