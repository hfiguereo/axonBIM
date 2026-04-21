# Normativa — AxonBIM

Índice maestro de las normativas técnicas dominicanas que AxonBIM debe cumplir o asistir a cumplir.

> **Cómo leer este directorio:**
> - `sources/` — PDFs originales tal como se publican (no editar).
> - `<organismo>/` — extractos operativos en Markdown que AxonBIM consume al generar código.
> - Si una sección operativa no existe aún, **no improvises**: marca `# TODO(<organismo>-<doc>): pendiente §<sección>` y pide al autor.

---

## 1. Estado por organismo

| Organismo | Documentos | Fase(s) | Estado | Carpeta |
|-----------|------------|---------|--------|---------|
| **MIVED** (Min. Vivienda, Hábitat y Edificaciones) | CCRD Vol. I (2025, 689 pgs) + CCRD Vol. II (2025, 465 pgs) | Bloqueante v1.0 | 🟡 TOC extraído, constantes pendientes | [`mived/`](mived/) |
| **MOPC** (Min. Obras Públicas y Comunicaciones) | 23 reglamentos R-001…R-033 (edificación) | Bloqueante v1.0 parcial | 🟡 Inventariado, 6 extractos esqueleto | [`mopc/`](mopc/) |
| Otros (CONARTED, INDOCAL, INAPA, SIE, ONESVIE) | — | Post-v1.0 | No cargado | [`sources/otros/`](sources/otros/) |

Glosario de siglas: [`glosario-organismos.md`](glosario-organismos.md).

## 2. Documentos bloqueantes para cada fase

### Fase 3 (Planos 2D) — 🔴 CRÍTICO

| Doc | Contenido | Estado |
|-----|-----------|--------|
| CCRD Vol. I §3.7 | Presentación de planos, disposiciones generales | 🔴 Por extraer |
| MOPC R-005 | Dibujo de planos (simbología, cajetín, capas) | 🔴 Por extraer (PDF escaneado, requiere OCR) |
| MOPC R-007 | Accesibilidad (anchos, rampas, baños) | 🔴 Por extraer |
| MOPC R-016 | Espacios mínimos en vivienda | 🔴 Por extraer |
| MOPC R-031 | Circulación vertical (escaleras, ascensores) | 🔴 Por extraer |
| MOPC R-032 | Incendios (rutas de escape, compartimentación) | 🔴 Por extraer |

### Fase 4 (Licencia / Empaquetado) — 🔴 CRÍTICO

| Doc | Contenido | Estado |
|-----|-----------|--------|
| CCRD Vol. I §3.8 | Licencia de construcción, requisitos | 🔴 Por extraer |
| MOPC R-021 | Tramitación de planos, memorias | 🔴 Por extraer |
| MOPC R-004 | Supervisión e inspección | 🟢 Informativo |

### Post-v1.0 (Cálculo estructural) — 🔵 FUTURO

| Doc | Contenido | Estado |
|-----|-----------|--------|
| CCRD Vol. I T. 2, 4, 5 | Sismo, suelos, hormigón armado | Documentado |
| CCRD Vol. II T. 6-11 | MHADL, aluminio, mampostería, acero, madera, vidrios | Documentado |
| MOPC R-001, R-024, R-027, R-028, R-029, R-033 | Sustituidos por CCRD — referencia histórica | Descargados |

## 3. Cómo añadir una nueva normativa

1. Coloca el PDF en `sources/<organismo>/<codigo>-<nombre-canonico>-<año>.pdf`.
2. Añádelo al índice del organismo en `<organismo>/README.md`.
3. Crea el extracto operativo `<organismo>/<codigo>-<nombre>.md` siguiendo las plantillas existentes.
4. Si modifica el comportamiento del agente, actualiza [`.cursor/rules/30-bim-normativa.mdc`](../../.cursor/rules/30-bim-normativa.mdc).
5. Commit: `docs(normativa): añade <organismo> <código-o-nombre>`.

## 4. Convenciones de nomenclatura

- **Kebab-case ASCII** sin tildes, sin espacios, minúsculas.
- Código oficial primero cuando existe: `r-005-dibujo-planos-2017.pdf`, `ccrd-vol-i-2025.pdf`.
- Año al final cuando aplique.
- Una versión = un archivo. No sobrescribir ediciones anteriores.

## 5. Política de PDFs escaneados vs con texto

Al descargar, se marca el PDF con:
- 📄 **Texto extraíble** — usar `pdftotext -layout` directamente.
- 🖼️ **Escaneado** — aplicar OCR antes: `ocrmypdf <in>.pdf <out>-ocr.pdf -l spa --rotate-pages --deskew`.

Reglamentos escaneados identificados: R-003, R-005, R-009, R-010. Generar versiones `-ocr.pdf` cuando se vaya a extraer contenido de ellos.

## 6. Para el agente

- **Fuente autoritativa para código:** solo los archivos `.md` extractados. Los PDFs de `sources/` son **referencia humana**.
- **Jerarquía en caso de conflicto:** CCRD > MOPC R-XXX históricos > otras.
- **Si un dato no está extraído:** `# TODO(<organismo>-<doc>): pendiente §<sección>`. **Nunca improvisar valores.**
- **Al extraer una sección:** actualizar simultáneamente (a) la tabla de §1/§2 aquí, (b) el extracto del organismo, (c) el test de validación correspondiente.
