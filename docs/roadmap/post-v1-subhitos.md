# Más allá de v1.0 — Sub-hitos exploratorios

**Referencia:** [`ROADMAP.md`](../../ROADMAP.md) §“Más allá de v1.0”.

Estos ítems **no** tienen criterio de salida de producto ni fechas; sirven para convertir ideas en trabajo futuro sin mezclarlas con el compromiso de Fase 4.

## Mapeo con el ROADMAP (ideas → sub-hito)

| Idea en ROADMAP | Sub-hito |
|-----------------|----------|
| Colaboración en tiempo real (CRDT / IFC) | SH-PV1-01 |
| Integración motores render externos | SH-PV1-02 |
| Plugin system normativas otros países | SH-PV1-03 |
| Mobile companion obra | SH-PV1-04 |
| IA asistente clasificación IFC | SH-PV1-05 |

## Sub-hitos exploratorios (mismo esquema qué / cómo / por qué)

---

### SH-PV1-01 — Colaboración en tiempo real (CRDT / modelo IFC)

- **Estado:** Abierto
- **Qué:** Sincronización multiusuario sobre cambios IFC o capa intermedia.
- **Cómo:** Investigación; posible ADR si se elige stack.
- **Por qué:** Diferenciación a largo plazo; alto riesgo técnico y legal (datos, conflictos).
- **Hecho cuando:** Spike y decisión go/no-go documentados.
- **Evidencia / enlaces:** —

---

### SH-PV1-02 — Integración con motores de render externo

- **Estado:** Abierto
- **Qué:** Export fiel a Blender/Cycles u otro para presentación.
- **Cómo:** Formatos de intercambio (glTF, OBJ, USD según licencias).
- **Por qué:** Marketing y diseño; fuera del núcleo BIM de entrega MIVED.
- **Hecho cuando:** Demo puntual; no bloquea v1.
- **Evidencia / enlaces:** —

---

### SH-PV1-03 — Plugins de normativa por país

- **Estado:** Abierto
- **Qué:** API de reglas 2D/checagem plugables sin fork del core.
- **Cómo:** Diseño de extensiones y contratos; respeto a copyright normativo.
- **Por qué:** Escalabilidad internacional; requiere arquitectura limpia de “motor norma”.
- **Hecho cuando:** ADR de plugin system o prototipo mínimo.
- **Evidencia / enlaces:** —

---

### SH-PV1-04 — Companion móvil para obra

- **Estado:** Abierto
- **Qué:** Lectura de modelo y anotaciones en campo.
- **Cómo:** Subproyecto separado; sincronización fuera de alcance inicial.
- **Por qué:** Valor de producto distinto al desktop Linux principal.
- **Hecho cuando:** Investigación de mercado + viabilidad técnica.
- **Evidencia / enlaces:** —

---

### SH-PV1-05 — IA asistida (clasificación / etiquetado IFC)

- **Estado:** Abierto
- **Qué:** Sugerencias de tipo o propiedades con revisión humana obligatoria.
- **Cómo:** Política de datos, licencias de modelo, privacidad.
- **Por qué:** Riesgo de calidad y cumplimiento; no debe automatizar decisiones normativas sin auditoría.
- **Hecho cuando:** Política de uso y opt-in claros.
- **Evidencia / enlaces:** `70-copyright-legal.mdc` (contenido generado).
