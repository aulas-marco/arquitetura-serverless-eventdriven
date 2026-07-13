# Unidade 2 — Event Sourcing e CQRS

Portal da Unidade 2. Aqui o estado deixa de ser uma linha que se sobrescreve e passa a ser uma sequência imutável de eventos — e a leitura se separa da escrita com CQRS. Tudo em Python + AWS serverless (DynamoDB, DynamoDB Streams, Lambda).

## Trilha

Leia na ordem. Cada peça se apoia na anterior.

| # | Documento | O que cobre |
|---|-----------|-------------|
| 1 | [Event Sourcing](01-fundamentos/1-event-sourcing.md) | Gravar fatos, não estado; replay; concorrência otimística |
| 2 | [Replay e snapshots](01-fundamentos/2-replay-e-snapshots.md) | Reconstruir e acelerar com snapshots |
| 3 | [CQRS e projeção](01-fundamentos/3-cqrs-e-projecao.md) | Separar leitura de escrita; projeção via Streams; rebuild |
| — | [**Demo: U2-LAB01**](02-demos/u2-01.md) | Event store append-only no DynamoDB |
| — | [**Demo: U2-LAB02**](02-demos/u2-02.md) | Replay acelerado por snapshots |
| — | [**Demo: U2-LAB03**](02-demos/u2-03.md) | CQRS e projeção via DynamoDB Streams |
| — | [Arquitetura da unidade](03-arquitetura/arquitetura.md) | Diagramas de event store, comando, snapshot e CQRS |
| — | [Exercícios](exercicios.md) | Desafios para fixar |
| — | [Glossário](glossario.md) | Termos e siglas (fonte única) |

## Laboratórios da unidade

| Lab | Título | Estado |
|-----|--------|--------|
| **U2-LAB01** | [Event store append-only](02-demos/u2-01.md) | ✅ Disponível |
| **U2-LAB02** | [Replay e snapshots](02-demos/u2-02.md) | ✅ Disponível |
| **U2-LAB03** | [CQRS e projeção (DynamoDB Streams)](02-demos/u2-03.md) | ✅ Disponível |

## Objetivos de aprendizagem

Ao final desta unidade, você consegue **descrever** Event Sourcing e o replay, **diferenciar** o lado de escrita (comando) do de leitura (consulta) no CQRS, e **explicar** a concorrência otimística e a consistência eventual entre event store e projeção.

## Relação com a Unidade 1

A Unidade 1 tratou o Lambda como função e os padrões de mensageria (fan-out, idempotência, DLQ). A Unidade 2 sobe uma camada: como **modelar o estado** de um agregado com eventos e como escalar a leitura separando-a da escrita.

## Ver também

Os mesmos padrões (Event Sourcing, CQRS, conta bancária) implementados em Java + Spring + Kafka: **[arquiteturas-reativas-event-driven](https://github.com/aulas-marco/arquiteturas-reativas-event-driven)**.

---

📑 [Voltar ao repositório](../../README.md)
