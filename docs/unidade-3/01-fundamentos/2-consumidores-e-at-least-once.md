# 2 — Consumidores e at-least-once

## Event Source Mapping (ESM)

O Lambda não faz polling manual do stream. O [Event Source Mapping](../glossario.md#event-source-mapping) é o componente gerenciado da AWS que lê o Kinesis em nome do Lambda: mantém o ponteiro de leitura (checkpoint) por shard, agrupa registros em lotes e invoca o Lambda. Quando a invocação termina com sucesso, o checkpoint avança. Se falha, o Lambda é re-invocado com o mesmo lote — **o checkpoint só avança quando o lote inteiro é processado sem erro**.

Por padrão, cada shard gera **uma invocação ativa por vez**: o próximo lote desse shard só sai depois que a invocação atual terminar. Isso preserva a ordenação intra-shard.

## ParallelizationFactor

O [ParallelizationFactor](../glossario.md#parallelization-factor) quebra essa restrição dentro do mesmo shard: com valor `4`, até 4 invocações simultâneas processam subconjuntos distintos do mesmo shard em paralelo. Isso multiplica o throughput por shard sem abrir um novo shard — útil quando o processamento de cada registro é lento (chamada externa, escrita em banco) mas a ordenação estrita intra-shard não é necessária.

É **paralelismo interno**, não fan-out. As 4 invocações consomem partes do mesmo shard; não há duplicação — cada registro vai para exatamente uma das invocações.

## Múltiplos consumidores = fan-out completo

Registrar **dois Lambdas distintos** no mesmo stream via ESMs separados produz um comportamento diferente do ParallelizationFactor: cada Lambda recebe **todos os eventos** do stream de forma independente. É o equivalente de dois [consumer groups](../glossario.md#consumer-group) distintos no Kafka.

```
Stream u3lab01-eventos-suporte
    ├── ESM → ConsumidorA  (recebe 100% dos eventos)
    └── ESM → ConsumidorB  (recebe 100% dos eventos — independente de A)
```

Isso permite que um sistema de analytics e um sistema de alertas consumam o mesmo fluxo sem coordenação. Nenhum dos dois "rouba" eventos do outro.

## At-least-once

O ESM garante que cada registro será entregue **pelo menos uma vez**. Se o Lambda falha antes de retornar com sucesso, o ESM re-invoca com o mesmo lote. Em caso de falhas persistentes, o lote fica bloqueando o avanço do checkpoint — nenhum registro posterior daquele shard é processado enquanto o lote com falha não for resolvido.

As implicações práticas:
- Um mesmo registro pode chegar **mais de uma vez** (falha + retry).
- A ordem de chegada é preservada dentro do shard, mas não entre shards.
- O consumidor deve ser **idempotente**: processar o mesmo registro duas vezes não pode causar efeito duplicado.

## BisectBatchOnFunctionError

Com `BisectBatchOnFunctionError: true`, quando o Lambda lança exceção o ESM divide o lote ao meio e retenta cada metade separadamente. Isso isola o registro problemático: se a falha vem de um único registro inválido, ele acaba num lote de tamanho 1 — onde pode ir para a DLQ ou ser descartado, sem bloquear os demais.

Sem essa opção, o lote inteiro é retentado indefinidamente até que o registro problemático passe ou o período de retenção expire.

## Idempotência como contramedida

At-least-once é o comportamento padrão; exatamente-uma-vez não existe em sistemas distribuídos sem transação distribuída. A contramedida correta é o consumidor ser idempotente: usar uma chave natural (sequenceNumber, eventId) para detectar e descartar duplicatas antes de aplicar o efeito.

## No lab

O [U3-LAB02](../02-demos/u3-02.md) instancia os dois padrões. ConsumidorA usa `ParallelizationFactor: 4`; ConsumidorB não. Ambos leem o mesmo stream e recebem todos os eventos. A segunda parte do script aciona `FalhaIntencional` via variável de ambiente para demonstrar o bisect em ação nos logs do CloudWatch.

---

## Aprofundamento

As páginas a seguir detalham cada mecanismo do consumidor com análise linha a linha do código:

4. [Consumidores via Lambda ESM](kinesis-e-ia/4-consumidores-esm.md) — o Event Source Mapping, o checkpoint por shard e o fan-out por múltiplos ESMs.
5. [ParallelizationFactor e paralelismo](kinesis-e-ia/5-parallelization-factor.md) — paralelismo interno por shard vs fan-out entre consumidores.
6. [At-least-once e BisectBatchOnFunctionError](kinesis-e-ia/6-at-least-once-bisect.md) — a semântica de entrega, o bisect e a idempotência como contramedida.

---

⬅️ [Anterior: Streaming e Kinesis](1-streaming-e-kinesis.md) · 📑 [Índice](../index.md) · [Próximo: IA generativa e cache](3-ia-generativa-e-cache.md) ➡️
