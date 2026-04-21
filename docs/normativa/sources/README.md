# Fuentes normativas originales

Esta carpeta contiene los PDFs oficiales tal como se publican. **Nunca editar estos archivos.**

---

## Estructura

```
sources/
├── mived/         # CCRD Vol. I y Vol. II (2025)
├── mopc/          # 23 reglamentos R-001…R-033 + catálogo DGRS
└── otros/         # Pendiente: CONARTED, INDOCAL, INAPA, SIE, ONESVIE, etc.
```

## Convenciones

- **Kebab-case ASCII** sin tildes, minúsculas.
- Código oficial primero si existe: `r-005-dibujo-planos-2017.pdf`.
- Año al final cuando aplique versionado.
- Una versión = un archivo. Conservar TODAS las versiones publicadas.

## Inventario actual

### MIVED
| Archivo | Páginas | Tamaño | Tipo | Publicado |
|---------|---------|--------|------|-----------|
| `mived/ccrd-vol-i-2025.pdf` | 689 | 25 MB | 📄 Con texto | Agosto 2025 |
| `mived/ccrd-vol-ii-2025.pdf` | 465 | 16 MB | 📄 Con texto | Agosto 2025 |

### MOPC
| Archivo | Páginas | Tamaño | Tipo |
|---------|---------|--------|------|
| `mopc/catalogo-publicaciones-dgrs.pdf` | 2 | 5.2 MB | 📄 Catálogo |
| `mopc/r-001-sismo-2011.pdf` | 65 | 2.7 MB | 📄 |
| `mopc/r-002-estacionamiento-1991.pdf` | 80 | 22 MB | 📄 (muy poco texto) |
| `mopc/r-003-electricas-parte-i-2017.pdf` | 79 | 12 MB | 🖼️ Escaneado |
| `mopc/r-004-supervision-inspeccion-2017.pdf` | 37 | 1.3 MB | 📄 |
| `mopc/r-005-dibujo-planos-2017.pdf` | 50 | 13 MB | 🖼️ Escaneado |
| `mopc/r-007-barreras-arquitectonicas-1991.pdf` | 58 | 9.6 MB | 📄 |
| `mopc/r-008-instalaciones-sanitarias-2010.pdf` | 102 | 5.4 MB | 📄 |
| `mopc/r-009-especificaciones-construccion-edificaciones.pdf` | 132 | 17 MB | 🖼️ Escaneado |
| `mopc/r-010-electricas-parte-ii-2017.pdf` | 94 | 15 MB | 🖼️ Escaneado |
| `mopc/r-016-espacios-minimos-vivienda.pdf` | 58 | 13 MB | 📄 |
| `mopc/r-021-tramitacion-planos-2006.pdf` | 54 | 1.3 MB | 📄 |
| `mopc/r-022-subestaciones-1998.pdf` | 56 | 4.8 MB | 📄 |
| `mopc/r-023-plantas-escolares-2006.pdf` | 54 | 1.2 MB | 📄 |
| `mopc/r-024-estudios-geotecnicos-2006.pdf` | 60 | 1.4 MB | 📄 |
| `mopc/r-025-plantas-emergencia-2006.pdf` | 40 | 1.4 MB | 📄 |
| `mopc/r-026-excavacion-vias-2007.pdf` | 27 | 1.1 MB | 📄 |
| `mopc/r-027-mamposteria-estructural-2007.pdf` | 80 | 2.1 MB | 📄 |
| `mopc/r-028-estructuras-acero-2007.pdf` | 94 | 1.9 MB | 📄 |
| `mopc/r-029-madera-estructural-2009.pdf` | 136 | 3.9 MB | 📄 |
| `mopc/r-030-glp-2010.pdf` | 57 | 1.9 MB | 📄 |
| `mopc/r-031-circulacion-vertical-2015.pdf` | 29 | 1.6 MB | 📄 |
| `mopc/r-032-incendios-2019.pdf` | 92 | 2.0 MB | 📄 |
| `mopc/r-033-hormigon-armado-2012.pdf` | 171 | 5.4 MB | 📄 |

**Totales:** 25 PDFs · ~185 MB · ~2 400 páginas.

## PDFs escaneados que requieren OCR

| Archivo | Relevancia | Comando OCR |
|---------|------------|-------------|
| `r-005-dibujo-planos-2017.pdf` | 🔴 **Bloqueante Fase 3** | `ocrmypdf r-005-dibujo-planos-2017.pdf r-005-dibujo-planos-2017-ocr.pdf -l spa --rotate-pages --deskew` |
| `r-003-electricas-parte-i-2017.pdf` | 🔵 Post-v1.0 | ídem |
| `r-009-especificaciones-construccion-edificaciones.pdf` | 🟡 | ídem |
| `r-010-electricas-parte-ii-2017.pdf` | 🔵 Post-v1.0 | ídem |

Requisitos: `sudo dnf install ocrmypdf tesseract-langpack-spa` (Fedora) o equivalente.

## Cómo añadir un PDF nuevo

```bash
mv ~/Descargas/norma.pdf docs/normativa/sources/<organismo>/<codigo>-<nombre>-<año>.pdf
pdfinfo docs/normativa/sources/<organismo>/<codigo>-<nombre>-<año>.pdf
# Actualizar tablas en este README y en <organismo>/README.md
# Crear extracto operativo en <organismo>/<codigo>-<nombre>.md
```

## Git LFS

Los PDFs ocupan ~185 MB en total — **requieren Git LFS obligatoriamente**. Ya está configurado en [`.gitattributes`](../../../.gitattributes) en la raíz del repo. Al inicializar el repo:

```bash
git lfs install
git add .gitattributes
git add docs/normativa/sources/
git commit -m "docs(normativa): carga inicial de fuentes oficiales"
```
