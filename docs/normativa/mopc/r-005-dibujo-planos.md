# R-005 — Dibujo de Planos en Proyectos de Edificaciones

> **Documento fuente:** [`sources/mopc/r-005-dibujo-planos-2017.pdf`](../sources/mopc/r-005-dibujo-planos-2017.pdf)
> **Título oficial:** Reglamento para Dibujo de Planos en Proyectos de Edificaciones
> **Autoridad emisora:** MOPC — Dirección General de Reglamentos y Sistemas (DGRS)
> **Publicación:** 2017 (2da edición)
> **Páginas:** 50
> **Vigencia:** Vigente. **Parcialmente sustituido** por CCRD Vol. I §3.7 — en caso de conflicto prevalece CCRD.
> **Estado de extracción:** 🔴 **Bloqueante para Fase 3.** PDF **escaneado** (🖼️) — requiere OCR antes de extracción.

---

## 1. Por qué importa para AxonBIM

R-005 es la norma histórica que define **cómo se deben presentar los planos** de edificaciones en República Dominicana:

- Formatos de lámina (A1, A2, A3, etc. y sus variantes locales).
- Escalas admisibles por tipo de plano.
- Capas obligatorias, colores, grosores de línea.
- Simbología estándar (arquitectónica, estructural, sanitaria, eléctrica).
- Cajetín: campos obligatorios, tamaño, posición.
- Rotulación: fuentes, alturas de texto, convenciones.
- Normas de acotación.

**Sin extracto operativo de R-005, AxonBIM no puede exportar planos conformes.**

## 2. Relación con CCRD Vol. I §3.7

El CCRD Vol. I §3.7 ("Documentos del Proyecto — Disposiciones sobre los Planos") también regula presentación de planos. Posibles escenarios:

| Situación | Acción |
|-----------|--------|
| CCRD cubre el tema con detalle suficiente | Usar CCRD, R-005 es referencia |
| CCRD solo menciona genéricamente; R-005 da el detalle | Usar R-005 |
| Conflicto directo entre ambos | **Prevalece CCRD** (más reciente, ley vigente) |
| Solo R-005 lo cubre | Usar R-005 |

Documentar cada caso al extraer.

## 3. Procedimiento de extracción (pendiente ejecutar)

1. **OCR del PDF** — el original es escaneado:
   ```bash
   # Instalar: sudo dnf install ocrmypdf tesseract-langpack-spa
   ocrmypdf docs/normativa/sources/mopc/r-005-dibujo-planos-2017.pdf \
            docs/normativa/sources/mopc/r-005-dibujo-planos-2017-ocr.pdf \
            -l spa --rotate-pages --deskew
   ```
2. **Extraer texto:** `pdftotext -layout r-005-...-ocr.pdf r-005.txt`.
3. **Identificar secciones operativas** y llenar las tablas de §5 abajo.

## 4. Tabla de contenidos esperada (por confirmar tras OCR)

_Pendiente OCR._ Esquema probable basado en reglamentos similares:

- Cap. 1: Disposiciones generales.
- Cap. 2: Formatos de lámina y escalas.
- Cap. 3: Cajetín y rotulación.
- Cap. 4: Simbología arquitectónica.
- Cap. 5: Simbología estructural.
- Cap. 6: Simbología sanitaria, eléctrica, mecánica.
- Cap. 7: Acotación.
- Cap. 8: Capas y grosores de línea.
- Anexos con ejemplos.

## 5. Constantes operativas

> **Todas las tablas de esta sección están pendientes de extracción.**
> Mientras no estén llenas, el código debe usar `# TODO(MOPC-R005): pendiente OCR y extracción §<sección>` y **no inventar valores**.

### 5.1 Formatos de lámina
*Pendiente extracción.*

### 5.2 Escalas por tipo de plano
*Pendiente extracción.*

### 5.3 Capas y grosores de línea
*Pendiente extracción.*

### 5.4 Simbología arquitectónica
*Pendiente extracción.*

### 5.5 Cajetín — campos obligatorios
*Pendiente extracción.*

### 5.6 Rotulación
*Pendiente extracción.*

### 5.7 Acotación
*Pendiente extracción.*

## 6. Para el agente

- **Si el usuario pide exportar un plano y este extracto sigue sin constantes reales:** notificar que se requiere el OCR de R-005 (y posiblemente el extracto de CCRD §3.7) antes de poder exportar planos conformes. No exportar con valores asumidos.
- **Al completar el OCR:** ejecutar el pipeline del §3, llenar §5 y actualizar el estado en [`README.md`](README.md) de 🔴 a ✅.
- **Al completar:** crear también `tests/normativa/test_r005_compliance.py` que valide un DXF generado contra las reglas extraídas.
