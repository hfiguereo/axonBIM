# Fase 1 — El puente de comunicación

**Release:** `v0.1.0-alpha.1` · **Fecha de cierre:** 2026-04-20 · **Duración efectiva:** ~3 meses (dedicación estimada de 10 h/semana)

> Este reporte es un cuaderno de bitácora para el autor y una introducción para arquitectos y profesionales del sector que quieran entender cómo está construido AxonBIM por dentro, sin ser programadores. Toda decisión y toda carpeta está explicada con el contexto que necesitarías para modificarlas con confianza.

---

## 1. Resumen ejecutivo

> En la Fase 1 construimos el "puente de comunicación" entre la interfaz gráfica (Godot) y el cerebro técnico (Python + IfcOpenShell), y lo probamos con un caso real: crear un muro IFC desde un botón y guardarlo en disco.

- **Se terminó:** dos aplicaciones (frontend Godot, backend Python) que hablan entre sí por un protocolo propio, estable y testeado. Crear un muro con dos clics funciona de punta a punta.
- **Infraestructura:** integración continua (CI) verde, cobertura de tests >80%, reglas de agente IA, normativa BIM de referencia, soporte para archivos pesados vía Git LFS.
- **No se terminó (y era esperado):** operaciones booleanas reales, modelado interactivo, persistencia interna SQLite, planos 2D. Eso es la Fase 2 y posteriores.

---

## 2. Qué puedes hacer hoy con AxonBIM

Siguiendo estos pasos reproduces los avances de la Fase 1 en tu máquina Linux. Los comandos se escriben en la terminal (esa ventana negra con texto; en GNOME se abre con <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>T</kbd>).

### 2.1. Poner en pie el entorno

```bash
cd ~/AxonBIM
uv sync --extra dev         # instala el backend Python + herramientas de desarrollo
```

`uv sync` lee `pyproject.toml` (la "lista de materiales" del backend) y deja todo listo en una carpeta `.venv/` dentro del proyecto. Analogía: es como el **pedido de compra de obra**. Llega todo lo que necesitas para empezar.

### 2.2. Arrancar el backend

En una terminal:

```bash
uv run python -m axonbim --tcp
```

El backend queda escuchando en el puerto TCP `5799` de tu propia máquina (no sale a internet, es el puerto default; lo cambias con `--tcp-port 9000`). Imprime algo como `JSON-RPC escuchando en 127.0.0.1:5799`. Es el **cerebro** de AxonBIM: sabe de IFC, geometría y normativa.

### 2.3. Abrir el frontend Godot

En otra terminal:

```bash
godot --path frontend
```

El `RpcClient` intenta por defecto `127.0.0.1:5799` (no hace falta exportar
`AXONBIM_RPC_PORT` en la mayoría de casos). Con **Flatpak**, si cambias el
puerto del backend o el sandbox no hereda variables del shell, usa:
`flatpak run --env=AXONBIM_RPC_PORT=5799 org.godotengine.Godot --path frontend`.

Se abre Godot. Si el editor te pregunta, importa el proyecto y luego pulsa **F5** para correr la escena principal. Verás la ventana de AxonBIM con un panel a la izquierda y un viewport 3D a la derecha (con una cuadrícula a ras de suelo).

### 2.4. La demo end-to-end

1. **Pulsar "Ping backend"** — arriba a la izquierda aparece `RTT: XX ms`. Confirmaste que los dos programas se hablan (RTT = tiempo de ida y vuelta de un mensaje).
2. **Pulsar "Crear muro"** — el botón cambia a "Click 1 de 2". Haces un clic en la cuadrícula para fijar el arranque, otro para fijar el final. Aparece un muro en el viewport.
3. **Pulsar "Guardar IFC..."** — se escribe un archivo `.ifc` en `/tmp/axonbim/`. Puedes abrirlo con BlenderBIM, Usd View, o Notepad — es texto ISO 10303-21, interoperable con cualquier herramienta BIM.

Si algún paso falla, la franja inferior izquierda muestra el error en lenguaje humano y el terminal del backend imprime el detalle técnico.

---

## 3. Por dentro: cómo está organizado el código

El proyecto tiene esta estructura principal:

```text
AxonBIM/
├── src/axonbim/          ← backend Python (el cerebro)
├── frontend/             ← proyecto Godot (la interfaz)
├── tests/                ← pruebas automatizadas Python
├── docs/                 ← documentación (protocolo, normativa, este reporte)
├── .cursor/rules/        ← reglas del agente IA que edita el código
├── .github/              ← CI/CD (automatización al empujar código)
├── pyproject.toml        ← "lista de materiales" Python
├── CHANGELOG.md          ← historial de cambios formal
├── ROADMAP.md            ← visión de las 5 fases
└── README.md             ← portada del proyecto
```

A continuación, cada carpeta principal con su propósito.

### 3.1. `src/axonbim/` — el backend Python

**Metáfora arquitectónica:** es la **oficina técnica**. No dibuja en el papel, pero hace los cálculos estructurales, controla la norma y firma el proyecto.

Está subdividido en módulos con responsabilidades claras:

| Subcarpeta | Qué hace | Archivos clave |
|------------|----------|----------------|
| `rpc/` | Recibe y envía mensajes desde Godot. Implementa JSON-RPC 2.0. | `server.py`, `dispatcher.py`, `framing.py`, `models.py` |
| `handlers/` | Código que se ejecuta cuando llega un mensaje concreto. Uno por acción. | `system.py`, `ifc.py`, `project.py` |
| `ifc/` | Lógica BIM pura: sesión IFC activa y creación de entidades. | `session.py`, `wall.py` |
| `geometry/` | Geometría discreta (mallas) e identificadores topológicos. | `meshing.py`, `topology.py` |
| `persistence/` | *(esqueleto)* Gestión futura de la base SQLite interna. | `migrator.py` |
| `drawing/` | *(esqueleto)* Futuro motor 2D (Fase 3). | — |
| `__main__.py` | Punto de entrada cuando ejecutas `python -m axonbim`. | — |
| `logging_config.py` | Configura cómo se ven los mensajes de log. | — |

Cada `__init__.py` es el letrero de la oficina: declara qué contiene la subcarpeta. Muchas están vacías a propósito (son marcadores).

#### 3.1.1. `rpc/` — la centralita

Cuatro archivos con un trabajo cada uno. La **separación de responsabilidades** es esencial: si un día cambiamos el protocolo, solo tocamos esta carpeta.

- **`models.py`** — define la forma exacta que tienen los mensajes. Un `JsonRpcRequest` siempre tiene `jsonrpc`, `method`, `params`, `id`. Usamos **Pydantic** (validador automático de datos): si Godot manda algo mal formado, Pydantic lo rechaza con un mensaje claro antes de que llegue al handler.

- **`framing.py`** — se ocupa de "leer un mensaje completo del flujo TCP". Los mensajes llegan con una cabecera tipo `Content-Length: 123\r\n\r\n{...}`. Si no existiera este archivo, dos mensajes muy rápidos se mezclarían. Misma técnica que usa el Language Server Protocol (Microsoft).

- **`dispatcher.py`** — el registro. Cuando arranca, cada handler se "da de alta" con un nombre (`system.ping`, `ifc.create_wall`...). Al llegar una petición, el dispatcher busca el handler registrado con ese nombre, valida los parámetros contra el modelo Pydantic, ejecuta el handler y convierte cualquier excepción a un código de error JSON-RPC estándar.

- **`server.py`** — escucha el puerto TCP y/o el socket Unix. Usa `asyncio` (programación asíncrona): un solo proceso puede atender múltiples clientes sin bloquearse.

#### 3.1.2. `handlers/` — los endpoints

Cada archivo expone una familia de "métodos RPC". Cuando Godot pide `ifc.create_wall`, se ejecuta la función correspondiente en `handlers/ifc.py`. Los handlers son **delgados**: no hacen lógica pesada, solo orquestan y devuelven.

Por ejemplo, el handler `ifc.create_wall`:

```python
# simplificado
def handle(params: CreateWallParams) -> CreateWallResult:
    guid, mesh = ifc_wall.create_wall(params.p1, params.p2, params.height, params.thickness)
    return CreateWallResult(guid=guid, mesh=mesh.as_dict())
```

La lógica pesada vive en `ifc/wall.py` y `geometry/meshing.py`. Así, si mañana cambiamos el protocolo a gRPC, los handlers cambian pero `ifc/wall.py` no se toca.

#### 3.1.3. `ifc/` — la sesión BIM

- **`session.py`** — mantiene el **archivo IFC activo** en memoria como un singleton thread-safe (objeto único protegido con un candado). Al inicializar, crea un `IfcProject` con unidades métricas y un sitio. Parecido a cuando abres AutoCAD con una plantilla en metros.

- **`wall.py`** — crea un `IfcWall` concreto. Calcula la longitud del eje, la orientación, la extrusión vertical, y emite las entidades IFC (`IfcWall`, `IfcExtrudedAreaSolid`, `IfcLocalPlacement`...). Devuelve el **GUID** (identificador único IFC, 22 caracteres) y una malla analítica para que Godot la pinte rápidamente.

#### 3.1.4. `geometry/` — matemática discreta

- **`meshing.py`** — conversión de geometría a **mallas de triángulos**, que es lo que entiende la GPU. Para un muro se generan 24 vértices (caja), 12 triángulos. La clase `Mesh` es un `dataclass` (estructura simple Python) con `vertices`, `indices`, `normals`.

- **`topology.py`** — stub del futuro **sistema de IDs topológicos persistentes**. Hoy genera un SHA-1 a partir del centroide, el área y la normal redondeados. En Fase 2 se extenderá para que un muro mantenga su identidad aunque lo recortes con una puerta.

### 3.2. `frontend/` — el proyecto Godot

**Metáfora arquitectónica:** es la **mesa de dibujo y el proyector para el cliente**. Todo lo que el usuario ve, todo lo que el usuario toca, y el 3D en pantalla.

```text
frontend/
├── project.godot               ← config general Godot + autoloads
├── scenes/main/main.tscn       ← la escena principal (la ventana)
├── scripts/
│   ├── autoload/
│   │   ├── logger.gd           ← singleton de logs
│   │   └── rpc_client.gd       ← cliente TCP hacia el backend
│   ├── main/main_scene.gd      ← lógica del sidebar (botones)
│   ├── tools/create_wall_tool.gd ← herramienta "crear muro por 2 clics"
│   └── viewport_3d/
│       ├── mesh_builder.gd     ← convierte malla JSON → ArrayMesh Godot
│       └── project_view.gd     ← mapa guid → MeshInstance3D
└── tests/                      ← tests GUT (opcionales)
```

**Autoload** en Godot = singleton siempre disponible. Aquí tenemos dos:

- **`Logger`** — cualquier script en Godot puede llamar `Logger.info("...")`. Formato consistente.
- **`RpcClient`** — la pieza central del frontend. Se conecta al backend al arrancar, mantiene la conexión viva, reintenta con *backoff exponencial* si se cae (500 ms → 1 s → 2 s → ... → 10 s) y expone dos operaciones:
  - `call_rpc(method, params) -> response` — llamada con respuesta.
  - `notify_rpc(method, params)` — notificación sin respuesta.

**Escena `main.tscn`** — el árbol de nodos de la interfaz:

- Un `HBoxContainer` raíz con dos hijos: `Sidebar` (panel izquierdo) y `ViewportContainer` (viewport 3D).
- El `Sidebar` contiene los botones (*Ping backend*, *Crear muro*, *Guardar IFC...*) y tres labels (estado del backend, RTT, log).
- El `ViewportContainer` envuelve un `SubViewport` con un `Node3D` *World* (cámara isométrica, luz direccional, grid, y un `ProjectView` que guarda las mallas creadas).

**Herramientas (`tools/`)** — son "modos" del cursor. Cuando pulsas *Crear muro*, se instancia `create_wall_tool.gd`: captura el primer clic (guarda punto A), captura el segundo clic (punto B), llama al backend, recibe la malla y la entrega a `ProjectView.add_entity(guid, mesh)`.

### 3.3. `tests/` — la prueba de calidad

Dos tipos de tests:

- **Unitarios** (`tests/unit/`) — prueban una función aislada. Rápidos (milisegundos).
- **Integración** (`tests/integration/`) — levantan el servidor real, conectan un cliente real, prueban el flujo completo. Más lentos pero detectan problemas que los unitarios no ven.

El test más importante es **`test_wall_roundtrip.py`**: simula un Godot fake que pide `ifc.create_wall` y luego `project.save`, y verifica que el archivo `.ifc` resultante es válido. Si este test falla, el producto está roto.

Ejecución:

```bash
uv run pytest                    # todos los tests
uv run pytest --cov              # con cobertura
uv run pytest tests/unit         # solo los rápidos
```

### 3.4. `docs/` — la documentación

- **`architecture/jsonrpc-protocol.md`** — contrato entre Godot y Python. Si dos piezas se conectan por cable, este documento describe el cable. Cuando un PR añade un método RPC, este documento se actualiza en el mismo commit (regla obligatoria).
- **`architecture/iso-19650.md`** — paráfrasis operativa de ISO 19650 (no copia). Describe cómo AxonBIM va a implementar estados `WIP/Shared/Published/Rejected/Archive` y el *Common Data Environment*.
- **`architecture/topological-naming.md`** — notas sobre el problema del *topological naming* (cómo mantener la identidad de una cara tras una booleana).
- **`architecture/decisions/`** — plantilla para ADRs (Architecture Decision Records). Vacía al cierre de Fase 1; la llenaremos cuando aparezcan decisiones con trade-offs reales.
- **`normativa/`** — extractos operativos de MOPC, CCRD/MIVED, INDOCAL (paráfrasis, nunca copias literales).
- **`packaging/`** — notas sobre Conda-pack vs PyInstaller (para Fase 4).
- **`phase-reports/`** — esta carpeta. Un reporte por fase.

### 3.5. `.cursor/rules/` — reglas del agente IA

Siete archivos `.mdc` que gobiernan cómo el agente (Cursor / Claude / etc.) escribe código en este repositorio. Cada regla tiene un frontmatter que indica cuándo se activa:

| Archivo | Qué regula |
|---------|-----------|
| `00-architecture.mdc` | Visión general, stack, división backend/frontend. |
| `10-anti-patterns.mdc` | Qué NO hacer (código basura, comentarios narrativos, trabajos a medias). |
| `20-backend-python.mdc` | Estándares Python (tipado, Pydantic, ruff, mypy). |
| `25-frontend-godot.mdc` | Estándares GDScript (tipado estático, autoloads, señales). |
| `30-bim-normativa.mdc` | Cómo referenciar normativa y jerarquía CCRD>MOPC. |
| `60-documentation.mdc` | **(nuevo)** Docstrings, ADRs, CHANGELOG, phase reports. |
| `70-copyright-legal.mdc` | **(nuevo)** Copyright, licencias de dependencias, assets. |

### 3.6. `.github/` — la fábrica automática

- **`workflows/ci.yml`** — al empujar a `main`/`develop` o abrir un PR:
  1. Instala Python 3.12 y 3.13.
  2. Corre `ruff check`, `ruff format --check`, `mypy --strict`, `pytest --cov` (gate 80%).
  3. Corre `gdformat --check` y `gdlint` sobre Godot.
  4. Si existe el addon GUT, corre los tests Godot headless.
  5. Verifica que Git LFS no tenga punteros rotos.
- **`workflows/pr-checks.yml`** — verifica que el título del PR siga [Conventional Commits](https://www.conventionalcommits.org/) (`feat(rpc): añadir ...`, `fix(ifc): ...`).
- **`dependabot.yml`** — un bot que abre PRs automáticos para actualizar dependencias.

---

## 4. Recorrido completo: "qué pasa cuando clicas Crear muro"

Este es el flujo más importante de la Fase 1. Trazarlo entero te da una imagen mental de todo el sistema.

### Paso 1 — Clic en el botón *Crear muro* (frontend)

`main_scene.gd` detecta la señal `pressed` del botón, y en su manejador:

```gdscript
_wall_tool = CreateWallTool.new(%ProjectView)
```

Se instancia la herramienta pasándole el `ProjectView` (el nodo 3D donde se añadirán los muros). El botón cambia su texto a "Click 1 de 2".

### Paso 2 — Primer clic en el viewport

`create_wall_tool.gd` escucha `input_event` del `ViewportContainer`. Con la cámara y la posición del mouse, proyecta un rayo hasta el plano Z=0 y guarda el punto de intersección como `_p1`. Actualiza el texto del botón a "Click 2 de 2".

### Paso 3 — Segundo clic en el viewport

Se repite el cálculo para `_p2`. Ahora tenemos dos puntos en metros, en coordenadas de mundo.

### Paso 4 — Llamada RPC

```gdscript
var response: Dictionary = await RpcClient.call_rpc("ifc.create_wall", {
    "p1": [_p1.x, _p1.y, _p1.z],
    "p2": [_p2.x, _p2.y, _p2.z],
    "height": 2.7,
    "thickness": 0.15,
})
```

`call_rpc` genera un `id` entero, serializa el mensaje como JSON, lo enmarca con `Content-Length:` y lo manda por el `StreamPeerTCP`. La corutina se suspende esperando la respuesta con ese `id`.

### Paso 5 — El backend recibe el mensaje

`server.py` (asyncio) lee bytes del socket. `framing.py` detecta el header `Content-Length`, lee exactamente esa cantidad de bytes, y entrega el cuerpo JSON. `models.JsonRpcRequest` lo valida:

- ¿Tiene `jsonrpc: "2.0"`?
- ¿Tiene `method: "ifc.create_wall"`?
- ¿Tiene `id`?

Si algo falla, se devuelve `-32600 Invalid Request` y el cliente lo ve en el `LogLabel`. Si pasa, el dispatcher continua.

### Paso 6 — Dispatch al handler

`dispatcher.py` busca `ifc.create_wall` en su registro y encuentra `handlers.ifc.handle`. Antes de llamarlo, valida los `params` contra `CreateWallParams` (Pydantic):

- `p1`, `p2` listas de tres floats.
- `height > 0`, `thickness > 0`.
- Distancia(`p1`, `p2`) `>= _MIN_WALL_LENGTH_M` (medio metro).

Si no cumple, retorna `-32602 Invalid Params` con el detalle Pydantic.

### Paso 7 — Creación del IfcWall

El handler llama a `ifc.wall.create_wall(...)`:

1. Obtiene la sesión activa (`ifc.session.get_session()`), que si no existe, se inicializa con `IfcProject` + unidades métricas.
2. Calcula el vector eje = `p2 - p1`, su longitud y ángulo.
3. Construye un `IfcLocalPlacement` en el punto medio con la rotación adecuada.
4. Crea el `IfcExtrudedAreaSolid` como rectángulo (thickness × longitud) extruido `height`.
5. Emite `IfcWall` con su representación.
6. Retorna `(guid, Mesh)` donde `Mesh` es la caja analítica (24 vértices, 12 triángulos) calculada por `geometry.meshing.wall_box_mesh(...)`.

### Paso 8 — Respuesta JSON-RPC

El handler serializa el resultado:

```json
{
  "jsonrpc": "2.0",
  "id": 42,
  "result": {
    "guid": "0TJlp9FMf1aRbIu9MfXkVN",
    "mesh": { "vertices": [...], "indices": [...], "normals": [...] }
  }
}
```

Va de vuelta por el mismo socket, enmarcado con `Content-Length:`.

### Paso 9 — El frontend recibe

`rpc_client.gd._consume_buffer()` detecta mensaje completo, lo parsea a `Dictionary`, busca la promesa pendiente con `id: 42` y la resuelve. La corutina del paso 4 despierta.

### Paso 10 — Pintado en el viewport

```gdscript
var mesh: ArrayMesh = MeshBuilder.build_array_mesh(response.result.mesh)
_project_view.add_entity(response.result.guid, mesh)
```

`MeshBuilder` convierte el diccionario JSON a un `ArrayMesh` nativo Godot (estructura GPU-friendly). `ProjectView.add_entity` crea un `MeshInstance3D` en la escena y lo registra en un diccionario interno `{guid: nodo}` para poder localizarlo luego.

### Paso 11 — Frame siguiente: se ve el muro

Godot renderiza la nueva `MeshInstance3D` en el viewport 3D. El `StatusLabel` muestra `Muro 0TJlp9FMf... creado`.

### Paso 12 — (Opcional) Guardar

Al pulsar *Guardar IFC...*, se llama a `project.save` con `{path: "/tmp/axonbim/out.ifc"}`. El handler invoca `session.save(path)` que serializa la sesión IFC a texto ISO 10303-21 y escribe el archivo. Puedes abrirlo con cualquier visor BIM.

---

## 5. Decisiones que tomamos y por qué

Las decisiones más importantes de esta fase, explicadas sin jerga. Cuando el proyecto madure, varias se elevarán a ADRs formales.

### 5.1. Separar backend Python y frontend Godot por un protocolo

**Alternativa descartada:** meter Python embebido dentro de Godot con GDExtension. **Por qué no:** acopla las dos aplicaciones (una caída del backend cuelga el editor), dificulta empaquetado (hay que recompilar Godot para cada cambio de Python), y rompe la portabilidad multiplataforma en el futuro.

**Ganancia:** puedes reiniciar el backend sin cerrar el editor. Puedes reemplazar el frontend Godot por una CLI o una web UI sin tocar Python. El backend es testeable sin Godot en CI.

### 5.2. JSON-RPC 2.0 sobre TCP loopback (+ Unix sockets para CLI)

**Alternativa descartada:** gRPC, REST, protocolo custom binario. **Por qué no:**

- gRPC requiere protobuf + compilador + dependencias GDExtension — sobreingeniería para la fase inicial.
- REST (HTTP) es verboso y no tiene notificaciones bidireccionales.
- Binario custom = reinventar la rueda.

**JSON-RPC 2.0** es texto legible (debuggeable con `tcpdump`), tiene respuestas y notificaciones, y es estándar con implementaciones probadas.

**Por qué TCP y no Unix socket para Godot:** Godot 4.x no expone `StreamPeerUnix` nativo. TCP loopback (127.0.0.1) tiene rendimiento casi idéntico en Linux (el kernel optimiza) y funciona en Windows/Mac si algún día se porta. Unix socket sigue activo para la CLI y los tests Python (más eficiente en ese caso).

### 5.3. Pydantic v2 en la frontera, `dataclass` dentro

**Alternativa descartada:** Pydantic en todas partes. **Por qué no:** Pydantic tiene coste (cada instancia valida); en cálculos geométricos con miles de vértices eso se nota.

**Regla:** Pydantic en la capa RPC (validación estricta de entrada no confiable). `dataclass` (estructuras Python nativas) en el núcleo geométrico (más rápido).

### 5.4. Geometría analítica para el muro en Fase 1

**Alternativa descartada:** enlazar desde el día 1 un kernel CAD pesado (cientos de MB de binarios y toolchain complejo en CI) solo para triangular una caja.

**Decisión:** en Fase 1, `wall_box_mesh` genera la caja con 8 vértices en Python puro. Las booleanas y sólidos más ricos se evaluarán por ADR cuando el producto las exija.

### 5.5. `sqlite3` de la librería estándar para persistencia interna

**Alternativa descartada:** SQLAlchemy, DuckDB. **Por qué no:** añaden dependencias pesadas para una base que será pequeña (metadatos y undo/redo). `sqlite3` viene con Python, es robusto, y es suficiente hasta cientos de miles de operaciones.

### 5.6. Conda-pack como mecanismo de empaquetado para Fase 4

**Alternativa descartada:** PyInstaller como primaria. **Por qué no:** PyInstaller suele requerir hooks para paquetes con extensiones C cargadas dinámicamente (IfcOpenShell es el ejemplo habitual del tronco). Conda-pack empaqueta un entorno Conda completo, incluyendo las DLL/`.so`.

**PyInstaller** queda como plan B si Conda-pack da problemas en Flatpak.

### 5.7. GPLv3 como licencia del proyecto

Software libre con copyleft fuerte. Cualquier derivado comercial debe publicar su código. Alinea con la misión de AxonBIM: **herramienta gratuita para arquitectura en República Dominicana sin lock-in propietario**.

### 5.8. Git LFS para archivos pesados

Los PDFs de normativa (que sean legalmente redistribuibles) se guardan con Git LFS para no inflar el historial. Los repositorios normales rompen con archivos binarios grandes.

### 5.9. Prohibición explícita de transcribir normas

Ver regla `30-bim-normativa.mdc` y `70-copyright-legal.mdc`. AxonBIM referencia normas como ISO 19650, MIVED CCRD, MOPC, pero **nunca copia texto literal**. Los documentos del repo son paráfrasis operativas. Esta decisión protege al proyecto legalmente y obliga a la claridad: si no sabes escribir la norma con tus palabras, no la entendiste bien.

---

## 6. Números de la fase

| Métrica | Valor |
|---------|-------|
| Líneas de código backend Python (`src/`) | ~1 356 |
| Líneas de código frontend Godot (`frontend/scripts/`) | ~552 |
| Líneas de tests Python (`tests/`) | ~981 |
| **Total LOC del proyecto** | **~2 941** |
| Métodos RPC implementados | 5 (`system.ping`, `system.version`, `system.shutdown`, `ifc.create_wall`, `project.save`) |
| Cobertura de tests Python | > 80 % (gate de CI) |
| Tests unitarios Python | 30+ |
| Tests de integración Python | 3 suites (`test_rpc_server`, `test_rpc_tcp`, `test_wall_roundtrip`) |
| Reglas del agente IA | 7 archivos `.mdc` |
| Archivos de documentación | 6 (protocolo, ISO, topología, normativa, packaging, este reporte) |
| Workflows de CI | 2 (`ci.yml`, `pr-checks.yml`) |
| Duración efectiva de la fase | ~3 meses a 10 h/semana |
| Release tageada | `v0.1.0-alpha.1` |

---

## 7. Lo que todavía no hace (y es honesto decirlo)

Esto NO es un proyecto terminado. Al cierre de Fase 1:

- **No se pueden modificar muros existentes** — solo crearlos. Editar cotas o eliminar no existe todavía.
- **No hay operaciones booleanas reales** — la caja es geométricamente exacta, pero no puedes meterle una puerta aún. (Fase 2.)
- **No hay undo/redo** — si te equivocas al colocar un muro, no hay `Ctrl+Z`. (Fase 2.)
- **No hay selección ni herramientas de medición** en el viewport. (Fase 2.)
- **No hay planos 2D** — el export es IFC puro, no DXF/PDF con simbología MIVED. (Fase 3.)
- **No hay validación normativa** automática (anchos mínimos, requisitos CCRD). (Fase 3.)
- **No hay persistencia de proyecto** — cierras AxonBIM y pierdes el trabajo en RAM (lo único que queda es el `.ifc` exportado). (Fase 2/4.)
- **No hay empaquetado instalable** — requiere terminal y `uv` para correr. (Fase 4.)
- **No hay colaboración multiusuario** ni estados ISO 19650 aplicados. (Fase 4.)

---

## 8. Qué viene en la Fase 2

**Objetivo:** modelado interactivo real con Push/Pull estilo SketchUp y sincronización Godot↔Python bidireccional.

Lo prioritario:

1. **Selección de cara** en el viewport 3D (raycast, highlight).
2. **Herramienta Push/Pull** — arrastrar una cara la empuja en su normal.
3. **Operaciones booleanas** en el backend con biblioteca madura elegida por ADR (suma, resta, intersección).
4. **Topological naming persistente** — cada cara mantiene su GUID aunque la geometría cambie. Este es el problema *difícil* de la fase.
5. **Undo/Redo con SQLite** — cada operación se apunta en `axon_internal.db`; puedes rebobinar.
6. **Tests de regresión geométrica** — snapshots de mallas con tolerancia 1e-6 para evitar que un refactor cambie silenciosamente la geometría.
7. Primer **ADR formal** probablemente sobre el esquema de topological naming.

**Criterio de salida de Fase 2:** un modelo con 50+ muros editado interactivamente durante una sesión completa sin perder identidad topológica y con undo/redo funcional.

---

## 9. Glosario mínimo

- **ADR** — *Architecture Decision Record*. Documento corto que captura una decisión de arquitectura y su porqué. Inmutable una vez aceptado.
- **ArrayMesh** — estructura de malla nativa de Godot, optimizada para GPU.
- **asyncio** — librería estándar de Python para programación asíncrona (un proceso atiende múltiples cosas sin hilos).
- **Autoload** — en Godot, un script o escena siempre cargada y accesible globalmente (singleton).
- **B-Rep** — *Boundary Representation*. Modelo geométrico basado en caras, aristas y vértices (IFC y motores CAD lo usan internamente).
- **Booleana** — operación geométrica de unión, resta o intersección entre sólidos.
- **CCRD** — *Código Consolidado de Reglamentos Dominicanos* emitido por MIVED.
- **CI/CD** — *Continuous Integration / Continuous Delivery*. Automatización que se ejecuta al subir cambios (tests, build).
- **Conventional Commits** — convención de nombres de commit (`feat: ...`, `fix: ...`) que permite generar CHANGELOG automáticamente.
- **dataclass** — decorador Python que genera automáticamente constructores, `__eq__`, etc. para clases de datos simples.
- **Dispatcher** — pieza que recibe un mensaje con un nombre de método y encuentra la función registrada para atenderlo.
- **Framing** — convención para marcar dónde empieza y termina un mensaje en un flujo de bytes continuo.
- **GUID** (IFC) — identificador único global de 22 caracteres. Cada entidad IFC tiene uno.
- **IFC** — *Industry Foundation Classes*. Estándar abierto de intercambio BIM (buildingSMART).
- **IfcOpenShell** — librería libre (LGPL) que lee/escribe IFC y expone un API Python.
- **IfcWall, IfcProject** — clases IFC: muro, proyecto raíz.
- **JSON-RPC 2.0** — protocolo de llamada remota basado en JSON. Simple, textual, con respuestas y notificaciones.
- **LSP framing** — *Language Server Protocol framing*. Convención de enmarcar mensajes con cabecera `Content-Length: N`.
- **Malla (Mesh)** — geometría discreta compuesta por vértices + triángulos. Es lo que pinta la GPU.
- **MIVED** — Ministerio de la Vivienda, Edificaciones y Desarrollo de República Dominicana.
- **MOPC** — Ministerio de Obras Públicas y Comunicaciones.
- **Pydantic** — librería Python de validación de datos por modelos tipados.
- **RPC** — *Remote Procedure Call*. Llamada a función que vive en otro proceso.
- **Singleton** — objeto único en toda la aplicación.
- **StreamPeerTCP** — clase Godot que envuelve un socket TCP.
- **Topological naming** — problema de mantener IDs estables de caras/aristas cuando el modelo geométrico cambia.
- **uv** — gestor Python moderno (Astral), reemplazo rápido de pip + venv.
- **Viewport** — ventana de renderizado 3D dentro del frontend Godot.

---

## Anexo A — Comandos útiles del día a día

```bash
# Actualizar dependencias
uv sync --extra dev

# Linter y formateo Python
uv run ruff check .
uv run ruff format .

# Type check
uv run mypy src tests

# Tests con cobertura
uv run pytest --cov --cov-report=term-missing

# Linter y formateo GDScript (requiere gdtoolkit)
gdformat --check frontend/scripts frontend/tests
gdlint frontend/scripts

# Arrancar backend (TCP en puerto default 5799)
uv run python -m axonbim --tcp
# o explicito: uv run python -m axonbim --tcp-port 5799

# Abrir Godot (5799 por defecto en RpcClient; env solo si cambias el puerto)
godot --path frontend
# Flatpak: flatpak run --env=AXONBIM_RPC_PORT=5799 org.godotengine.Godot --path frontend
```

## Anexo B — Convención de ramas y commits

- `main` — solo releases estables.
- `develop` — integración continua.
- `feature/<slug>` — nueva funcionalidad.
- `fix/<slug>` — corrección de bug.
- `docs/<slug>` — documentación o reglas.
- `chore/<slug>` — mantenimiento (deps, CI).

Mensajes de commit y títulos de PR siguen [Conventional Commits](https://www.conventionalcommits.org):

- `feat(rpc): añadir método ifc.create_slab`
- `fix(ifc): corregir orientación del muro con eje vertical`
- `docs(rules): actualizar regla 30-bim-normativa`
- `chore(deps): bump pydantic 2.6 → 2.7`

---

*Este reporte se cerró junto con la release `v0.1.0-alpha.1`. La Fase 2 está abierta a partir del commit siguiente en `develop`.*
