# Architecture Decision Records (ADRs)

Este directorio registra decisiones de arquitectura significativas del proyecto AxonBIM.

## ¿Qué es un ADR?

Un **Architecture Decision Record** es un documento corto que captura una decisión arquitectónica, su contexto y sus consecuencias. La idea original es de Michael Nygard (2011); aquí usamos una variante simplificada de [MADR](https://adr.github.io/madr/).

Los ADRs son **inmutables una vez aceptados**: no se editan, se superan con un ADR posterior.

## ¿Cuándo escribir un ADR?

Ver regla [`60-documentation.mdc`](../../../.cursor/rules/60-documentation.mdc), sección 6. En resumen: cuando la decisión toca varios módulos, cuando hay trade-off real entre alternativas o cuando es difícil revertirla (formatos, protocolos, motores).

## Proceso

1. Duplicar [`0000-template.md`](0000-template.md) con el siguiente número correlativo y un slug descriptivo: `0001-mi-decision.md`.
2. Rellenar el template. Marcar estado inicial como `Proposed`.
3. Abrir el PR correspondiente. Al merge, cambiar estado a `Accepted`.
4. Si más tarde la decisión se reemplaza: crear un ADR nuevo con estado `Accepted` y marcar el antiguo como `Superseded by ADR-NNNN`.

## Estados

- **Proposed** — propuesto, en discusión en un PR.
- **Accepted** — decisión vigente.
- **Deprecated** — ya no se aplica pero sigue documentada por contexto histórico.
- **Superseded by ADR-NNNN** — reemplazado por una decisión posterior.

## Índice

| Nº | Título | Estado | Fecha |
|----|--------|--------|-------|
| 0000 | Plantilla | Template | 2026-04-20 |

> Aún no hay ADRs registrados. Las decisiones de la Fase 1 (ver [`docs/phase-reports/phase-1-report.md`](../../phase-reports/phase-1-report.md) §5) pueden retroactivamente convertirse en ADRs a medida que el proyecto madure.
