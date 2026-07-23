# ParallelizationFactor — paralelismo dentro do shard

> **Pré-requisito:** [Consumidores via ESM](4-consumidores-esm.md) · **Demo:** U3-LAB02 · **Script:** `consumir-e-observar.sh`

Por padrão, o ESM invoca **uma** Lambda por shard de cada vez — para preservar a ordem. O `ParallelizationFactor` afrouxa isso de forma controlada: até 10 invocações concorrentes por shard, mantendo a ordem por *PartitionKey*. Esta página diferencia os dois consumidores do laboratório.

## 1. Dois eixos de escala

- **Número de shards** — escala horizontal do *stream* (mais shards, mais throughput).
- **ParallelizationFactor** — escala vertical do consumo por shard (mais invocações concorrentes lendo o mesmo shard).

```
  shard-2  ──▶ ESM (ParallelizationFactor=4) ──▶ até 4 invocações Lambda concorrentes
                                                  (ordem preservada por PartitionKey)
```

## 2. Os dois consumidores do lab

No `lab-u3-02/template.yaml`:

- **ConsumidorA** — `ParallelizationFactor: 4`: até 4 invocações simultâneas por shard. Absorve picos sem adicionar shards.
- **ConsumidorB** — sem `ParallelizationFactor`: uma invocação por shard por vez (o comportamento padrão).

Ambos processam o *stream* inteiro (são grupos independentes). A diferença é só o paralelismo interno — visível nos *logs* quando o volume sobe.

## 3. A garantia que sobrevive

Mesmo com `ParallelizationFactor > 1`, o Kinesis mantém a ordem **por chave**: todos os registros de um `clienteId` (mesmo shard) são entregues em ordem, porque o particionamento interno respeita a *PartitionKey*. O paralelismo age entre chaves distintas, não dentro de uma.

## 4. Quando aumentar

Suba o `ParallelizationFactor` quando o consumidor está atrás (IteratorAge crescente) mas os shards não estão saturados — é mais barato que reparticionar o *stream*. Se o gargalo é o *throughput* de ingestão, aí sim adicione shards.

---

⬅️ [Anterior: Consumidores via ESM](4-consumidores-esm.md) · 📑 [Índice](../../index.md) · [Próximo: At-least-once e bisect](6-at-least-once-bisect.md) ➡️
