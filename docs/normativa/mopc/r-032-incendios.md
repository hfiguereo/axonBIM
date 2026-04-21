# R-032 — Seguridad y Protección Contra Incendios

> **Documento fuente:** [`sources/mopc/r-032-incendios-2019.pdf`](../sources/mopc/r-032-incendios-2019.pdf)
> **Título oficial:** Reglamento para la Seguridad y Protección Contra Incendios
> **Decretos:** 85-11, modificado por 364-16 y 347-19
> **Autoridad emisora:** MOPC
> **Año:** 2019 (versión consolidada)
> **Páginas:** 92
> **Vigencia:** Vigente.
> **Estado de extracción:** 🔴 **Bloqueante para Fase 3 (validador de rutas de escape).** PDF con texto extraíble 📄.

---

## 1. Por qué importa para AxonBIM

R-032 define:

- **Rutas y medios de escape** según ocupación y uso del edificio.
- **Distancias máximas** desde cualquier punto hasta una salida.
- **Ancho de salidas** según capacidad de ocupación.
- **Compartimentación** contra fuego (muros cortafuego, puertas RF).
- **Sistemas de detección y extinción** (rociadores, hidrantes, extintores).
- **Señalización** de emergencia.
- **Iluminación de emergencia**.

Validar cumplimiento R-032 es parte crítica de la exportación de un proyecto, especialmente en edificaciones públicas, comerciales o de más de cierto número de ocupantes.

## 2. Constantes operativas

> Pendiente extracción.

### 2.1 Clasificación de ocupación
*Pendiente extracción.*

### 2.2 Distancias máximas a salidas
*Pendiente extracción.*

### 2.3 Anchos de salida por capacidad
*Pendiente extracción.*

### 2.4 Compartimentación y resistencia al fuego
*Pendiente extracción.*

### 2.5 Sistemas activos y pasivos
*Pendiente extracción.*

## 3. Para el agente

- Implementar validador `validate_fire_egress(project)` que:
  1. Clasifique la ocupación del edificio.
  2. Calcule cargas de ocupación por espacio.
  3. Trace rutas de escape desde cada punto accesible.
  4. Verifique distancias máximas y anchos vs §2.2 y §2.3.
  5. Detecte ausencia de compartimentación donde se requiere.
- Emitir plano de evacuación como parte del paquete de licencia.

## 4. Referencias cruzadas

- R-031 (circulación vertical) — escaleras de emergencia.
- R-007 (accesibilidad) — rutas accesibles en emergencia.
- NFPA (National Fire Protection Association) — R-032 se inspira en NFPA 101.
