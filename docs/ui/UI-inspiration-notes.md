# Inspiración UI (boceto tipo escritorio BIM)

## Origen

En el repo existía la carpeta **`UI Ejemplo/`** con un único archivo
`UI ejemplo.rtf`: GDScript de un **mockup procedural** (cinta por
disciplinas, navegador, viewport, propiedades) pegado en formato RTF, no una
escena Godot importable.

## Qué se reutilizó (y dónde vive ahora)

| Idea del boceto | Implementación actual |
|-----------------|------------------------|
| Paleta gris/blanco y acentos suaves tipo Revit | Constantes y `StyleBoxFlat` en `frontend/scripts/ui/ribbon_workspace_theme.gd`. |
| Pestañas de cinta con fondo y borde discretos | Overrides en el `TabBar` de `main.tscn` aplicados en tiempo de ejecución desde ese script. |
| Paneles laterales y grupos del ribbon con borde | `PanelContainer` del ribbon, cabeceras de docks, barra de estado y `Tree` del navegador. |
| Botones del ribbon con hover/pressed claros | Estilos en los botones Ping / Muro / Push-Pull / Guardar. |
| Fondo del visor 3D gris azulado claro | `Environment.background_color` en `main.tscn` (valor por defecto) + misma tonalidad aplicada al recurso en `_ready` por coherencia con la paleta. |
| Anchuras mínimas navegador / propiedades más generosas | `custom_minimum_size` del dock izquierdo (260 px) y derecho (280 px) en `main.tscn`. |

## Qué no se portó (a propósito)

- Construcción **100 % en código** de toda la UI: AxonBIM mantiene el layout
  en **`frontend/scenes/main/main.tscn`** y la lógica en
  **`main_scene.gd`** (herramientas, RPC, árbol).
- Pestañas de disciplina “Arquitectura / Estructura” con botones placeholder:
  la cinta real sigue **Inicio / Insertar / Vista** conectada a herramientas;
  ampliar disciplinas es un hito de producto aparte.

## Archivo de origen

El RTF se **eliminó** del repositorio tras esta integración; la referencia
histórica queda en este documento y en el comentario de cabecera del script
de tema.

## Proceso para futuros bocetos

1. Preferir **`.gd` + `.tscn`** (o al menos `.gd` suelto) versionados bajo
   `frontend/`, no RTF/PDF con código.
2. Extraer solo **paleta, espaciados y patrones de `Theme`/`StyleBox`** al
   script de tema o a un recurso `.tres`, sin duplicar jerarquía de la escena
   principal.
3. Tras migrar ideas útiles, borrar o mover a `docs/archive/` el artefacto
   temporal para no confundir a CI ni a colaboradores.
