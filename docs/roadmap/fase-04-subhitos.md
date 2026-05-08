# Fase 4 — Sub-hitos complementarios (ecosistema y publicación)

**Referencia:** [`ROADMAP.md`](../../ROADMAP.md) §Fase 4 · **Empaquetado (esbozo):** [`docs/packaging/flatpak-pyinstaller.md`](../packaging/flatpak-pyinstaller.md) · **ISO 19650 (estrategia):** [`docs/architecture/iso-19650.md`](../architecture/iso-19650.md).

**Criterio de salida (pendiente):** usuario final instala Flatpak (u otro empaquetado acordado), modela y exporta planos MIVED sin terminal ([`ROADMAP.md`](../../ROADMAP.md) §Fase 4).

## Sub-hitos ya cubiertos (ROADMAP: hito [x] en tronco)

---

### SH-F4-11 — Navegador de proyecto en Godot (árbol + propiedades básicas)

- **Estado:** Cerrado
- **Qué:** Exploración del modelo con árbol y panel de propiedades mínimo operativo.
- **Cómo:** UI Godot + datos de sesión expuestos vía RPC según implementación actual.
- **Por qué:** Base de **descubrimiento** del IFC antes de estados ISO 19650 y empaquetado.
- **Hecho cuando:** Flujo diario de desarrollo y demo usan el navegador sin bloqueos críticos.
- **Evidencia / enlaces:** ROADMAP Fase 4 primer hito [x], escena principal / Project Browser.

---

## Pendientes hacia distribución y v1.0

---

### SH-F4-01 — Estructura espacial IFC en navegador (visión de producto completa)

- **Estado:** Abierto
- **Qué:** Árbol y metadatos alineados a la **jerarquía espacial IFC** que v1 se compromete a soportar (no solo lista plana de muros ni un subconjunto accidental).
- **Cómo:** Iteración en Godot + handlers `ifc.*` / consultas de sesión; criterio escrito por el BDFL (qué `Ifc*` aparecen y cómo).
- **Por qué:** Publicación y colaboración requieren navegación **semántica** creíble, coherente con entrega MIVED.
- **Hecho cuando:** Documento de criterio + implementación que lo cumple en proyecto sintético de prueba.
- **Evidencia / enlaces:** ROADMAP nota “pendiente” bajo hito navegador; compare SH-F4-11.

---

### SH-F4-02 — Estados ISO 19650 en runtime

- **Estado:** Abierto
- **Qué:** Transiciones WIP / Shared / Published / Rejected / Archive con reglas de inmutabilidad; errores RPC ya esbozados en protocolo.
- **Cómo:** SQLite append-only para auditoría + handlers `project.set_state` (contrato existente en doc).
- **Por qué:** Sin estados, “entrega oficial” es solo un archivo suelto sin trazabilidad (punto ciego de colaboración).
- **Hecho cuando:** Flujo mínimo reproducible + tests de transición ilegal.
- **Evidencia / enlaces:** `jsonrpc-protocol.md`, `iso-19650.md`.

---

### SH-F4-03 — Congelar backend Python (PyInstaller o Conda-pack)

- **Estado:** Abierto
- **Qué:** Binario o árbol `onedir` con IfcOpenShell + ezdxf resolviendo extensiones.
- **Cómo:** Pipeline documentado en `flatpak-pyinstaller.md`; hooks si hace falta.
- **Por qué:** Usuario final no puede depender de `uv` ni de wheels en desarrollo.
- **Hecho cuando:** Artefacto generado en CI o script local reproducible; arranque RPC verificado.
- **Evidencia / enlaces:** `docs/packaging/`.

---

### SH-F4-04 — Flatpak aplicación completa

- **Estado:** Abierto
- **Qué:** Manifiesto que empaqueta Godot exportado + backend congelado + launcher.
- **Cómo:** YAML Flatpak, permisos de filesystem y red loopback acordados.
- **Por qué:** Criterio de salida ROADMAP (“descarga Flatpak… sin terminal”).
- **Hecho cuando:** Instalación en distro limpia abre app y completa demo Fase 1/2 sin pasos ocultos.
- **Evidencia / enlaces:** manifiesto bajo `packaging/` (cuando exista).

---

### SH-F4-05 — AppImage (alternativa portable)

- **Estado:** Abierto
- **Qué:** Paquete alternativo para quien no use Flatpak.
- **Cómo:** Script de empaquetado + prueba en distro objetivo.
- **Por qué:** Reduce fricción en entornos corporativos heterogéneos; opcional pero lista en ROADMAP.
- **Hecho cuando:** Release de prueba descargable y verificada.
- **Evidencia / enlaces:** —

---

### SH-F4-06 — Sitio web, manual de usuario y vídeos

- **Estado:** Abierto
- **Qué:** Punto de descarga, guía de instalación, 1–3 tutoriales en vídeo alineados al manual.
- **Cómo:** Repo o sitio estático; sin duplicar normativa con copyright problemático.
- **Por qué:** v1.0 es producto solo si es **encontrable** y **aprendible**.
- **Hecho cuando:** Checklist de contenido mínimo publicado y enlazado desde README.
- **Evidencia / enlaces:** `docs/manual-de-axonbim.md` como núcleo textual.

---

### SH-F4-07 — Hardening de seguridad y sandbox

- **Estado:** Abierto
- **Qué:** Revisión de permisos Flatpak, variables de entorno, rutas de proyecto; no exponer RPC al LAN sin decisión explícita.
- **Cómo:** Documento corto de amenazas + ajustes de `finish-args`.
- **Por qué:** Empaquetado introduce superficie de ataque nueva (filesystem, IPC).
- **Hecho cuando:** Lista de permisos justificada y revisada.
- **Evidencia / enlaces:** regla `14-seguridad-repositorio-y-despliegue.mdc`.

---

### SH-F4-08 — Release process v1.0

- **Estado:** Abierto
- **Qué:** Tag SemVer, notas de release, enlaces a reporte de fase y CHANGELOG consolidado.
- **Cómo:** `CONTRIBUTING.md` + plantilla de release; criterios de bloqueo (tests, empaquetado).
- **Por qué:** “Lanzamiento” sin proceso es punto ciego de reproducibilidad y soporte.
- **Hecho cuando:** `v1.0.0` publicado con binarios y fuente alineados.
- **Evidencia / enlaces:** `CHANGELOG.md`, `50-git-commits.mdc`.

---

### SH-F4-09 — Telemetría y diagnóstico opt-in (opcional)

- **Estado:** Abierto
- **Qué:** Política clara: sin telemetría por defecto o solo local/logs; si se añade, opt-in y documentación.
- **Cómo:** ADR si se activa recolección remota.
- **Por qué:** Evita sorpresas legales y de confianza en v1.
- **Hecho cuando:** Política escrita en README o manual.
- **Evidencia / enlaces:** —

---

### SH-F4-10 — Soporte post-instalación (FAQ empaquetado)

- **Estado:** Abierto
- **Qué:** Errores típicos Flatpak (GPU, permisos home, puerto RPC) con soluciones.
- **Cómo:** Sección en manual enlazada desde el sitio.
- **Por qué:** El criterio “sin terminal” requiige mensajes y guías cuando algo falla.
- **Hecho cuando:** FAQ cubre los 5 primeros tickets esperados.
- **Evidencia / enlaces:** —
