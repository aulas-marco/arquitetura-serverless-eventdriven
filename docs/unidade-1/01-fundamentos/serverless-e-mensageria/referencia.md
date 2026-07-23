# Referências — Serverless, eventos e mensageria

> Fontes O'Reilly Learning que sustentam os conceitos desta unidade. Os capítulos são o ponto de partida; trate versões, preços e limites como o que estava disponível na data de captura.

## Núcleo

- **Serverless Architectures on AWS, 2nd ed** — Peter Sbarski et al (Manning), Cap. 1 (modelo FaaS) e Cap. 4 (padrões dos laboratórios). A referência central de Lambda e do modelo de execução por invocação.
- **Designing Event-Driven Systems** — Ben Stopford (O'Reilly), Cap. 1. Evento como fato imutável, desacoplamento temporal, coreografia vs. orquestração.

## Apoio

- **Building Event-Driven Microservices** — Adam Bellemare (O'Reilly), Cap. 1 (fronteiras por evento) e Cap. 3 (idempotência e deduplicação).
- **Designing Data-Intensive Applications** — Martin Kleppmann (O'Reilly), Cap. 11. Entrega, ordenação e as garantias que uma fila realmente oferece.
- **Enterprise Integration Patterns** — Hohpe, Woolf (Pearson/AW), Cap. 1. O vocabulário de mensageria (canal, fila, tópico, *dead letter*) que ancora SNS/SQS/DLQ.

## Do conceito ao código

| Conceito | Onde ver no código |
|----------|--------------------|
| Ciclo de vida, cold start, runtimes, SnapStart | `lab-u1-01/` (fundamentos, runtimes, snapstart) |
| Fan-out SNS → SQS | `lab-u1-02/src/`, `template.yaml` |
| Idempotência (chave + DynamoDB TTL) | `lab-u1-03/src/comum.py`, `consumidor.py` |
| DLQ, falha parcial de lote, redrive | `lab-u1-04/src/`, `template.yaml`, `scripts/veneno-e-dlq.sh` |

## Nota sobre datedness

Conteúdo de curso fica no ar por anos. Números concretos (custo por invocação, cold start por runtime) envelhecem — os laboratórios trazem data e região de captura e o alvo `make medir` reproduz os valores atuais.

---

⬅️ [Anterior: DLQ e at-least-once](11-dlq-at-least-once.md) · 📑 [Índice](../../index.md) · [Próximo: Demo U1-LAB01](../../02-demos/u1-01.md) ➡️
