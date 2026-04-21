# R-021 — Tramitación de Planos / Reglamento General de Edificaciones

> **Documento fuente:** [`sources/mopc/r-021-tramitacion-planos-2006.pdf`](../sources/mopc/r-021-tramitacion-planos-2006.pdf)
> **Título oficial:** Requerimientos de Aplicación del Reglamento General de Edificaciones y Tramitación de Planos
> **Decreto:** 576-06
> **Autoridad emisora:** MOPC
> **Año:** 2006
> **Páginas:** 54
> **Vigencia:** Vigente (probable solapamiento con CCRD Vol. I §3.8 — Licencia).
> **Estado de extracción:** 🔴 **Bloqueante para Fase 4 (licencia/exportación paquete).** PDF con texto extraíble 📄.

---

## 1. Por qué importa para AxonBIM

R-021 establece los **requisitos documentales** para tramitar licencias de construcción:

- Qué planos son obligatorios según tipo y tamaño del proyecto.
- Qué memorias técnicas acompañan.
- Formato del paquete de entrega.
- Sellos profesionales requeridos (CODIA).
- Tiempos, tasas y procedimientos.

AxonBIM en Fase 4 debe generar un **paquete de licencia completo** que cumpla R-021 (+ CCRD §3.8).

## 2. Constantes operativas

> Pendiente extracción.

### 2.1 Planos obligatorios por tipo de proyecto
*Pendiente extracción.*

### 2.2 Memorias técnicas requeridas
*Pendiente extracción.*

### 2.3 Formato del paquete físico y digital
*Pendiente extracción.*

### 2.4 Sellos y firmas
*Pendiente extracción.*

## 3. Para el agente

- Implementar comando `project.export_license_package` que:
  1. Verifique que el proyecto cumple los criterios de §2.1 (set completo de planos).
  2. Genere las memorias según §2.2 a partir de los datos IFC del modelo.
  3. Compile el paquete en el formato del §2.3.
  4. Emita reporte de faltantes si algo no se puede generar automáticamente.

## 4. Referencias cruzadas

- CCRD Vol. I §3.7 (planos requeridos) y §3.8 (licencia).
- Reglas de colegios profesionales (CODIA) para sello.
