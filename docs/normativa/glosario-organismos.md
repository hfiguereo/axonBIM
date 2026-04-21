# Glosario de organismos normativos — República Dominicana

Referencia rápida de quién emite qué en el ecosistema regulatorio de la construcción dominicana.

---

## Ministerios y organismos del Estado

### MIVED — Ministerio de la Vivienda, Hábitat y Edificaciones
- **Creado por:** Ley 160-21.
- **Rol:** Órgano rector en materia de vivienda y construcción de edificaciones.
- **Publica:** Código de Construcción de la República Dominicana (CCRD).
- **Anteriormente:** Las funciones se distribuían entre INVI, MOPC y otras entidades.
- **Sitio:** [mived.gob.do](https://mived.gob.do)

### MOPC — Ministerio de Obras Públicas y Comunicaciones
- **Rol:** Obras viales, puentes, infraestructura pública. Históricamente publicaba reglamentos técnicos para edificaciones (R-001 sismo, R-027 hormigón, etc.) hoy refundidos en el CCRD.
- **Vigencia de sus normas históricas:** Algunas siguen aplicando como complementarias del CCRD.
- **Publica:** Especificaciones técnicas para obras viales, manuales de diseño geométrico, etc.

### MEPyD — Ministerio de Economía, Planificación y Desarrollo
- **Rol:** Planificación territorial, ordenamiento urbano. Miembro de CONARTED.

### MIMARENA — Ministerio de Medio Ambiente y Recursos Naturales
- **Rol:** Permisos ambientales, evaluación de impacto. Miembro de CONARTED.

### MEM — Ministerio de Energía y Minas
- **Rol:** Normativas energéticas. Miembro de CONARTED.

### MINERD — Ministerio de Educación
- **Rol:** Normativas para edificaciones escolares. Miembro de CONARTED.

### INAPA — Instituto Nacional de Aguas Potables y Alcantarillados
- **Rol:** Normativas para instalaciones sanitarias y suministro de agua.

### SIE — Superintendencia de Electricidad
- **Rol:** Normativas para instalaciones eléctricas.

### SGN — Servicio Geológico Nacional
- **Rol:** Mapas geológicos, datos de subsuelo.

### ONESVIE — Oficina Nacional de Evaluación Sísmica y Vulnerabilidad
- **Rol:** Mapas sísmicos, evaluación de vulnerabilidad estructural.

---

## Consejos y comités

### CONARTED — Consejo Nacional de Regulación Técnica para las Edificaciones
- **Rol:** Coordina la elaboración y actualización del CCRD. Integra los ministerios listados arriba más gremios (CODIA, ACOPROVI, etc.).

---

## Gremios profesionales

### CODIA — Colegio Dominicano de Ingenieros, Arquitectos y Agrimensores
- **Rol:** Gremio profesional. **Sello obligatorio** en planos para tramitación oficial. Define ética profesional, certifica títulos.

### ACOPROVI — Asociación Dominicana de Constructores y Promotores de Viviendas
- **Rol:** Gremio empresarial.

### APROCOVICI — Asociación de Promotores y Constructores de Viviendas del Cibao
- **Rol:** Gremio regional.

### CADOCON — Cámara Dominicana de la Construcción
- **Rol:** Gremio empresarial.

### COPYMECON — Confederación de MIPYMES de la Construcción
- **Rol:** Gremio MIPYME.

### SODOSÍSMICA — Sociedad Dominicana de Sismología e Ingeniería
- **Rol:** Asociación científica. Aporte técnico clave al CCRD Título 2 (cargas sísmicas).

### SINEDOM — Sociedad de Ingenieros Estructuralistas Dominicanos
- **Rol:** Asociación profesional especializada en estructuras.

---

## Calidad y certificación

### INDOCAL — Instituto Dominicano para la Calidad
- **Rol:** Publica normas técnicas dominicanas (**NORDOM**). Equivalente local a ISO/IEC.

---

## Universidades con aporte técnico al CCRD

- **UASD** — Universidad Autónoma de Santo Domingo
- **UNIBE** — Universidad Iberoamericana
- **INTEC** — Instituto Tecnológico de Santo Domingo
- **PUCMM** — Pontificia Universidad Católica Madre y Maestra
- **UNIANDES** (Colombia) — Universidad de los Andes (asistencia técnica internacional)

---

## Para AxonBIM — relevancia operativa

| Organismo | ¿Necesario para v1.0? | Cuándo |
|-----------|----------------------|--------|
| MIVED | **Sí** | Fase 3 (planos), Fase 4 (licencias) |
| MOPC | Probable | Fase 3 si se usan normas históricas; Post-v1 para obras viales |
| INAPA | Post-v1 | Cuando se implementen instalaciones sanitarias |
| SIE | Post-v1 | Cuando se implementen instalaciones eléctricas |
| CODIA | Indirecto | El cajetín exige campo para sello CODIA |
| ONESVIE | Post-v1 | Cuando se implemente análisis sísmico |
| INDOCAL | Caso por caso | Si una NORDOM aplica a un módulo específico |
