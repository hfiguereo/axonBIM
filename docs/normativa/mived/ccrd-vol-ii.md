# CCRD Vol. II — Extracto operativo para AxonBIM

> **Documento fuente:** [`sources/mived/ccrd-vol-ii-2025.pdf`](../sources/mived/ccrd-vol-ii-2025.pdf)
> **Título oficial:** Código de Construcción de la República Dominicana — Volumen II
> **Autoridad emisora:** MIVED + CONARTED + ADED
> **Año:** 2025
> **Páginas:** 465
> **Vigencia:** Vigente desde su publicación (Agosto 2025).
> **Estado de extracción:** 🟡 TOC extraído. Títulos de cálculo estructural — **relevancia post-v1.0 de AxonBIM**.

---

## 1. Identificación legal

- Mismo marco que Vol. I: Ley 160-21, CONARTED, ADED.
- Complementa al Vol. I cubriendo materiales estructurales adicionales.

## 2. Estructura del Vol. II

| Título | Contenido | Páginas aprox | Aplicabilidad a AxonBIM |
|--------|-----------|---------------|--------------------------|
| **Título 6** | Muros de Hormigón Armado de Ductilidad Limitada (MHADL) | 27–32 | 🔵 Post-v1.0 (análisis sísmico avanzado) |
| **Título 7** | Estructuras de Aluminio | 33–43 | 🔵 Post-v1.0 |
| **Título 8** | Mampostería (considera generales, diseño, refuerzo, muros armados, amarres, axial/flexión, cortante, flexión fuera de plano, aplastamiento, muros de contención, huecos) | 44–92 | 🔵 Post-v1.0 (útil para validar muros de bloque) |
| **Título 9** | Estructuras de Acero (generalidades, diseño, pórticos, miembros a tensión/compresión/flexión/cortante/fuerzas combinadas, conexiones, fabricación, compuestas acero-hormigón) | 93–208 | 🔵 Post-v1.0 |
| **Título 10** | Estructuras de Madera (definiciones, clasificación, tratamiento, criterios de diseño, propiedades mecánicas, esbeltez, diseño de elementos) | 209–420 | 🔵 Post-v1.0 |
| **Título 11** | Vidrios y Acristalamientos | 421–465 | 🟡 Potencialmente útil en Fase 3 para validación de aberturas |

Leyenda: 🔴 Bloqueante · 🟡 Importante · 🟢 Útil · 🔵 Futuro post-v1.0

## 3. Aplicación a AxonBIM

### 3.1 Relevancia inmediata (v1.0)

**Ninguna crítica.** Todo el Vol. II es cálculo estructural de materiales específicos. AxonBIM v1.0 es una herramienta de modelado arquitectónico + exportación BIM/planos; el cálculo estructural no está en alcance.

**Excepción parcial:** Título 11 (Vidrios) podría aportar restricciones para validar tamaños de acristalamiento en Fase 3 si se quiere avisar al usuario de incumplimientos.

### 3.2 Relevancia post-v1.0

Cuando AxonBIM añada módulos de cálculo estructural (roadmap post-v1.0), este Volumen será fuente principal junto con el Título 5 del Vol. I (hormigón armado).

Orden de prioridad sugerido para implementación:

1. **Título 8 (Mampostería)** — es el sistema constructivo más común en RD.
2. **Título 9 (Acero)** — edificaciones comerciales e industriales.
3. **Título 10 (Madera)** — segundarioen RD pero relevante para viviendas ligeras.
4. **Título 6 (MHADL)** — especializado, solo para proyectos con sismología específica.
5. **Título 7 (Aluminio)** — nicho (cerramientos, cubiertas ligeras).
6. **Título 11 (Vidrios)** — puede adelantarse a Fase 3 si se quiere validación de aberturas.

## 4. Constantes operativas

*No se extraen valores en esta fase.* Este documento queda como referencia disponible. Cuando se active un módulo de cálculo estructural, se creará un extracto detallado por título.

## 5. Para el agente

- **Si el usuario pide cálculo estructural en v1.0:** responde que no está en alcance y refiere al ROADMAP.
- **Si el usuario pide validación de mampostería/acero/madera:** recuerda que este Vol. II es la fuente autoritativa, pero su extracto operativo está pendiente. No improvises fórmulas.
- **Si el usuario pide validación de aberturas (vidrios):** Título 11 es la referencia. Extracto pendiente.
