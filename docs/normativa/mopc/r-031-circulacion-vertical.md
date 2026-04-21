# R-031 — Medios de Circulación Vertical en Edificaciones

> **Documento fuente:** [`sources/mopc/r-031-circulacion-vertical-2015.pdf`](../sources/mopc/r-031-circulacion-vertical-2015.pdf)
> **Título oficial:** Reglamento para el Diseño de Medios de Circulación Vertical en Edificaciones (2da edición)
> **Decreto:** 361-15 (sustituye 84-11)
> **Autoridad emisora:** MOPC
> **Año:** 2015
> **Páginas:** 29
> **Vigencia:** Vigente.
> **Estado de extracción:** 🔴 **Bloqueante para Fase 3 (validador de escaleras y ascensores).** PDF con texto extraíble 📄.

---

## 1. Por qué importa para AxonBIM

R-031 define dimensiones y requisitos para:

- **Escaleras**: ancho mínimo, huella, contrahuella, descansos, pasamanos, altura libre.
- **Rampas**: pendientes, anchos, descansos, pasamanos.
- **Ascensores**: dimensiones mínimas de cabina, número requerido según altura y uso del edificio, velocidad mínima.
- **Montacargas**: requisitos específicos.

Aplica obligatoriamente a edificios ≥3 plantas o con uso público.

## 2. Constantes operativas

> Pendiente extracción.

### 2.1 Escaleras
*Pendiente extracción (huella, contrahuella, ancho, descansos, pasamanos).*

### 2.2 Rampas
*Pendiente extracción.*

### 2.3 Ascensores
*Pendiente extracción (dimensión mínima cabina, número por altura/uso).*

## 3. Para el agente

- Al modelar escaleras (`IfcStair`, `IfcStairFlight`), validar automáticamente contra §2.1.
- Al modelar rampas (`IfcRamp`), validar contra §2.2.
- Al modelar ascensores (`IfcTransportElement` tipo elevator), validar contra §2.3.
- Reportar incumplimientos en el panel de validación.

## 4. Referencias cruzadas

- R-007 (accesibilidad) — las rampas deben cumplir ambos.
- R-032 (incendios) — anchura de escaleras condicionada por rutas de escape.
