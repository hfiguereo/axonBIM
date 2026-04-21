# R-007 — Proyectar Sin Barreras Arquitectónicas

> **Documento fuente:** [`sources/mopc/r-007-barreras-arquitectonicas-1991.pdf`](../sources/mopc/r-007-barreras-arquitectonicas-1991.pdf)
> **Título oficial:** Reglamento para Proyectar Sin Barreras Arquitectónicas
> **Decreto:** 284-91
> **Autoridad emisora:** MOPC
> **Año:** 1991
> **Páginas:** 58
> **Vigencia:** Vigente. Se anunció su integración futura al **CCRD Vol. V Título 6**, pero hasta tanto R-007 aplica.
> **Estado de extracción:** 🔴 **Bloqueante para Fase 3 (validación accesibilidad).** PDF con texto extraíble 📄.

---

## 1. Por qué importa para AxonBIM

R-007 define las dimensiones mínimas y requisitos para garantizar la accesibilidad universal:

- Anchos mínimos de puertas, pasillos, rampas.
- Pendiente máxima de rampas.
- Dimensiones mínimas de baños accesibles.
- Alturas de mostradores, interruptores, señales.
- Superficies antideslizantes.
- Áreas de giro para sillas de ruedas.

AxonBIM debe **validar automáticamente** estos parámetros al modelar viviendas y edificios públicos, y alertar al usuario cuando un elemento no cumpla.

## 2. Tabla de contenidos (por extraer)

*Pendiente extracción con `pdftotext -layout`. Este PDF sí es extraíble.*

## 3. Constantes operativas

> Todas pendientes de extracción. Mientras, usar `# TODO(MOPC-R007): pendiente §<sección>`.

### 3.1 Anchos mínimos
*Pendiente extracción.*

### 3.2 Rampas (pendiente, longitud, descansos)
*Pendiente extracción.*

### 3.3 Baños accesibles (dimensiones mínimas, giro, barras)
*Pendiente extracción.*

### 3.4 Alturas y alcances
*Pendiente extracción.*

### 3.5 Señalización accesible
*Pendiente extracción.*

## 4. Para el agente

- Al validar un proyecto, si se detecta un elemento menor al mínimo R-007, marcar como **warning** (no error): el usuario puede elegir ignorar para proyectos no públicos, pero debe ser explícito.
- Al exportar el paquete de licencia (Fase 4), incluir reporte de cumplimiento R-007 como adjunto obligatorio.

## 5. Referencias cruzadas

- Ley 5-13 (Derechos Personas con Discapacidad RD) — refuerza R-007.
- NORDOM 748 (INDOCAL) — accesibilidad, si aplica.
- Futuro CCRD Vol. V Título 6.
