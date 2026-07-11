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
| — | [**Demo: U1-LAB01**](02-demos/u1-01.md) | O laboratório prático, em 5 partes |
| — | [Arquitetura da unidade](03-arquitetura/arquitetura.md) | Diagramas de ciclo de vida e topologia de gatilhos |
| — | [Exercícios](exercicios.md) | Desafios para fixar |
| — | [Glossário](glossario.md) | Termos e siglas (fonte única) |

## Laboratórios da unidade

| Lab | Título | Estado |
|-----|--------|--------|
| **U1-LAB01** | [Lambda: alô mundo, gatilhos, ciclo de vida e comparativo de runtimes](02-demos/u1-01.md) | ✅ Disponível |
| U1V7 | Lambda + SNS + SQS fan-out | 🔜 |
| U1V8 | Idempotência com Lambda e DynamoDB | 🔜 |
| U1V9 | DLQ e resiliência com Lambda | 🔜 |

## Objetivos de aprendizagem (Bloom)

A unidade opera nos verbos de compreensão aceitos pela FIC (auto-instrucional): **reconhecer, listar, descrever, diferenciar, identificar, explicar**. Ao final, você deve **descrever** o ciclo de vida do Lambda, **diferenciar** evento de comando e as fontes de gatilho, e **identificar** as magnitudes de cold start por runtime.

---

📑 [Voltar ao repositório](../../README.md)
