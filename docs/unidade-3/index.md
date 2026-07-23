# Unidade 3 — Streaming, Consumidores e IA Generativa

Portal da Unidade 3. O foco se desloca de filas discretas (SQS/SNS) para **fluxos contínuos** de eventos com Kinesis Data Streams, e a capacidade de tratamento de eventos ganha uma nova camada: modelos de linguagem que classificam e roteiam sem regras manuais.

## Trilha

Leia na ordem. Cada peça se apoia na anterior.

| # | Documento | O que cobre |
|---|-----------|-------------|
| 1 | [Streaming e Kinesis](01-fundamentos/1-streaming-e-kinesis.md) | Shard, PartitionKey, sequenceNumber — a anatomia do stream |
| 2 | [Consumidores e at-least-once](01-fundamentos/2-consumidores-e-at-least-once.md) | ESM, ParallelizationFactor, BisectBatchOnFunctionError |
| 3 | [IA generativa e cache](01-fundamentos/3-ia-generativa-e-cache.md) | Lambda→Anthropic SDK→SQS; cache DynamoDB com TTL |
| 4 | [Como ler o código](01-fundamentos/3-como-ler-o-codigo.md) | Mapa do repositório e padrões dos três laboratórios |
| ★ | [Aprofundamento: Kinesis e IA](01-fundamentos/kinesis-e-ia/1-stream-e-shards.md) | 10 páginas atômicas — shards, ESM, at-least-once, IA e cache |
| — | [**Demo: U3-LAB01**](02-demos/u3-01.md) | Produtor Kinesis com roteamento por clienteId |
| — | [**Demo: U3-LAB02**](02-demos/u3-02.md) | Dois consumidores independentes e at-least-once |
| — | [**Demo: U3-LAB03**](02-demos/u3-03.md) | Classificador IA com cache DynamoDB |
| — | [Arquitetura da unidade](03-arquitetura/arquitetura.md) | Diagramas de stream, consumidores e pipeline IA |
| — | [Exercícios](exercicios.md) | Desafios para fixar |
| — | [Glossário](glossario.md) | Termos e siglas (fonte única) |

## Laboratórios da unidade

| Lab | Título | Estado |
|-----|--------|--------|
| **U3-LAB01** | [Produtor Kinesis — roteamento por clienteId](02-demos/u3-01.md) | ✅ Disponível |
| **U3-LAB02** | [Consumidores Kinesis e at-least-once](02-demos/u3-02.md) | ✅ Disponível |
| **U3-LAB03** | [Classificador IA + cache DynamoDB](02-demos/u3-03.md) | ✅ Disponível |

## Objetivos de aprendizagem

Ao final desta unidade, você consegue **descrever** a anatomia de um Kinesis Data Stream (shard, PartitionKey, sequenceNumber), **diferenciar** múltiplos consumidores (fan-out completo) de ParallelizationFactor (paralelismo interno por shard), **explicar** at-least-once e BisectBatchOnFunctionError, e **identificar** quando o cache DynamoDB elimina chamadas desnecessárias a um LLM.

## Relação com a Unidade 2

A Unidade 2 tratou o estado como sequência de eventos num event store (Event Sourcing) e separou leitura de escrita com CQRS. A Unidade 3 entra no plano do **transporte**: como eventos chegam em alta taxa, em ordem, e como múltiplos sistemas os consomem sem interferir uns nos outros.

## Relação com a Unidade 1

A Unidade 1 apresentou SQS e SNS como primitivas de mensageria assíncrona. O Kinesis resolve um problema diferente: **ordenação por chave** e **reprocessamento** do histórico — o evento não desaparece ao ser lido, e dois consumidores independentes recebem o mesmo fluxo completo.
