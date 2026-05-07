# Protocolo JSON-RPC — AxonBIM

Spec viva del puente entre Godot (frontend) y Python (backend).

> **Versión del protocolo:** `0.1.0` (alpha)
> **Última revisión:** 2026-05
> **Estado:** propuesta inicial — sujeto a cambios mientras estemos en Fase 1.

---

## 1. Transporte

El backend puede escuchar **simultáneamente** en dos transportes y los clientes eligen el que les convenga:

| Transporte | Cliente típico | Ventaja |
|------------|----------------|---------|
| **Unix socket** (`AF_UNIX`, stream) | Tests Python, CLI, clientes nativos | Permisos de FS, cero overhead TCP, sin puertos |
| **TCP loopback** (`127.0.0.1:<puerto>`) | Godot 4.x (cliente oficial del frontend) | Godot expone `StreamPeerTCP` pero no `StreamPeerUnix` |

- **Unix path:** `${XDG_RUNTIME_DIR}/axonbim.sock` (fallback: `${TMPDIR}/axonbim-${UID}.sock`).
- **TCP:** el backend usa `--tcp` (puerto default `5799`) o `--tcp-port=<N>`. El
  cliente Godot (`RpcClient`) intenta `127.0.0.1:5799` si no hay env
  `AXONBIM_RPC_PORT` (Flatpak a menudo no hereda variables del shell; el default
  evita quedar en puerto `0`). Se puede forzar con `AXONBIM_RPC_PORT` o con
  `--rpc-port=<puerto>` en los argumentos de usuario de Godot. `AXONBIM_RPC_PORT=0`
  desactiva TCP en el cliente.
- **Lifecycle:** Python crea el/los listeners al arrancar; los clientes conectan una sola vez y mantienen la conexión abierta durante toda la sesión.
- **Encoding:** UTF-8 en el body, ASCII en los headers.

### Decisión de diseño (Sprint 1.3)

El spike confirmó que Godot 4.3 no expone `AF_UNIX` a través de la API `StreamPeer`. En lugar de desarrollar un `StreamPeerExtension` en C (complejidad alta, mantenimiento continuo), se adopta **TCP loopback** como transporte del frontend. El Unix socket se mantiene como transporte primario para tests y herramientas, asegurando que el protocolo es transporte-agnóstico.

## 2. Framing

Estilo LSP — header + cuerpo:

```
Content-Length: <bytes>\r\n
\r\n
<json body>
```

`Content-Type: application/vscode-jsonrpc; charset=utf-8` opcional, ignorado si presente.

## 3. Mensajes — JSON-RPC 2.0

### 3.1 Request

```json
{
  "jsonrpc": "2.0",
  "id": 42,
  "method": "geom.extrude_face",
  "params": {
    "topo_id": "a1b2c3d4...",
    "vector": [0.0, 0.0, 0.5]
  }
}
```

- `id`: entero monotónico generado por el cliente. Único por sesión.
- `method`: `<dominio>.<acción>` en `snake_case`.
- `params`: objeto (siempre objeto, nunca array, para permitir extensión por nombre).

### 3.2 Response — éxito

```json
{
  "jsonrpc": "2.0",
  "id": 42,
  "result": {
    "mesh": {
      "vertices": [0.0, 0.0, 0.0, 1.0, 0.0, 0.0, ...],
      "indices": [0, 1, 2, 0, 2, 3, ...],
      "normals": [...]
    },
    "topo_map": {
      "a1b2c3d4...": "f5e6d7c8..."
    }
  }
}
```

`topo_map` mapea IDs viejos a nuevos cuando una operación cambia la topología.

### 3.3 Response — error

```json
{
  "jsonrpc": "2.0",
  "id": 42,
  "error": {
    "code": -32001,
    "message": "Boolean operation failed",
    "data": {
      "reason": "non-manifold-result",
      "operation": "extrude_face",
      "topo_id": "a1b2c3d4..."
    }
  }
}
```

### 3.4 Notification (sin `id`)

Solo del backend al frontend. Eventos asíncronos:

```json
{ "jsonrpc": "2.0", "method": "project.autosave_done", "params": { "timestamp": 1745000000 } }
```

## 4. Códigos de error

### 4.1 Estándar JSON-RPC

| Código | Significado |
|--------|-------------|
| `-32700` | Parse error |
| `-32600` | Invalid request |
| `-32601` | Method not found |
| `-32602` | Invalid params |
| `-32603` | Internal error |

### 4.2 Específicos AxonBIM (`-32000` a `-32099`)

| Código | Constante | Significado |
|--------|-----------|-------------|
| `-32000` | `IFC_PARSE_ERROR` | Archivo IFC corrupto o no parseable |
| `-32001` | `BOOLEAN_FAILED` | Operación booleana inválida (no-manifold, geometría degenerada) |
| `-32002` | `TOPO_ID_NOT_FOUND` | El `topo_id` referenciado no existe en el modelo actual |
| `-32003` | `STATE_TRANSITION_INVALID` | Transición ISO 19650 no permitida (ej. de Published a WIP directo) |
| `-32004` | `MIVED_SPEC_MISSING` | Se requiere un valor MIVED no definido en la spec |
| `-32005` | `OPERATION_TIMEOUT` | Operación excedió el timeout configurado |
| `-32006` | `BUSY` | Backend ocupado en otra operación bloqueante |
| `-32007` | `LOIN_INCOMPLETE` | Faltan propiedades obligatorias del perfil LOIN para la transición solicitada |
| `-32008` | `CONTAINER_IMMUTABLE` | Se intentó modificar un contenedor en estado no-WIP (Shared/Published/Archive/Rejected) |

## 5. Dominios y métodos

### 5.1 `system.*`

| Método | Params | Result |
|--------|--------|--------|
| `system.ping` | `{}` | `{ "pong": true, "ts": <int> }` |
| `system.version` | `{}` | `{ "protocol": "0.1.0", "backend": "0.1.0" }` |
| `system.shutdown` | `{}` | `{ "ok": true }` (cierra el backend tras responder) |

### 5.2 `ifc.*`

| Método | Params | Result |
|--------|--------|--------|
| `ifc.open` | `{ "path": "<file>" }` | `{ "project_guid": "...", "stats": {...} }` |
| `ifc.create_wall` | `{ "p1": [x,y,z], "p2": [x,y,z], "height": <m>, "thickness": <m>, "join_with_guid": "<opcional>", "join_end_guid": "<opcional>" }` | `{ "guid": "...", "mesh": {...}, "workspace_xy_half_m": [halfX_m, halfY_m] }` (medias en planta desde origen; crecen con margen **~12%** cuando el trazo las excede). Si `join_with_guid` refiere el muro previo y el ángulo es ~90°, el backend retrocede `p1` medio espesor para cerrar la esquina en cadena. Si `join_end_guid` refiere el **primer** muro del contorno y `p2` coincide con su `p1` en planta con esquina ~90°, el backend **extiende** `p2` medio espesor sobre el eje del tramo (cierre de habitación, simétrico al ajuste de cadena). |
| `ifc.get_wall_spec` | `{ "guid": "<GlobalId>" }` | `{ "wall_spec": { "p1": {...}, "p2": {...}, "height": <m>, "thickness": <m> } }` |
| `ifc.set_wall_typology` | `{ "guid": "<GlobalId>", "height": <m>, "thickness": <m>, "typology_id": "<opcional>" }` | `{ "guid": "...", "mesh": {...} }` |
| `ifc.delete` | `{ "guid": "..." }` | `{ "ok": true }` |
| `ifc.get_properties` | `{ "guid": "..." }` | `{ "properties": {...} }` |

*(lista no exhaustiva — se completa en Fase 1)*

### 5.3 `geom.*`

| Método | Params | Result |
|--------|--------|--------|
| `geom.extrude_face` | `{ "topo_id": "...", "vector": [x,y,z] }` | `{ "guid": "...", "mesh": {...}, "topo_map": {...}, "debug_ocp_mesh_stats": {"vertices": 36, "triangles": 12, "faces": 6} }` |
| `geom.boolean` | `{ "op": "union\|difference\|intersection", "a_guid": "...", "b_guid": "..." }` | `{ "mesh": {...}, "result_guid": "..." }` |
| `geom.fillet_edge` | `{ "topo_id": "...", "radius": <m> }` | `{ "mesh": {...}, "topo_map": {...} }` |

### 5.4 `draw.*`

| Método | Params | Result |
|--------|--------|--------|
| `draw.ortho_snapshot` | `{ "view": "top\|front\|right", "width_px": 1280, "height_px": 800, "margin_px": 24, "view_id": "<opcional>", "requested_scale_m_per_px": <opcional>, "view_range": { ... }, "projection_engine": "analytical\|ocp" (opcional, por defecto `analytical`) }` | Igual que antes; el resultado incluye `projection_engine` cuando hay muros (proyección de aristas desde caja analítica o malla OCP según el motor). Sin muros: comportamiento anterior. |
| `draw.export_dxf_walls` | `{ "out_path": ".../walls.dxf", "view": "top\|front\|right" (opcional, por defecto `top`), "view_range": { ... } (opcional) }` | `{ "path": "...", "segment_count": <int>, "view": "..." }` — DXF R2010 mínimo, capa `WALLS`, proyección **analítica** (metros en plano de la vista). |
| `draw.export_plan` | `{ "level": "<storey_guid>", "format": "dxf\|pdf", "out_path": "...", "norma": "MIVED" }` | `{ "ok": true, "path": "..." }` |
| `draw.export_section` | `{ "plane": {...}, "format": "...", "out_path": "..." }` | `{ "ok": true, "path": "..." }` |

Nota de producto actual (frontend): en vistas 2D el modo por defecto es `auto` (intenta
snapshot vectorial analítico y cae a ortográfico de modelo si hay error o resultado vacío).
El método RPC sigue siendo único; el ruteo de modo ocurre en Godot.

### 5.5 `project.*` / `history.*`

| Método | Params | Result |
|--------|--------|--------|
| `project.save` | `{ "path": "..." }` | `{ "path": "...", "bytes": <int> }` |
| `history.undo` | `{}` | `{ "applied": true, "guid": "...", "mesh": {...} \| null, "topo_map": {...} }` o `{ "applied": false, "reason": "empty" \| "unsupported:..." }` |
| `history.redo` | `{}` | Igual criterio que `history.undo`. |
| `project.set_state` | `{ "state": "WIP\|Shared\|Published", "comment": "..." }` | `{ "ok": true, "snapshot_path": "..." }` |

**Historial persistente (SQLite):** tipos de operación reversibles en el tronco: `extrude_face`, `set_wall_typology`, `delete_wall`, `create_wall` (la pila de redo usa además `recreate_wall` y `redo_delete_wall` de forma interna). **Ámbito:** hasta el primer `project.save` en la sesión del proceso, la pila usa el ámbito `__unsaved__`; tras guardar, el ámbito pasa a la **ruta absoluta canónica** del `.ifc` guardado, de modo que pilas de distintos archivos no se mezclan. Variable de entorno `AXONBIM_HISTORY_DB` fija el fichero SQLite (desarrollo/tests).

### 5.6 Notificaciones del backend

| Método | Params |
|--------|--------|
| `project.autosave_done` | `{ "timestamp": <int>, "path": "..." }` |
| `project.state_changed` | `{ "state": "...", "by": "..." }` |
| `system.warning` | `{ "message": "...", "level": "info\|warn" }` |

### 5.7 Puerto auxiliar — proceso Godot Worker (headless)

> **ADR:** [`0003-godot-worker-headless-auxiliar.md`](decisions/0003-godot-worker-headless-auxiliar.md)

El **backend Python** (`python -m axonbim`, puerto TCP default `5799`) sigue siendo el **único** canal JSON-RPC para el frontend de producto (`RpcClient`) y la verdad IFC.

Además puede existir un **segundo listener** en el mismo host: un proceso **Godot 4.x `--headless`** que expone JSON-RPC con **idéntico framing** (§2) pero en **otro puerto**, para tareas **auxiliares** (no mutan el IFC; no sustituyen IfcOpenShell/OCP salvo ADR futuro).

| Concepto | Valor / notas |
|----------|----------------|
| Host | `127.0.0.1` (loopback) |
| Puerto default | `5800` (no colisiona con `5799`) |
| Variable de entorno | `AXONBIM_WORKER_PORT` — si está vacía, se usa el default `5800` en el worker; Python puede fijarla al spawnear el subproceso. |
| Quién escucha | **Godot worker** (servidor TCP). |
| Quién conecta | **Python** (`WorkerManager`, tests) u otras herramientas; el frontend Godot con UI **no** reemplaza su conexión principal por este puerto en la fase piloto. |

#### Métodos `worker.*` (piloto)

| Método | Params | Result |
|--------|--------|--------|
| `worker.ping` | `{}` | `{ "pong": true, "engine": "<string>" }` |
| `worker.aabb_intersects` | `{ "a_min": [x,y,z], "a_max": [x,y,z], "b_min": [x,y,z], "b_max": [x,y,z] }` (metros, mundo alineado a ejes) | `{ "intersects": <bool> }` |

Errores: mismos códigos JSON-RPC estándar; parámetros mal formados → `-32602` (`Invalid params`).

## 6. Timeouts

| Categoría | Timeout cliente |
|-----------|-----------------|
| Operaciones triviales (`system.*`, `ifc.get_*`) | 5s |
| Mutaciones simples (`ifc.create_wall`, `ifc.set_wall_typology`, `geom.extrude_face`) | 10s |
| Booleanas, parsing IFC grande, exportación 2D | 60s |
| Operaciones bulk explícitas | configurable por llamada con campo `_timeout_ms` en `params` |

## 7. Compatibilidad

- Cambios **aditivos** (nuevo método, nuevo campo opcional) → bump minor (`0.1.0` → `0.2.0`).
- Cambios **incompatibles** (eliminar método, cambiar tipo de campo) → bump major y nota en `CHANGELOG.md`.
- Cliente verifica `system.version` al conectar y rechaza si la major no coincide.
