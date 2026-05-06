# Manual de AxonBIM

Documento de **ayuda para el usuario final** (arquitecto, modelador, BIM manager): qué hace la aplicación hoy, cómo usar las herramientas visibles y por dónde seguir leyendo. No sustituye el protocolo técnico ni la normativa; enlaza a ellos cuando haga falta.

**Última revisión orientativa:** 2026-05 (alinear con `CHANGELOG.md` sección `[Unreleased]` y releases tageadas).

---

## 1. Qué es AxonBIM

AxonBIM es un editor BIM **open source** (GPLv3) que separa de forma estricta:

- **Frontend (Godot):** interfaz, viewport 3D, herramientas y feedback.
- **Backend (Python):** geometría, IFC, historial y validación; es la **autoridad** del modelo.

Los dos procesos se comunican por **JSON-RPC 2.0** (TCP en desarrollo típico). Detalle en [`docs/architecture/jsonrpc-protocol.md`](architecture/jsonrpc-protocol.md).

---

## 2. Puesta en marcha

Resumen; el arranque completo y prerequisitos están en [`README.md`](../README.md).

1. Instalar dependencias del backend (`uv sync` o equivalente del proyecto).
2. Levantar el backend con TCP (puerto por defecto **5799** en la configuración habitual).
3. Abrir el proyecto Godot bajo `frontend/` y ejecutar la escena principal (por ejemplo **F5** en el editor).

Atajo recomendado en Linux: `./start` o `make start` (backend + Godot según el `Makefile`).

Si el backend no está disponible, la interfaz puede mostrar avisos de conexión; la barra o el registro de la aplicación suelen indicar el fallo en lenguaje claro.

---

## 3. Ventana principal

De forma general (puede variar ligeramente entre versiones):

| Zona | Función |
|------|---------|
| **Barra / acciones** | Comandos globales: comprobar conexión con el backend, guardar IFC, deshacer, etc. |
| **Panel lateral** | Árbol de proyecto, herramientas de modelado y **Propiedades** (parámetros de la herramienta activa). |
| **Viewport 3D** | Vista del modelo, selección de entidades y, según la herramienta, **clics** para definir geometría o caras. |
| **Estado** | Mensajes breves (errores, RTT del ping, confirmaciones). |

Patrón de entrada 3D (SubViewport embebido): ver [`docs/architecture/app-gui-viewport-patterns.md`](architecture/app-gui-viewport-patterns.md).

---

## 4. Herramientas y acciones

| Elemento | Uso |
|----------|-----|
| **Ping backend** | Comprueba que el frontend llega al servidor JSON-RPC; suele mostrar tiempo de ida y vuelta (RTT). |
| **Navegación 3D** | Convención **Z arriba** (plano XY). **1–3** = ortogonales; **4** (o órbita desde orto) = perspectiva. **Fondo** plano único sin domo celeste. Órbita (MMB / **Alt+clic**), zoom y pan (**Mayús+MMB**). Sin marco interior que coma píxeles del 3D; splits sin agarrador visible. **HUD** esquina superior izquierda: **±X · ±Y** en planta (**medias** del espacio IFC, se **amplían** proporcionalmente al dibujar muros) más pista de encuadre (ortográfica vs perspectiva). **Teclado numérico** 7/1/3/0; botones esquina **Planta … Inicio**. **Tonemap ACEs**, **MSAA**; rejilla según ángulo. |
| **Selección** | Elige una entidad en el modelo para inspeccionarla o combinarla con otras acciones. |
| **Crear muro** | **Nivel base** por ahora fijo (00); más adelante habrá **niveles** y **desfases**. En **vista 3D** el muro se define en el **plano horizontal** (eje **Z** arriba; huella en **X/Y**). En **vista 2D OCC** el trazo usa **esa misma huella en X/Y** leyendo la geometría de la vista, **sin** tomar la **cámara 3D** como referencia del dibujo. El **primer** segmento pide clic **P1** y clic **P2**; cada muro válido sigue desde el **final (P2) del anterior**, de modo que el siguiente trazo suele ser **solo un clic (P2)**. **Alt + clic** fuerza **nuevo P1**. **Esc** o el mismo botón cierran la herramienta. Inferencia a ejes **X/Y** desde P1 y a **X=0 / Y=0**. **Altura y espesor** en **Propiedades** (tipología/familia). La pista bajo el visor muestra **largo en planta**, altura/espesor, etc., al mover el ratón durante el trazo. |
| **Push/Pull** | Modelado directo: tras **fijar una cara** (modo edición), arrastrar o introducir **distancia numérica** en Propiedades para extruir según el vector indicado. Con el ratón sobre el modelo, el resaltado de hover agrupa la **cara lógica** (todos los triángulos que comparten el mismo `topo_id`), no solo el triángulo bajo el cursor. |
| **Editar elemento** | Modo de edición acotado a un elemento (doble clic en un elemento seleccionado o acción equivalente en Propiedades). **Esc** o el mismo control suelen salir del modo. Push/Pull queda limitado a ese elemento mientras dure el modo. |
| **Eliminar muro** | Con **un muro IFC** seleccionado (viewport o árbol del proyecto): botón **Eliminar muro** en **Propiedades**, o tecla **Supr** cuando el ratón está **sobre el viewport** y no tienes foco en un campo de texto. Elimina la entidad en la sesión IFC y la quita del árbol y del visor 3D. |
| **Guardar IFC…** | Escribe el modelo activo en disco en formato IFC (ruta según el flujo implementado en esa versión). |
| **Generar vistas 2D…** | Con OCC 2D habilitado, exporta `top/front/right` desde `draw.ortho_snapshot` a PNG técnico raster; si OCC falla, cae a la ruta legacy (captura ortográfica del viewport) sin bloquear la UI. |
| **Exportar muros DXF (planta)…** | Guarda un `.dxf` con la huella de los muros de la sesión en **planta** (`view: top`), capa `WALLS`, unidades en metros (proyección analítica en backend). Requiere al menos un muro en el modelo. |
| **Modo 2D: Auto / Plano vectorial / Modelo ortográfico** | Cambia el ruteo de visualización en pestañas 2D. **Auto** intenta plano vectorial (`draw.ortho_snapshot`, analítico) y hace fallback a ortográfico de modelo si no hay líneas o hay error. **Plano vectorial** fuerza snapshot backend. **Modelo ortográfico** desactiva snapshot y usa la cámara ortográfica del viewport. |
| **Vistas 2D en Project Browser** | En `Navegador de proyecto` aparece `Vistas 2D` (Planta/Frente/Derecha por defecto). Puedes crear nuevas con `+ Vista 2D` y borrar la seleccionada con `Eliminar vista`. Cada vista mantiene estado (`loading/ready/error/fallback`) y escala aproximada por vista durante la sesión activa; si OCC falla, vuelve automáticamente al preset ortográfico legacy. En OCC 2D: **rueda = zoom**, **MMB arrastre = pan**. |
| **View Range (Planta 2D OCC)** | La planta OCC usa rango de vista configurable (`cut/top/bottom/depth`). Atajos iniciales: **PgUp/PgDn** ajustan el plano de corte (`cut_plane`) en pasos de 0,10 m. El HUD muestra zoom + valores activos del rango. |
| **Deshacer / Rehacer** | Operaciones mutantes recientes (p. ej. extrusiones) vía historial; atajos habituales **Ctrl+Z** y **Ctrl+Shift+Z** cuando estén cableados en la escena. |

Los iconos y textos exactos siguen el tema e iconografía del proyecto (`frontend/assets/` y guías en ese directorio).

---

## 5. Flujos recomendados

### 5.1. Primera comprobación

1. Arrancar backend y frontend.
2. **Ping backend** y comprobar RTT o mensaje de éxito.

### 5.2. Primer muro y archivo

1. Activar **Crear muro**. En **Propiedades** elige **tipología / familia** (o **Personalizado**) y altura/espesor para el **siguiente trazo** (aparece el bloque aunque no haya muro seleccionado).
2. Clic **P1** y clic **P2** en el suelo del viewport para el primer muro; aparece la pieza y el siguiente trazo suele usar **solo P2** (continúa desde el extremo del anterior). Para empezar en otro sitio pulsa **Alt + clic**.
3. Sigue dibujando o pulsa **Esc** / el botón **Crear muro** otra vez para salir de la herramienta.
4. Para cambiar altura/espesor de un **muro ya colocado** sin Push/Pull: selecciónalo, ajusta familia o valores en **Propiedades** y **Aplicar tipología al muro**.
5. Para quitar un muro de la sesión: selecciónalo y **Eliminar muro** o **Supr** (ratón sobre el visor).
6. **Guardar IFC…** y abrir el archivo con otra herramienta BIM compatible (BlenderBIM, visores IFC, etc.).

### 5.3. Extrusión de cara (Push/Pull)

1. Seleccionar el elemento y entrar en **Editar elemento** si el flujo lo exige.
2. Activar **Push/Pull** y **fijar la cara** a editar (según la UI de la versión).
3. Arrastrar o introducir la **distancia** en el panel Propiedades y aplicar.
4. Usar **Deshacer** si el resultado no es el deseado.

---

## 6. Límites actuales y roadmap

- El **ROADMAP** del producto está en [`ROADMAP.md`](../ROADMAP.md): fases 3 en adelante incluyen planos 2D MIVED, estados ISO 19650 avanzados y empaquetado para usuario final sin terminal.
- Lo que ya se cerró en fases anteriores se resume en [`docs/phase-reports/`](phase-reports/) (p. ej. informe de Fase 1).
- No se documentan aquí valores normativos numéricos del CCRD u otras normas: usar [`docs/normativa/`](normativa/).
- En 2D, el modo **Plano vectorial** hoy prioriza cobertura de muros caja; para geometría todavía no proyectada por reglas analíticas, usar **Auto** (con fallback) o **Modelo ortográfico**.

---

## 7. Documentación relacionada

| Documento | Propósito |
|-----------|-----------|
| [`README.md`](../README.md) | Instalación, filosofía, comandos de desarrollo. |
| [`CHANGELOG.md`](../CHANGELOG.md) | Historial de cambios orientado a usuario. |
| [`docs/architecture/jsonrpc-protocol.md`](architecture/jsonrpc-protocol.md) | Contrato RPC entre Godot y Python. |
| [`docs/architecture/app-gui-viewport-patterns.md`](architecture/app-gui-viewport-patterns.md) | Patrones de UI y viewport. |

---

## Mantenimiento de este manual

Quien cambie **flujos visibles**, **nombres de herramientas**, **atajos** o **mensajes orientados al usuario** debe actualizar **este archivo** en el mismo PR o en uno inmediato, y reflejar el cambio en `CHANGELOG.md` cuando corresponda. La regla del repositorio `.cursor/rules/67-manual-de-axonbim.mdc` detalla el criterio para agentes y revisores.
