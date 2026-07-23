# Roteamento por PartitionKey e ordenação por shard

> **Pré-requisito:** [Stream e shards](1-stream-e-shards.md) · **Demo:** U3-LAB01 · **Script:** `publicar-e-rotear.sh`

O shard de destino de um registro não é escolhido pelo código — é o Kinesis que decide, por *hash* da `PartitionKey`. Esta página mostra como a mesma chave sempre cai no mesmo shard (a única garantia de ordenação do Kinesis) e o que acontece com chaves diferentes.

## 1. Hash da chave → shard

O Kinesis calcula `MD5(PartitionKey)` e mapeia o resultado para a faixa de *hash key* de um dos shards. Determinístico: mesma chave → mesmo shard.

```
  put_records
  ┌──────────────────────────────┐
  │ PartitionKey = "cli-001"      │──▶ MD5 → faixa do shard 3
  │ PartitionKey = "cli-002"      │──▶ MD5 → faixa do shard 2
  │ PartitionKey = "cli-003"      │──▶ MD5 → faixa do shard 2
  └──────────────────────────────┘
   stream u3lab01-eventos-suporte (4 shards)
   [shard-0] [shard-1] [shard-2] [shard-3]
                          ▲          ▲
              cli-002 e cli-003      cli-001 (sempre aqui, em ordem)
```

## 2. No código — `clienteId` é a chave

O produtor (`lab-u3-01/src/suporte.py`) monta cada registro com o `clienteId` como `PartitionKey` e o evento serializado em *bytes*:

```python
def montar_registro(evento):
    return {
        "PartitionKey": evento["clienteId"],
        "Data": json.dumps(evento).encode("utf-8"),
    }
```

O handler chama `kinesis.put_records(StreamName=STREAM, Records=[...])` e, na resposta, cada registro traz o `ShardId` e o `SequenceNumber` de destino — a evidência de qual shard recebeu o quê.

## 3. Ordenação: por shard, nunca global

Dentro de um shard, os registros ficam ordenados pelo `SequenceNumber` (crescente). Entre shards diferentes, **não há ordem** — por isso os eventos de um mesmo cliente precisam compartilhar a chave, para caírem no mesmo shard e manterem a ordem por cliente.

O `publicar-e-rotear.sh` publica 7 eventos (cli-001 ×3, cli-002 ×2, cli-003 ×2) e prova, pela resposta do `put_records`, que cada `clienteId` caiu sempre no mesmo shard e que clientes diferentes se distribuíram.

## 4. Pegadinha — chave ausente

Sem `PartitionKey` (ou com uma chave de baixa cardinalidade), a distribuição fica desbalanceada ou perde a ordenação por entidade. A chave não é um detalhe: é o instrumento de roteamento e a única garantia de ordem que o Kinesis oferece.

---

⬅️ [Anterior: Stream e shards](1-stream-e-shards.md) · 📑 [Índice](../../index.md) · [Próximo: Ponte Kafka → Kinesis](3-ponte-kafka-kinesis.md) ➡️
