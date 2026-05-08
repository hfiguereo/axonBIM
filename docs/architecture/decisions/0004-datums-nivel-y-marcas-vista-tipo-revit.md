# ADR-0004: Datums de nivel y marcas de vista (paridad mínima tipo Revit)

- **Estado:** Proposed
- **Fecha:** 2026-05-07
- **Autores:** @hfiguereo
- **Fase:** Fase 2 → Fase 3 (documentación 2D y vistas técnicas)

---

## Contexto

El producto ya expone **niveles IFC** (`IfcBuildingStorey`, cota de trabajo, listado vía RPC) y **vistas 2D/ortográficas** (pestañas, presets, canvas analítico). Falta el comportamiento que en Revit se resuelve con **objetos gráficos en el lienzo**:

1. **Datums de nivel:** líneas horizontales con **nombre**, referencia de planta y **cota/altura**, visibles en planta y en alzado, editables **en contexto** (viewport), no solo en formularios.
2. **Marcas de vista:** en planta, un símbolo que **define dirección y vínculo** hacia una vista de elevación (o equivalente ortográfico), de modo que colocar o ajustar la marca **crea o actualiza** la vista asociada.

Sin una decisión explícita, el riesgo es duplicar fuentes de verdad (Godot vs IFC), o implementar anotación solo en frontend sin persistencia ni coherencia con el Project Browser y Propiedades.

## Decisión

Adoptamos un **MVP en dos frentes** que deben compartir el mismo modelo de datos visible en **viewport, Propiedades y Project Browser**:

### 1) Datums de nivel (storey graphics)

- La **verdad geométrica y de identidad** del nivel sigue siendo el **backend / IFC** (`GlobalId` de `IfcBuildingStorey`, elevación en metros).
- Godot dibuja **representación gráfica** (línea + etiqueta + grips) y envía mutaciones (p. ej. arrastre vertical, renombrar) vía **JSON-RPC** validadas en Python antes de tocar el modelo.
- Seleccionar un datum en vista abre la **misma entidad** en Propiedades; el **Project Browser** lista niveles y permite localizar/resaltar el datum activo.

### 2) Marcas de vista (plan → elevación)

- En planta, el usuario coloca o edita una **marca** con **vector de vista** (o preset ortogonal equivalente: Este/Oeste/Norte/Sur) y metadatos de nombre.
- Al confirmar o al mover la marca, el sistema **crea o actualiza** una entrada de vista técnica (pestaña / `view2d_*` / estado serializable de proyecto alineado con [ADR-0001](0001-multi-viewport-y-vistas-ortogonales.md)) cuya cámara o proyección queda **alineada** a esa dirección respecto al modelo.
- La marca tiene identidad estable en estado de proyecto; no es solo decoración: **Propiedades** editan parámetros; el **Project Browser** muestra la vista hija vinculada.

### Principios transversales

- **Backend como verdad** para todo lo que sea IFC o geometría normativa; extensiones de proyecto (marcas no IFC en primera iteración) se serializan en el **estado de proyecto** acordado con el puente, documentado en `docs/architecture/jsonrpc-protocol.md` cuando se añadan métodos o campos.
- **Una entidad, tres superficies de edición:** viewport (rápido), panel de propiedades (detalle), árbol de proyecto (navegación).

## Alternativas consideradas

### Alternativa A — Solo overlays en Godot sin RPC

- **Descripción:** dibujar líneas y textos de nivel y marcas solo en el cliente; persistir en escena `.tscn` o recursos locales.
- **Pros:** implementación rápida; menos carga en el puente.
- **Contras:** divergencia con IFC; sin garantía de que otra sesión o export vea lo mismo; viola el núcleo “Python decide” para datos de edificio.
- **Motivo por el que se descartó:** insostenible para BIM colaborativo y para normativa Fase 3.

### Alternativa B — Todo en backend como geometría IFC adicional

- **Descripción:** modelar marcas y líneas como entidades IFC explícitas desde el primer día.
- **Pros:** trazabilidad máxima en el STEP.
- **Contras:** sobrecarga de modelo IFC y de mapeo semántico antes de tener el flujo UX cerrado; riesgo de semántica ambigua (¿`IfcAnnotation`? ¿`IfcGrid`?).
- **Motivo por el que se descartó:** aplazar hasta que el flujo gráfico esté validado; el MVP puede anclar marcas al estado de proyecto y documentar migración a IFC si hace falta.

## Consecuencias

### Positivas

- Camino claro hacia documentación 2D coherente con [ADR-0002](0002-estrategia-combinada-2d-analitica-orto-y-export-dxf.md).
- Usuario obtiene **parámetros gráficos** sin abandonar el modelo dual Godot/Python.
- Base para hojas, cotas y secciones en Fase 3.

### Negativas / trade-offs aceptados

- Nuevos métodos RPC y/o campos de serialización de proyecto; mantenimiento del contrato en `jsonrpc-protocol.md`.
- Complejidad de selección/hit-testing en 2D y sincronía multi-vista.

### Neutras

- Las marcas de vista pueden convivir temporalmente con vistas creadas manualmente por preset hasta unificarse en el Browser.

## Plan de implementación (opcional)

- [x] Fase datum (MVP): RPC ``project.update_storey``; representación 3D + grip seleccionable; panel Propiedades y rama **Niveles** en el Project Browser. (Pendiente: grips en alzado/vistas 2D y edición por arrastre.)
- [ ] Fase marca: esquema de `ViewMarker` (o nombre acordado) en estado de proyecto; UI en planta; creación/actualización de vista ortográfica vinculada; documentar en protocolo RPC.
- [ ] Tests: unitarios backend para validación de elevación/nombre; GUT o pruebas manuales de flujo en Godot según `AGENTS.md`.
- [ ] Revisión post-MVP: si las marcas deben exportarse a IFC, ADR de seguimiento o extensión de este documento.

## Referencias

- PR que acompaña este ADR: N/A (definición previa a implementación)
- ADRs relacionados: [0001](0001-multi-viewport-y-vistas-ortogonales.md), [0002](0002-estrategia-combinada-2d-analitica-orto-y-export-dxf.md)
- Especificación puente: `docs/architecture/jsonrpc-protocol.md`
