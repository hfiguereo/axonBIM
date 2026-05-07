# ADR-0003: Proceso Godot headless auxiliar (Worker) para cómputo escénico

- **Estado:** Accepted
- **Fecha:** 2026-05-07
- **Autores:** AxonBIM (contribuidores)
- **Fase:** Roadmap — UI nativa y aceleración auxiliar

---

## Contexto

AxonBIM separa **frontend Godot** (UI y viewport) y **backend Python** (IfcOpenShell, OCP, persistencia IFC). Algunas tareas futuras (raycasts de prueba, cajas envolventes sobre mallas ya serializadas, prototipos de intersección visual) podrían beneficiarse del motor de escena sin bloquear el hilo de UI.

Riesgo: duplicar la **verdad geométrica** del modelo IFC en dos runtimes. Hace falta un límite explícito y un contrato de red que no confunda al worker con el backend principal.

## Decisión

**Adoptar un proceso Godot 4.x en modo `--headless`** que escucha en **TCP loopback dedicado** (`127.0.0.1`), con el **mismo framing LSP** (`Content-Length`) y JSON-RPC 2.0 que el servidor Python, pero en un **puerto distinto** del RPC principal del backend.

- El **backend Python permanece la única fuente de verdad** para mutaciones IFC y geometría B-Rep documentada.
- El **worker** solo ejecuta métodos **auxiliares** acotados, con parámetros y resultados **serializables** (números, booleanos, arrays de escalar). No sustituye IfcOpenShell ni OCP salvo que un ADR futuro lo autorice explícitamente.
- **Orientación de conexión:** el worker actúa como **servidor** TCP en el puerto auxiliar; **Python u otros clientes** se conectan como **clientes** para invocar `worker.*`. El frontend interactivo **no** sustituye su `RpcClient` principal por el worker; cualquier orquestación pasa por decisiones del backend o queda en pruebas/herramientas hasta que el protocolo principal lo incorpore.

## Alternativas consideradas

### Alternativa A — Worker como cliente del RPC Python (mismo puerto 5799)

- **Descripción:** Godot headless se conecta al mismo servidor que el frontend y registra capacidades vía métodos `worker.register`.
- **Pros:** Un solo listener; simetría con el frontend.
- **Contras:** Mezcla sesiones, autenticación inexistente y multiplexación de “quién es cliente de servicios auxiliares” más frágil; el dispatcher actual no distingue roles.
- **Motivo por el que se descartó:** Mayor complejidad en el servidor principal antes de tener un piloto estable.

### Alternativa B — Sin proceso Godot; todo en Python/OCP

- **Descripción:** No spawnear Godot; usar solo Python para AABB, raycast analítico, etc.
- **Pros:** Un solo runtime; menos procesos.
- **Contras:** No reutiliza escena, jerarquía ni utilidades del viewport Godot cuando el producto las necesite.
- **Motivo por el que se descartó:** Se mantiene como opción para muchas operaciones; el worker cubre el hueco “escena Godot sin UI” de forma acotada.

## Consecuencias

### Positivas

- Límite claro entre **RPC principal** (Python, IFC) y **RPC auxiliar** (Godot headless).
- El contrato (`docs/architecture/jsonrpc-protocol.md`) puede evolucionar por dominio `worker.*` sin colisionar con `ifc.*` / `geom.*`.

### Negativas / trade-offs aceptados

- Un puerto y proceso más que vigilar; CI puede omitir pruebas que requieran binario `godot`.
- Riesgo de **doble modelo** si alguien usa el worker con datos no derivados del backend; mitigación: revisión de PR y ADR.

### Neutras

- Variables de entorno documentadas: `AXONBIM_WORKER_PORT`, `AXONBIM_GODOT_BIN`, `AXONBIM_SPAWN_GODOT_WORKER`.

## Plan de implementación (opcional)

- [x] Documentar transporte, puerto default y métodos piloto en el protocolo JSON-RPC.
- [x] Escena/script headless mínimo en el proyecto Godot.
- [x] `WorkerManager` en Python (subproceso, SIGTERM al apagar el servidor RPC).
- [x] Pruebas de humo con mock o `pytest.mark.skip` sin binario.

## Referencias

- [`docs/architecture/jsonrpc-protocol.md`](../jsonrpc-protocol.md) — sección puerto auxiliar y `worker.*`.
- ADRs relacionados: ADR-0001 (multi-viewport), ADR-0002 (2D/ortográfica).
- Código: `src/axonbim/worker_manager.py`, `frontend/scripts/worker/worker_host.gd`, `frontend/scenes/worker/worker_host.tscn`.
