# Fases 3 y 4 — Inventario de pendientes (estado al cierre documental de Fase 2)

**Fecha:** 2026-05-07 · **Audiencia:** autor del proyecto, arquitectos y colaboradores técnicos.

Este documento **no** declara el cierre de las fases 3 ni 4. Resume, en lenguaje claro, lo que el [`ROADMAP.md`](../../ROADMAP.md) sigue marcando como abierto y por qué sigue siendo trabajo de producto mayor (semanas o meses), no un ajuste de una tarde.

---

## 1. Resumen ejecutivo

- **Fase 3 (MIVED / motor 2D normado):** hoy hay proyección 2D operativa y export DXF de muros; **falta** la capa de **presentación reglamentaria** (simbología CCRD, cajetín, secciones, PDF, checklist MIVED de entrega).
- **Fase 4 (distribución y colaboración):** hoy el desarrollador corre Godot + `uv run`; **falta** el **empaquetado para usuario final**, estados **ISO 19650** en código con trazabilidad append-only, sitio y material de difusión, y **v1.0**.

---

## 2. Fase 3 — Qué falta (según ROADMAP)

| Pendiente | Qué implica en la práctica |
|-----------|----------------------------|
| Simbología y grosores **CCRD Vol. I** estrictos | Reglas de dibujo técnico dominicano aplicadas al vector 2D (no solo “líneas de muro”). |
| **Simbología técnica** completa | Sombras, arcos de apertura, convenciones de ventana/puerta, etc., alineadas a norma. |
| **Secciones**, **PDF**, checklist MIVED completo | Flujos de entrega que hoy no existen como producto cerrado. |
| **Cajetín y rotulación** MIVED | Plantillas de plano con metadatos de proyecto y revisión. |

**Criterio de salida del ROADMAP:** planta arquitectónica residencial exportable “lista para presentación oficial” bajo MIVED. Eso **no** se alcanza solo con ortográficos y DXF de muros.

---

## 3. Fase 4 — Qué falta (según ROADMAP)

| Pendiente | Qué implica en la práctica |
|-----------|----------------------------|
| **ISO 19650** en runtime | `project.set_state` y contenedores inmutables según `docs/architecture/iso-19650.md`, con log/SQLite append-only. |
| **Python congelado** | PyInstaller o Conda-pack con IfcOpenShell + dependencias nativas resueltas (extensiones `.so`). |
| **Flatpak** (y opcional **AppImage**) | Manifiesto, launcher, permisos de sandbox, pipeline de release. |
| **Sitio web**, docs de usuario ampliadas, **vídeos** | Capa de descubrimiento y adopción fuera del repositorio Git. |
| **Lanzamiento v1.0** | Tag y comunicación cuando los anteriores estén en orden. |

**Criterio de salida del ROADMAP:** arquitecto sin terminal descarga un paquete, modela y exporta planos MIVED. Hoy el camino canónico sigue siendo **desde fuente** (`README.md`, `./start`).

---

## 4. Relación con otros documentos

- Estrategia de empaquetado (esbozo): [`docs/packaging/flatpak-pyinstaller.md`](../packaging/flatpak-pyinstaller.md).
- Contrato RPC ya prevé errores de estado ISO: [`docs/architecture/jsonrpc-protocol.md`](../architecture/jsonrpc-protocol.md).
- Extracto operativo CCRD (paráfrasis): [`docs/normativa/mived/ccrd-vol-i.md`](../normativa/mived/ccrd-vol-i.md).

---

## 5. Próximo paso recomendado

Elegir **un** corte vertical por trimestre (por ejemplo: “solo cajetín + PNG/PDF básico” o “solo Flatpak sin ISO 19650”) en lugar de intentar cerrar toda la Fase 3 o 4 de un solo golpe. Cada corte debería actualizar el ROADMAP y, si cierra un hito mayor, el [`CHANGELOG.md`](../../CHANGELOG.md).
