# ADR-0005: Renderizado Godot GL por defecto y perfiles de GPU (Linux)

- **Estado:** Accepted
- **Fecha:** 2026-05-07
- **Autores:** @hfiguereo
- **Fase:** Tronco (soporte de producto y desarrollo)

---

## Contexto

AxonBIM usa **Godot 4.x** con el **renderer GL Compatibility** (OpenGL) por defecto en [`frontend/project.godot`](../../../frontend/project.godot) porque el camino **Forward+ (Vulkan)** ha mostrado **SIGABRT** en combinaciones frecuentes de desarrollo (**Flatpak + GPU NVIDIA**), sin relación con la lógica GDScript del proyecto.

En paralelo:

- La regla interna del repo citaba **Forward+ obligatorio**, contradiciendo el `project.godot` real.
- El script [`scripts/dev/linux_profile.sh`](../../../scripts/dev/linux_profile.sh) exportaba **`DRI_PRIME=0`** cuando la variable no estaba definida; en muchos stacks Mesa eso **no es un valor válido** y produce el aviso *Invalid value (0) for DRI_PRIME. Should be > 0*.
- El ahorro de GPU **no depende solo del driver**: [`frontend/scripts/viewport_3d/viewport_manager.gd`](../../../frontend/scripts/viewport_3d/viewport_manager.gd) controla `SubViewport.render_target_update_mode` (p. ej. pausar 3D cuando una **vista 2D vectorial** cubre el lienzo) y [`frontend/scripts/main/main_scene.gd`](../../../frontend/scripts/main/main_scene.gd) aplica **MSAA** al viewport principal. Esa política forma parte del contrato de rendimiento documentado junto a la elección de API gráfica.

## Decisión

1. **Mantener** `renderer/rendering_method="gl_compatibility"` como **default del repositorio** hasta que una matriz de pruebas explícita autorice un cambio global a Forward+.
2. **Forward+/Vulkan** queda como **opt-in** del proyecto Godot (*Project → Project Settings → Rendering → Method → Forward+*) solo cuando el entorno (drivers, Flatpak vs binario oficial) lo tolera; el riesgo de inestabilidad queda documentado en [`README.md`](../../../README.md).
3. Sustituir el export fijo `DRI_PRIME=0` por un contrato **`AXONBIM_GPU_PROFILE`** (`auto` \| `integrated` \| `dedicated`) implementado en `linux_profile.sh` y descrito en el README:
   - **`auto`** (default): no se exportan variables de selección de GPU; respeta lo que el usuario o el SO ya hayan definido.
   - **`integrated`**: no se fuerzan variables PRIME; se documentan alternativas manuales (p. ej. `__GLX_VENDOR_LIBRARY_NAME=mesa` en GLX) para quien necesite reducir ruido de sonda de la dGPU.
   - **`dedicated`**: exportar `DRI_PRIME=1` para intentar **offload** a la GPU discreta en portátiles híbridos (requiere stack NVIDIA/propietario operativo; puede fallar si los drivers no están listos).
4. Centralizar la **matriz entorno × renderer × variables** en el README y enlazar este ADR desde el manual de usuario.

## Alternativas consideradas

### Alternativa A — Forward+ (Vulkan) como default del `project.godot`

- **Descripción:** alinear el binario con la regla antigua “Vulkan obligatorio”.
- **Pros:** mejor pipeline moderno en GPUs donde Vulkan es estable.
- **Contras:** regresión de estabilidad en Flatpak+NVIDIA documentada; más soporte en issues.
- **Motivo por el que se descartó:** el producto prioriza **arranque reproducible** en el entorno de desarrollo más común del autor/colaboradores.

### Alternativa B — Seguir exportando `DRI_PRIME=0` por defecto

- **Descripción:** mantener el hack para “silenciar” sondas de NVIDIA.
- **Pros:** ninguno durable; el valor 0 es inválido en Mesa.
- **Contras:** aviso confuso en consola; semántica incorrecta.
- **Motivo por el que se descartó:** deuda técnica real; se reemplaza por perfiles explícitos.

## Consecuencias

### Positivas

- Una **fuente de verdad** (este ADR + README) para agentes y humanos.
- Lanzadores Linux sin valores mágicos inválidos para PRIME.
- El contrato de rendimiento **aplicación + driver** queda explícito (viewport / MSAA enlazados arriba).

### Negativas / trade-offs aceptados

- Quien dependía implícitamente de `DRI_PRIME=0` dejará de tenerlo; debe usar `AXONBIM_GPU_PROFILE=integrated` o variables del README si aún necesita forzar Mesa.
- Forward+ sigue siendo responsabilidad del **usuario del editor** si lo activa en ajustes del proyecto.

### Neutras

- Windows/macOS no cargan `linux_profile.sh`; no hay cambio de comportamiento allí.

## Referencias

- [`README.md`](../../../README.md) — matriz GPU, checklist de verificación, Flatpak+NVIDIA.
- [`scripts/dev/linux_profile.sh`](../../../scripts/dev/linux_profile.sh) — `AXONBIM_GPU_PROFILE`.
- [`frontend/project.godot`](../../../frontend/project.godot) — `renderer/rendering_method`.
