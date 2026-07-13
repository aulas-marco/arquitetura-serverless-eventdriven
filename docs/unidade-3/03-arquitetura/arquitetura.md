# Arquitetura — Unidade 3

Visão de arquitetura dos recursos exercitados nos laboratórios da Unidade 3 (Streaming, Consumidores e IA Generativa).

## Contexto (C4 nível 1)

```mermaid
C4Context
    title U3 — Contexto
    Person(aluno, "Aluno", "Publica eventos e envia tickets")
    System_Boundary(aws, "AWS us-east-1") {
        System(api, "HTTP API (U3-LAB01)", "API Gateway + Lambda produtor")
        System(stream, "Kinesis Data Streams", "4 shards, retenção 24h")
        System(consumers, "Consumidores Lambda (U3-LAB02)", "ConsumidorA + ConsumidorB")
        System(classifier, "Classificador Lambda (U3-LAB03)", "SQS + Lambda + DynamoDB")
    }
    System_Ext(anthropic, "Anthropic API", "Claude Haiku — classificação de texto")
    Rel(aluno, api, "POST /eventos array JSON")
    Rel(api, stream, "PutRecords (PartitionKey=clienteId)")
    Rel(stream, consumers, "ESM — lote de registros por shard")
    Rel(aluno, classifier, "SQS send-message (ticket JSON)")
    Rel(classifier, anthropic, "messages.create (cache miss)")
```

## Fluxo do produtor (U3-LAB01)

```mermaid
sequenceDiagram
    participant C as curl
    participant H as ProdutorFunction
    participant K as Kinesis (4 shards)

    C->>H: POST /eventos [{clienteId, mensagem}, ...]
    Note over H: montar_evento (valida campos)
    Note over H: montar_registro (PartitionKey=clienteId)
    H->>K: PutRecords [Records...]
    Note over K: hash(PartitionKey) → shard
    K-->>H: [{ShardId, SequenceNumber}, ...]
    H-->>C: 200 {publicados: [{clienteId, shardId, sequenceNumber}]}
```

## Topologia de shards e consumidores (U3-LAB02)

```mermaid
flowchart TB
    P[Produtor\nu3lab01-produtor] -->|PartitionKey=clienteId| K

    subgraph K [Kinesis u3lab01-eventos-suporte]
        S0[shard-0]
        S1[shard-1]
        S2[shard-2]
        S3[shard-3]
    end

    K -->|ESM\nParallelizationFactor=4\nBisectBatchOnFunctionError=true| A{{ConsumidorA}}
    K -->|ESM\nBisectBatchOnFunctionError=true| B{{ConsumidorB}}

    A --> CWA[(CloudWatch\nconsumidor-a)]
    B --> CWB[(CloudWatch\nconsumidor-b)]
```

Cada seta do stream para o consumidor representa um ESM independente que lê o stream **inteiro** — os eventos não são divididos entre A e B.

## Pipeline do classificador IA (U3-LAB03)

```mermaid
flowchart LR
    IN[SQS\nu3lab03-tickets] -->|BatchSize=1| L{{ClassificadorFunction\nclaude-haiku-4-5}}

    L -->|1 — get_item| D[(DynamoDB\nu3lab03-cache-classificacao\nPK=hash_texto · TTL=ttl)]
    D -->|hit| L
    L -->|miss — 2 — messages.create| API[Anthropic API\nclaude-haiku-4-5]
    API -->|JSON texto| L
    L -->|3 — put_item| D

    L --> QA[SQS\nalta-prioridade]
    L --> QB[SQS\nbaixa-prioridade]
    L --> QS[SQS\nsem-classificacao]
```

## Fluxo de decisão cache/API

```mermaid
flowchart TD
    T[ticket.texto] --> H[hash_texto SHA-256]
    H --> G{DynamoDB\nget_item}
    G -->|hit| R[classificacao do cache]
    G -->|miss| P[montar_prompt]
    P --> A[Anthropic API\nclaude-haiku-4-5]
    A --> V[parsear_resposta]
    V -->|ok| S[salvar cache\nTTL 24h]
    V -->|SemClassificacao| QS[fila sem-classificacao]
    S --> R
    R --> ROT{rotear}
    ROT -->|alta| QA[fila alta-prioridade]
    ROT -->|baixa| QB[fila baixa-prioridade]
```
