# 1 — Streaming e Kinesis

## O problema do tempo real

Processar eventos em batch significa esperar: acumula-se o suficiente, dispara o job, consome o resultado. Para suporte ao cliente, alertas de produção ou detecção de fraude, esperar horas ou minutos é inaceitável. **Streaming** processa cada evento no instante em que ele chega, com latência de milissegundos.

O [Kinesis Data Streams](../glossario.md#kinesis-data-streams) é o serviço gerenciado da AWS para esse cenário: um fluxo contínuo de registros, retidos por um período configurável, consumíveis por múltiplos leitores independentes.

## A anatomia do stream

Um stream é dividido em [shards](../glossario.md#shard). Cada shard é uma unidade independente de capacidade e ordenação — 1 MB/s de entrada, 2 MB/s de saída, e uma sequência própria de registros ordenada por tempo de chegada.

O produtor escolhe em qual shard gravar através da [PartitionKey](../glossario.md#partition-key): o Kinesis calcula o hash MD5 da chave e mapeia para um shard. A consequência direta é:

```
mesma PartitionKey  →  mesmo hash  →  mesmo shard  →  mesma sequência
```

Todos os registros de `clienteId="cli-001"` caem no mesmo shard, em ordem de chegada. Dois tickets do mesmo cliente nunca chegam ao consumidor fora de ordem — a garantia é estrutural, não dependente de retry ou dedup.

## Analogia com Kafka

| Kafka | Kinesis |
|-------|---------|
| Tópico | Stream |
| Partição | [Shard](../glossario.md#shard) |
| Chave de mensagem | [PartitionKey](../glossario.md#partition-key) |
| Offset | [sequenceNumber](../glossario.md#sequence-number) |
| Período de retenção | Período de retenção (24h–365 dias) |
| Consumer group | Lambda com Event Source Mapping independente |

O [sequenceNumber](../glossario.md#sequence-number) identifica univocamente um registro dentro do shard. O consumidor pode retomar a leitura a partir de qualquer sequência — o stream não descarta registros ao serem lidos, apenas após a janela de retenção.

## Quando usar Kinesis, quando usar SQS

| Critério | Kinesis | SQS |
|----------|---------|-----|
| Ordenação por chave | ✅ Garantida (por shard) | ❌ Não (FIFO é por fila, sem particionamento) |
| Múltiplos consumidores independentes | ✅ Cada ESM lê o stream inteiro | ⚠️ SNS → múltiplas SQS |
| Reprocessamento | ✅ Reposicionamento por sequência | ❌ Mensagem some após consumo |
| Fan-out simples sem ordenação | ⚠️ Funciona, mas SQS é mais simples | ✅ Mais direto |
| Throughput muito alto e ordenado | ✅ Design central | ❌ Não é o ponto forte |

## No lab

O [U3-LAB01](../02-demos/u3-01.md) cria um stream de 4 shards e publica eventos de suporte usando `clienteId` como PartitionKey. O script mostra que `cli-001` sempre aterrissa no mesmo shard — a ordenação por cliente é a prova de que o hash da chave funciona.

---

📑 [Índice](../index.md) · [Demo: U3-LAB01](../02-demos/u3-01.md) · [Consumidores e at-least-once ➡️](2-consumidores-e-at-least-once.md)
