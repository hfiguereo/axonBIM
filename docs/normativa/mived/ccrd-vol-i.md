# CCRD Vol. I — Extracto operativo para AxonBIM

> **Documento fuente:** [`sources/mived/ccrd-vol-i-2025.pdf`](../sources/mived/ccrd-vol-i-2025.pdf)
> **Título oficial:** Código de Construcción de la República Dominicana — Volumen I
> **Autoridad emisora:** MIVED + CONARTED + ADED
> **Año:** 2025
> **Páginas:** 689
> **Vigencia:** Vigente desde su publicación (Agosto 2025).
> **Estado de extracción:** 🟡 Esqueleto + plan. Secciones operativas pendientes de redactar.

---

## 1. Identificación legal

- **Base legal:** Ley 160-21 (creación del MIVED) y su reglamento de aplicación.
- **Órgano coordinador:** CONARTED (Consejo Nacional de Regulación Técnica para las Edificaciones).
- **Editor técnico:** ADED (Agremiación Dominicana de Empresas de Diseño).
- **Aplicación:** Obligatoria para toda edificación dentro del territorio nacional dominicano.

## 2. Tabla de contenidos (estructura del Vol. I)

| Título | Capítulos | Páginas | Aplicabilidad a AxonBIM |
|--------|-----------|---------|--------------------------|
| **Guía introductoria** | §1–§14 | 13–29 | Contextual; no genera código |
| **Título 1.** Consideraciones generales | 1.1–1.5 (Objetivo, Volúmenes, Sanciones, Definiciones, Documentos del Proyecto Estructural) | 33–55 | 🟢 Definiciones útiles para validador IFC |
| **Título 2.** Cargas mínimas para análisis y diseño estructural | 2.1–2.11 (Sismo principalmente) | 56–112 | 🔵 Post-v1.0 (análisis estructural) |
| **Título 3.** Consideraciones generales — exigencias técnicas y administrativas | 3.1–3.18 | 113–230 | 🔴 **Bloqueante para Fase 3 (planos) y Fase 4 (licencia)** |
| **Título 3.1.** Reglamento para supervisión e inspección general de obras | I–VI (Arts. 1–134) | 232–291 | 🟢 Informativo; potencial para módulo de supervisión post-v1 |
| **Título 4.** Suelos y fundaciones | 4.1–4.8 | 293–428 | 🔵 Post-v1.0 |
| **Título 5.** Reglamento para diseño y construcción de estructuras en hormigón armado | 5.1–5.76 + Anexos 1–7 | 429–688 | 🔵 Post-v1.0 |

Leyenda: 🔴 Bloqueante para fase activa · 🟡 Importante · 🟢 Útil · 🔵 Futuro post-v1.0

## 3. Mapa de aplicación a AxonBIM

### 3.1 Para Fase 3 (Planos 2D) — PRIORIDAD ALTA

Secciones del Título 3 que AxonBIM **debe** soportar al exportar planos:

| Sección | Contenido | Página | Estado de extracción |
|---------|-----------|--------|----------------------|
| **3.7.1** Planos requeridos | Lista de tipos de plano obligatorios por tipo de proyecto | 154 | 🔴 TODO(MIVED): extraer matriz tipo-de-proyecto × planos-exigidos |
| **3.7.2** Presentación de los planos | Formato, escala, cajetín, rotulación, sello CODIA | 156 | 🔴 TODO(MIVED): extraer especificaciones de cajetín y campos obligatorios |
| **3.7.3** Planos del diseño arquitectónico | Plantas, alzados, secciones, detalles. Simbología. | 158 | 🔴 TODO(MIVED): extraer simbología, grosores, capas |
| **3.7.4** Proyectos con calles interiores | Requisitos especiales | 160 | 🟡 TODO(MIVED): extraer si aplica |
| **3.7.16–3.7.17** Planos y memorias estructurales | Requisitos | 164–165 | 🟢 TODO(MIVED): extraer (validación cruzada) |
| **3.7.20** Planos de instalaciones sanitarias | Simbología, requisitos | 168 | 🔵 Post-v1.0 |
| **3.7.22** Planos del sistema de GLP | Requisitos | 169 | 🔵 Post-v1.0 |
| **3.7.23** Planos de instalaciones eléctricas | Simbología | 170 | 🔵 Post-v1.0 |
| **3.7.38–3.7.43** Mecánicas, ventilación, climatización | Requisitos | 172–173 | 🔵 Post-v1.0 |

### 3.2 Para Fase 4 (Licencia / Empaquetado de proyecto)

| Sección | Contenido | Página | Estado |
|---------|-----------|--------|--------|
| **3.8.4** Requisitos generales para obtener la licencia | Documentación requerida | 176 | 🟡 TODO(MIVED) |
| **3.8.7** Requerimientos adicionales | Casos especiales | 177 | 🟡 TODO(MIVED) |
| **3.8.8** Proyectos con características especiales | — | 178 | 🟡 TODO(MIVED) |
| **3.9.1** Permiso de inicio de obra | — | 181 | 🟡 TODO(MIVED) |

### 3.3 Definiciones útiles desde Fase 2

| Sección | Contenido | Página | Estado |
|---------|-----------|--------|--------|
| **1.4** Definiciones | Glosario oficial CCRD | 35 | 🟡 TODO(MIVED): extraer términos referenciados por IfcPropertySet personalizado |

### 3.4 Para post-v1.0 (referencia, no implementar aún)

- **Título 2** completo: cargas sísmicas, demanda sísmica, métodos de análisis.
- **Título 4**: suelos, fundaciones superficiales y profundas.
- **Título 5**: hormigón armado (vigas, columnas, losas, muros, zapatas).

## 4. Constantes operativas extraídas

> Esta sección se llenará a medida que se extraigan valores específicos del PDF. Mientras una constante no esté aquí, **el código debe usar `# TODO(MIVED-CCRD): pendiente extracción §<sección>`**.

### 4.1 Capas DXF para planos arquitectónicos

**Estado:** pendiente extracción literal de §3.7.3. **Convención de producto:** tabla interna y código en [`draw-delivery-layers.md`](../../architecture/draw-delivery-layers.md) + [`layer_ids.py`](../../../src/axonbim/drawing/layer_ids.py) (`DXF_ARCH_LAYER_SPECS`). Sustituir o alinear nombres cuando el extracto normativo esté redactado.

### 4.2 Grosores de línea
*Pendiente extracción de §3.7.2.*

### 4.3 Simbología de elementos arquitectónicos
*Pendiente extracción de §3.7.3.*

### 4.4 Cajetín y rotulación
*Pendiente extracción de §3.7.2.*

### 4.5 Formatos y escalas estándar
*Pendiente extracción de §3.7.2.*

## 5. Referencias cruzadas con otras normas

- El CCRD Título 2 sustituye al **R-001** (Reglamento sísmico MOPC, 2011) — pero R-001 puede seguir siendo referencia útil.
- El CCRD Título 5 toma elementos del **ACI 318** (referencia internacional para hormigón armado).
- Las instalaciones sanitarias se rigen además por normativas **INAPA** complementarias.
- Las instalaciones eléctricas referencian **NEC** (National Electrical Code) y normas **SIE**.

## 6. Plan de extracción

Orden recomendado de trabajo (cuando llegue Fase 3):

1. **§3.7.2 Presentación de los planos** → desbloquea formato general, escalas, cajetín.
2. **§3.7.3 Planos arquitectónicos** → desbloquea simbología, capas, grosores.
3. **§3.7.1 Planos requeridos** → desbloquea validador "¿está completo el set de planos?".
4. **§1.4 Definiciones** → desbloquea Pset_AxonBIM_CCRD para anotar entidades IFC.
5. **§3.8.4 Licencia** → desbloquea exportación de paquete de licencia.

## 7. Para el agente

- Si el usuario solicita generar código que dependa de una constante de §4 y esa constante aún figura como "Pendiente extracción", **detente y notifica**. No improvises valores.
- Las páginas referenciadas están en el PDF; si necesitas verificar literalmente algo específico, pídelo al usuario en lugar de inventar.
- Cuando se extraiga una sección, actualiza simultáneamente:
  1. La tabla de §3 (cambiar 🔴/🟡 a ✅).
  2. El bloque correspondiente en §4 con los valores reales.
  3. El test de validación en `tests/normativa/test_ccrd_vol_i.py` (cuando exista).
