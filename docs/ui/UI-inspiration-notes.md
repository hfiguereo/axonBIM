# Inspiración UI (boceto tipo escritorio BIM)

## Origen

En el repo existía la carpeta **`UI Ejemplo/`** con un único archivo
`UI ejemplo.rtf`: GDScript de un **mockup procedural** (cinta por
disciplinas, navegador, viewport, propiedades) pegado en formato RTF, no una
escena Godot importable. Parte de esa línea se exploró en la rama **`temporal`**
y se consolidó después en **`develop`** con otra organización de archivos.

## Qué se reutilizó (y dónde vive ahora)

| Idea del boceto | Implementación actual |
|-----------------|------------------------|
| Paleta gris/blanco y acentos suaves tipo Revit | Constantes de color y `StyleBoxFlat` / overrides en `frontend/scripts/main/main_scene.gd` y tema `frontend/themes/axon_theme.tres`. |
| Pestañas de cinta con fondo y borde discretos | `TabBar` y ribbon en `frontend/scenes/main/main.tscn` + estilos aplicados desde `main_scene.gd`. |
| Paneles laterales y grupos del ribbon con borde | `PanelContainer` del ribbon, cabeceras de docks, barra de estado y `Tree` del navegador (`main.tscn`). |
| Botones del ribbon con hover/pressed claros | Estilos en los botones de la cinta (ping, muro, push/pull, archivo, etc.) vía `_apply_button_style` en `main_scene.gd`. |
| Fondo del visor 3D gris azulado claro | `Environment.background_color` en `main.tscn` y ajustes coherentes en `main_scene.gd` / rig de cámara. |
| Anchuras mínimas navegador / propiedades más generosas | `custom_minimum_size` de docks izquierdo/derecho en `main.tscn`. |

## Qué no se portó (a propósito)

- Construcción **100 % en código** de toda la UI: AxonBIM mantiene el layout
  en **`frontend/scenes/main/main.tscn`** y la lógica en
  **`main_scene.gd`** (herramientas, RPC, árbol).
- Pestañas de disciplina “Arquitectura / Estructura” con botones placeholder:
  la cinta real sigue **Inicio / Insertar / Vista** conectada a herramientas;
  ampliar disciplinas es un hito de producto aparte.

## Archivo de origen

El RTF se **eliminó** del repositorio; la referencia histórica queda en este
documento.

## Proceso para futuros bocetos

1. Preferir **`.gd` + `.tscn`** (o al menos `.gd` suelto) versionados bajo
   `frontend/`, no RTF/PDF con código.
2. Extraer solo **paleta, espaciados y patrones de `Theme`/`StyleBox`** al
   recurso de tema o a la escena principal, sin duplicar jerarquía innecesaria.
3. Tras migrar ideas útiles, borrar o mover a `docs/archive/` el artefacto
   temporal para no confundir a CI ni a colaboradores.
