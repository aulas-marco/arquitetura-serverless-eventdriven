# Stream e shards

> **Pré-requisito:** [Como ler o código](../3-como-ler-o-codigo.md) · **Demo:** U3-LAB01 · **Lab:** `lab-u3-01`

## Objetivo

Ao terminar esta página você vai **descrever** a anatomia de um Kinesis Data Stream — *stream*, *shard*, *sequenceNumber* — e **explicar** por que o *shard* é a unidade de capacidade e de ordenação do Kinesis.

---

## Stream, shard e sequenceNumber

O Kinesis organiza registros em duas camadas de endereçamento: o **stream** (o canal) e o **shard** (a partição interna). Dentro de um *shard*, cada registro recebe um **sequenceNumber** que fixa sua posição.

```
  Stream: u3lab01-eventos-suporte
  ┌──────────────────────────────────────────────┐
  │  shard-0   seq→ [r0][r1][r2][r3] ...           │  1 MB/s in · 2 MB/s out
  │  shard-1   seq→ [r0][r1] ...                   │
  │  shard-2   seq→ [r0][r1][r2] ...               │
  │  shard-3   seq→ [r0] ...                        │
  └──────────────────────────────────────────────┘
         retenção 24h (relê enquanto não expira)
```

Cada **shard** é uma unidade independente de capacidade — até 1 MB/s de entrada e 2 MB/s de saída — e de ordenação: os registros de um *shard* chegam ao consumidor na ordem de escrita. Registros em *shards* diferentes não têm ordem relativa garantida.

O **sequenceNumber** é o identificador de posição dentro do *shard*. Cresce monotonicamente, mas é **opaco** — não é um inteiro contínuo como o *offset* do Kafka. Serve para ordenar e para reposicionar a leitura, nunca para contar.

| Conceito | Papel | Garantia |
|---|---|---|
| Stream | canal de eventos | nenhuma — distribui entre *shards* |
| Shard | *log* ordenado + unidade de capacidade | ordem estrita por `sequenceNumber` |
| sequenceNumber | posição no *shard* | crescente, opaco, imutável |

---

## No lab: 4 shards e retenção de 24h

O `template.yaml` do `lab-u3-01` cria o *stream* com 4 *shards* — número escolhido para que o roteamento por *hash* da chave seja observável (clientes diferentes tendem a cair em *shards* diferentes):

```yaml
# template.yaml — lab-u3-01
StreamEventos:
  Type: AWS::Kinesis::Stream
  Properties:
    Name: u3lab01-eventos-suporte
    ShardCount: 4
    RetentionPeriodHours: 24
```

A **retenção de 24h** é a diferença estrutural em relação ao SQS: o registro não desaparece quando é lido. Ele permanece no *shard* durante toda a janela, o que permite reprocessamento e múltiplos consumidores independentes (tema das páginas [4](4-consumidores-esm.md) e [5](5-parallelization-factor.md)).

---

## O que o produtor devolve

A resposta de `put_records` traz, por registro, o `ShardId` de destino e o `SequenceNumber` confirmado — a prova de onde cada registro aterrissou:

```python
# produtor.py — lab-u3-01
for evento, registro in zip(eventos, resposta["Records"]):
    if "ShardId" in registro:
        publicados.append({
            "clienteId": evento["clienteId"],
            "shardId": registro["ShardId"],
            "sequenceNumber": registro["SequenceNumber"],
        })
```

O `ShardId` não é decidido pelo código — é decisão do Kinesis, por *hash* da `PartitionKey`. A próxima página detalha esse roteamento.

---

⬅️ [Anterior: Como ler o código](../3-como-ler-o-codigo.md) · 📑 [Índice](../../index.md) · [Próximo: Roteamento por PartitionKey](2-particao-por-chave.md) ➡️
