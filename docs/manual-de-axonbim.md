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
| **Navegación 3D** | Convención **Z arriba** (plano XY). **Rueda:** zoom. **Botón central + arrastre:** órbita. **Mayús + botón central:** pan. **Trackpad:** **Alt + clic izquierdo** órbita; **Mayús + clic izquierdo** pan; **Ctrl o Meta + clic izquierdo** (arrastre vertical) zoom; gesto de **pellizco** también acerca o aleja. **Teclas** (con el ratón sobre el visor): fila **1–4** = planta / frente / derecha / perspectiva de trabajo; **Inicio** o **R** = vista inicial. **Teclado numérico:** **7 / 1 / 3 / 0** = mismas vistas. Esquina del visor: **Planta / Frente / Derecha / Persp / Inicio**. |
| **Selección** | Elige una entidad en el modelo para inspeccionarla o combinarla con otras acciones. |
| **Crear muro** | Flujo en dos clics en el suelo (inicio y fin del eje del muro); el backend genera la malla y el IFC. |
| **Push/Pull** | Modelado directo: tras **fijar una cara** (modo edición), arrastrar o introducir **distancia numérica** en Propiedades para extruir según el vector indicado. Con el ratón sobre el modelo, el resaltado de hover agrupa la **cara lógica** (todos los triángulos que comparten el mismo `topo_id`), no solo el triángulo bajo el cursor. |
| **Editar elemento** | Modo de edición acotado a un elemento (doble clic en un elemento seleccionado o acción equivalente en Propiedades). **Esc** o el mismo control suelen salir del modo. Push/Pull queda limitado a ese elemento mientras dure el modo. |
| **Guardar IFC…** | Escribe el modelo activo en disco en formato IFC (ruta según el flujo implementado en esa versión). |
| **Deshacer / Rehacer** | Operaciones mutantes recientes (p. ej. extrusiones) vía historial; atajos habituales **Ctrl+Z** y **Ctrl+Shift+Z** cuando estén cableados en la escena. |

Los iconos y textos exactos siguen el tema e iconografía del proyecto (`frontend/assets/` y guías en ese directorio).

---

## 5. Flujos recomendados

### 5.1. Primera comprobación

1. Arrancar backend y frontend.
2. **Ping backend** y comprobar RTT o mensaje de éxito.

### 5.2. Primer muro y archivo

1. Activar **Crear muro**.
2. Dos clics en la cuadrícula del viewport para definir el segmento.
3. **Guardar IFC…** y abrir el archivo con otra herramienta BIM compatible (BlenderBIM, visores STEP/IFC, etc.).

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
