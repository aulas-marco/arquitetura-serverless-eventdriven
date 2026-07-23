# At-least-once e BisectBatchOnFunctionError

> **Pré-requisito:** [ParallelizationFactor](5-parallelization-factor.md) · **Demo:** U3-LAB02 · **Script:** `consumir-e-observar.sh` (Parte 2)

Kinesis + Lambda entrega **at-least-once**: um registro pode ser processado mais de uma vez. Quando uma invocação falha, o ESM não descarta o lote — ele retenta. Esta página mostra como o `BisectBatchOnFunctionError` isola o registro problemático para não travar o shard inteiro.

## 1. O problema do lote que falha

Sem tratamento, se uma Lambda lança exceção ao processar um lote, o ESM retenta o **lote inteiro** — inclusive os registros bons, repetidamente. Como o Kinesis preserva a ordem por shard, um registro venenoso pode **bloquear o shard** até expirar por retenção.

## 2. Bisect — dividir para isolar

Com `BisectBatchOnFunctionError: true`, ao falhar o ESM divide o lote ao meio e retenta cada metade separadamente. Repetindo a divisão, o registro venenoso acaba isolado num lote de tamanho 1, e os bons seguem.

```
  lote [1 2 3 4] falha
        │
        ├─ [1 2] ok
        └─ [3 4] falha
              ├─ [3] ok
              └─ [4] falha isolada  ← veneno isolado, não bloqueia 1,2,3
```

## 3. No laboratório

O `consumidor.py` (`lab-u3-02`) levanta uma exceção proposital quando o `clienteId` casa com a variável `FALHAR_EM`:

```python
if FALHAR_EM and cliente_id == FALHAR_EM:
    raise FalhaIntencional(f"falha intencional para clienteId={cliente_id!r}")
```

A Parte 2 do `consumir-e-observar.sh` seta `FALHAR_EM=cli-002` no ConsumidorA, publica eventos misturando `cli-001` e `cli-002`, e nos *logs* você vê o *bisect* isolando `cli-002` (retentado) enquanto `cli-001` é processado — a mesma mensagem entregue mais de uma vez, sem descarte silencioso.

## 4. Idempotência é responsabilidade sua

At-least-once significa que o consumidor **precisa** ser idempotente (ver a idempotência da Unidade 1). Reprocessar o mesmo registro não pode causar efeito colateral em dobro. O ESM garante que nada se perde; cabe ao código garantir que reprocessar é seguro.

## 5. Observabilidade — IteratorAge

O análogo do *consumer lag* do Kafka é a métrica `IteratorAge` (CloudWatch): quão atrás o consumidor está do fim do shard. Um `IteratorAge` crescente indica consumo mais lento que a ingestão — hora de subir o `ParallelizationFactor` ou investigar falhas em *bisect*.

---

⬅️ [Anterior: ParallelizationFactor](5-parallelization-factor.md) · 📑 [Índice](../../index.md) · [Próximo: IA — casos de uso](7-ia-casos-de-uso.md) ➡️
