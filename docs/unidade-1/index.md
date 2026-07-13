# Unidade 1 — Fundamentos: Serverless, Eventos e Mensageria

Portal da Unidade 1. Aqui o AWS Lambda deixa de ser conceito e vira função implantada, gatilho disparado e número medido no console.

## Trilha

Leia na ordem. Cada peça se apoia na anterior.

| # | Documento | O que cobre |
|---|-----------|-------------|
| 0 | [Pré-requisitos](00-comece-aqui/pre-requisitos.md) | Ferramental e credenciais AWS |
| 0 | [Setup local](00-comece-aqui/setup-local.md) | LocalStack e execução sem conta AWS |
| 1 | [Serverless e o modelo FaaS](01-fundamentos/1-serverless-e-faas.md) | O que é serverless; por que FaaS muda o custo |
| 2 | [Ciclo de vida e cold start](01-fundamentos/2-ciclo-de-vida-e-cold-start.md) | Init/Invoke/Shutdown; partida fria; custo GB·s |
| 3 | [Eventos e gatilhos](01-fundamentos/3-eventos-e-gatilhos.md) | Evento vs comando; as 4 fontes de gatilho |
| 4 | [Runtimes e SnapStart](01-fundamentos/4-runtimes-e-snapstart.md) | Por que a JVM penaliza; como o SnapStart mitiga |
| 5 | [Mensageria e fan-out](01-fundamentos/5-mensageria-e-fanout.md) | SNS vs SQS; por que se combinam; o duplo envelope |
| 6 | [Idempotência e entrega at-least-once](01-fundamentos/6-idempotencia-e-entrega.md) | Por que a duplicata acontece; conditional write; TTL |
| 7 | [DLQ e resiliência](01-fundamentos/7-dlq-e-resiliencia.md) | Mensagem veneno; maxReceiveCount; falha parcial de lote |
| — | [**Demo: U1-LAB01**](02-demos/u1-01.md) | Fundamentos do Lambda, em 5 partes |
| — | [**Demo: U1-LAB02**](02-demos/u1-02.md) | Fan-out com SNS + SQS |
| — | [**Demo: U1-LAB03**](02-demos/u1-03.md) | Idempotência com Lambda + DynamoDB |
| — | [**Demo: U1-LAB04**](02-demos/u1-04.md) | DLQ e resiliência com Lambda |
| — | [Arquitetura da unidade](03-arquitetura/arquitetura.md) | Diagramas de ciclo de vida, gatilhos, fan-out, idempotência e DLQ |
| — | [Exercícios](exercicios.md) | Desafios para fixar |
| — | [Glossário](glossario.md) | Termos e siglas (fonte única) |

## Laboratórios da unidade

| Lab | Título | Estado |
|-----|--------|--------|
| **U1-LAB01** | [Lambda: alô mundo, gatilhos, ciclo de vida e comparativo de runtimes](02-demos/u1-01.md) | ✅ Disponível |
| **U1-LAB02** | [Fan-out com SNS + SQS](02-demos/u1-02.md) | ✅ Disponível |
| **U1-LAB03** | [Idempotência com Lambda + DynamoDB](02-demos/u1-03.md) | ✅ Disponível |
| **U1-LAB04** | [DLQ e resiliência com Lambda](02-demos/u1-04.md) | ✅ Disponível |

## Objetivos de aprendizagem

Ao final desta unidade, você consegue **descrever** o ciclo de vida do Lambda, **diferenciar** evento de comando e as fontes de gatilho, e **identificar** as magnitudes de cold start por runtime.

---

📑 [Voltar ao repositório](../../README.md)
