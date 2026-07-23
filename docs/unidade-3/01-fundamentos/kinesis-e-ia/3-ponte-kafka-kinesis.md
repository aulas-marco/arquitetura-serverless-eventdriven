# Ponte: de Kafka para Kinesis

> **Pré-requisito:** [Roteamento por PartitionKey](2-particao-por-chave.md) · **Contexto:** os vídeos conceituais U3V1–V3 ensinam Kafka; os laboratórios desta disciplina usam AWS Kinesis.

Os teleprompters conceituais desta unidade ensinam **Apache Kafka** — o log persistente, partições, grupos de consumidores. Os laboratórios, porém, rodam em **AWS Kinesis Data Streams**, o equivalente serverless-nativo na AWS. O conceito é o mesmo; muda o vocabulário e a forma de operar. Esta página faz a tradução explícita para você reconhecer um no outro.

## 1. Tabela de equivalência

| Kafka (conceito) | Kinesis (laboratório) | Observação |
|------------------|------------------------|------------|
| Tópico | *Stream* | O canal nomeado de eventos |
| Partição | *Shard* | Unidade de paralelismo e ordenação |
| Chave da mensagem | `PartitionKey` | Decide o shard/partição por *hash* |
| Offset | `SequenceNumber` | Posição do registro dentro do shard |
| `producer.produce()` + `flush()` | `put_records` (lote) | Publicação |
| Consumer group | Um Lambda *Event Source Mapping* (ESM) | Cada ESM lê o *stream* inteiro |
| Rebalanceamento entre instâncias | Atribuição de shards pelo ESM + `ParallelizationFactor` | Gerenciado pela AWS |
| Commit manual de offset | *(não existe)* — o ESM avança o iterador por shard | O análogo de "reprocessar" é o retry |
| At-least-once via retry | `BisectBatchOnFunctionError` + retry | Isola o registro venenoso |
| Consumer lag | Métrica `IteratorAge` (CloudWatch) | Atraso do consumidor |

## 2. Onde a analogia quebra

- **Rebalanceamento ao vivo (1→2→3 instâncias)** é uma demo clássica no Kafka. O ESM do Kinesis **não** expõe isso da mesma forma — a atribuição de shards a invocações é automática. Os laboratórios modelam "dois consumidores independentes" (dois Lambdas) como o análogo de dois *consumer groups* distintos, e usam o `ParallelizationFactor` como eixo de paralelismo.
- **Retenção e replay** existem nos dois (o evento não some ao ser lido), mas a configuração e os limites diferem.

## 3. Por que Kinesis nesta disciplina

Kinesis é serverless-nativo na AWS: sem *cluster* para operar, integra direto com Lambda via ESM, e roda em LocalStack (ver [Setup local](../../00-comece-aqui/setup-local.md)). Alinha a Unidade 3 ao restante da disciplina (Lambda, SQS, DynamoDB). Quem aprendeu os conceitos em Kafka os reconhece aqui sem reaprender nada de fundamental.

---

⬅️ [Anterior: Roteamento por PartitionKey](2-particao-por-chave.md) · 📑 [Índice](../../index.md) · [Próximo: Consumidores via ESM](4-consumidores-esm.md) ➡️
