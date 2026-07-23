# Referências — Kinesis, streaming e IA

> Fontes O'Reilly Learning e documentação que sustentam esta unidade. Os capítulos são o ponto de partida; trate versões, preços e modelos como o que estava disponível na data de captura.

## Streaming (conceito em Kafka, laboratório em Kinesis)

- **Kafka: The Definitive Guide, 2nd ed** — Gwen Shapira et al (O'Reilly), Cap. 1 (o log), Cap. 3 (partições e chaves), Cap. 4 (grupos de consumidores e semântica de entrega). Base conceitual dos vídeos U3V1–V3; use a [ponte Kafka → Kinesis](3-ponte-kafka-kinesis.md) para mapear no laboratório.
- **Designing Event-Driven Systems** — Ben Stopford (O'Reilly), Cap. 4. Log persistente e reprocessamento.
- **AWS Kinesis Data Streams** — documentação oficial: *shards*, `PartitionKey`, *records* e *Event Source Mapping* para Lambda (o que os laboratórios usam de fato).

## Programação reativa (apoio, ponte com o curso irmão)

- **Reactive Design Patterns** — Roland Kuhn et al (Manning), Cap. 1. Contrapressão e fluxos assíncronos — o conceito é transferível para `asyncio`/consumo reativo.

## IA aplicada a eventos

- **AI as a Service** — Peter Elger, Eóin Shanaghy (Manning), Cap. 1 (casos de uso) e Cap. 6 (pipeline dos laboratórios). Base de U3V5/V6 e do U3-LAB03.
- **Generative AI on AWS** — Chris Fregly et al (O'Reilly), Cap. 11. Padrões de custo e implantação de modelos generativos.

## Do conceito ao código

| Conceito | Onde ver no código |
|----------|--------------------|
| Produtor Kinesis, PartitionKey, shards | `lab-u3-01/src/`, `template.yaml` |
| Consumidores via ESM, at-least-once, bisect | `lab-u3-02/src/`, `template.yaml` |
| Classificação LLM + cache DynamoDB | `lab-u3-03/src/classificador.py`, `suporte.py` |

---

⬅️ [Anterior: Classificação com cache DynamoDB](9-classificacao-cache-dynamodb.md) · 📑 [Índice](../../index.md) · [Próximo: Demo U3-LAB01](../../02-demos/u3-01.md) ➡️
