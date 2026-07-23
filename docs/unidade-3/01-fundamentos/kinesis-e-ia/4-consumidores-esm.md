# Consumidores via Lambda Event Source Mapping

> **Pré-requisito:** [Ponte Kafka → Kinesis](3-ponte-kafka-kinesis.md) · **Demo:** U3-LAB02 · **Script:** `consumir-e-observar.sh`

No Kinesis serverless não se escreve um laço `poll()`. O *Event Source Mapping* (ESM) é o componente gerenciado que lê o *stream* e invoca uma Lambda com lotes de registros. Esta página mostra como dois Lambdas independentes consomem o mesmo *stream* — cada um recebe tudo, como dois *consumer groups* distintos.

## 1. Dois consumidores, o stream inteiro cada um

```
        stream u3lab01-eventos-suporte
                    │
        ┌───────────┴───────────┐
        ▼                       ▼
  ESM → ConsumidorA        ESM → ConsumidorB
  (recebe TODOS)           (recebe TODOS)
```

Cada ESM mantém sua própria posição de leitura por shard. São dois "grupos" independentes: o que um processa não afeta o outro (`lab-u3-02/template.yaml`, funções `ConsumidorAFunction` e `ConsumidorBFunction`).

## 2. O handler decodifica o lote

O ESM entrega os registros com o `Data` em *base64*. A lógica pura (`lab-u3-02/src/suporte.py`) decodifica cada registro e extrai o `shardId` do `eventID`:

```python
def decodificar_registro(registro):
    shard_id = registro["eventID"].split(":")[0]      # shardId-000...:seq
    dados = json.loads(base64.b64decode(registro["kinesis"]["data"]).decode("utf-8"))
    return {"shardId": shard_id, "dados": dados}
```

O handler (`consumidor.py`) apenas percorre o lote decodificado e loga `shard` + `clienteId` — evidência de qual shard cada consumidor processou.

## 3. Configuração do ESM (SAM)

No `template.yaml`, o gatilho `Type: Kinesis` liga a Lambda ao *stream*:

```yaml
Events:
  Kinesis:
    Type: Kinesis
    Properties:
      Stream: !Sub "arn:aws:kinesis:...:stream/${StreamNome}"
      StartingPosition: LATEST
      BatchSize: 10
      BisectBatchOnFunctionError: true
```

`StartingPosition: LATEST` começa do fim (só eventos novos); `BatchSize: 10` agrupa até 10 registros por invocação. As próximas páginas detalham o paralelismo (`ParallelizationFactor`) e a resiliência (`BisectBatchOnFunctionError`).

## 4. Sem commit manual

Diferente do Kafka, não há `commit()` de offset no código. O ESM avança o iterador por shard automaticamente quando a invocação tem sucesso. O controle de reprocessamento vem do tratamento de erro — próxima página.

---

⬅️ [Anterior: Ponte Kafka → Kinesis](3-ponte-kafka-kinesis.md) · 📑 [Índice](../../index.md) · [Próximo: ParallelizationFactor](5-parallelization-factor.md) ➡️
