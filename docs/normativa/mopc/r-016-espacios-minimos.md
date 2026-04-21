# R-016 — Espacios Mínimos en la Vivienda Urbana

> **Documento fuente:** [`sources/mopc/r-016-espacios-minimos-vivienda.pdf`](../sources/mopc/r-016-espacios-minimos-vivienda.pdf)
> **Título oficial:** Recomendaciones Provisionales para Espacios Mínimos en la Vivienda Urbana
> **Autoridad emisora:** MOPC
> **Páginas:** 58
> **Vigencia:** Vigente (pendiente verificar si CCRD lo sustituye).
> **Estado de extracción:** 🔴 **Bloqueante para Fase 3 (validador de áreas habitables).** PDF con texto extraíble 📄.

---

## 1. Por qué importa para AxonBIM

R-016 define áreas mínimas obligatorias por tipo de habitación en vivienda urbana:

- Sala, comedor, cocina (mínimo por espacio y combinados).
- Dormitorio principal, dormitorio secundario.
- Baño principal, baño social.
- Lavadero, balcón, estudio.
- Relación entre área total y número de ocupantes.

AxonBIM debe validar al exportar planos si todos los espacios cumplen R-016, y reportar déficits con ubicación específica.

## 2. Constantes operativas

> Pendiente extracción. Usar `# TODO(MOPC-R016): pendiente §<sección>`.

### 2.1 Áreas mínimas por habitación
*Pendiente extracción.*

### 2.2 Dimensiones lineales mínimas
*Pendiente extracción.*

### 2.3 Alturas mínimas
*Pendiente extracción.*

### 2.4 Iluminación y ventilación natural
*Pendiente extracción.*

## 3. Para el agente

- Asociar cada `IfcSpace` con un tipo (sala, dormitorio, etc.) vía `Pset_SpaceCommon.IsExternal=false` + propiedad `LongName` o clasificación Uniclass local.
- Validar área (`IfcSpace.Area`) y bounding box contra las tablas del §2.
- Al exportar, incluir tabla de áreas como anexo del plano.

## 4. Referencias cruzadas

- CCRD Vol. I §3.7.3 puede tener requisitos complementarios.
- Normas municipales de zonificación pueden imponer áreas mayores.
