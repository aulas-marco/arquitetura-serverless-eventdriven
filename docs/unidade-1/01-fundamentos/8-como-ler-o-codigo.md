# Como Ler o Código

> Guia de orientação: onde cada arquivo mora, o que cada padrão recorrente significa e o que observar antes de entrar nos quatro laboratórios da Unidade 1.

## 1. Estrutura do repositório

```
arquitetura-serverless-eventdriven/
│
├── lab-u1-01/   ← Lambda: alô mundo, gatilhos, ciclo de vida, runtimes, SnapStart
│   ├── fundamentos/   ← Python + pytest (identificação de origem do evento)
│   ├── runtimes/      ← python · go · java + medir.sh (comparativo de cold start)
│   ├── snapstart/     ← java com/sem SnapStart
│   └── scripts/       ← disparar-gatilhos.sh · comparar-snapstart.sh
│
├── lab-u1-02/   ← Fan-out SNS + SQS
│   ├── src/           ← publicar.py · consumidor_estoque.py · consumidor_notificacao.py · comum.py
│   ├── template.yaml  ← 1 tópico SNS, 2 filas SQS, 2 assinaturas, 2 Lambdas
│   ├── tests/         ← pytest (duplo envelope SNS→SQS e montagem do evento)
│   └── scripts/       ← publicar-e-observar.sh
│
├── lab-u1-03/   ← Idempotência com Lambda + DynamoDB
│   ├── src/           ← publicar.py · consumidor.py · comum.py
│   ├── template.yaml  ← fila SQS + tabela DynamoDB (TTL) + 2 Lambdas
│   ├── tests/         ← pytest (chave de idempotência, item com TTL, duplicata)
│   └── scripts/       ← enviar-duplicado-e-observar.sh
│
└── lab-u1-04/   ← DLQ e resiliência
    ├── src/           ← publicar.py · consumidor.py · comum.py
    ├── template.yaml  ← fila + DLQ (RedrivePolicy, maxReceiveCount=3) + ReportBatchItemFailures
    ├── tests/         ← pytest (validação do veneno, falha parcial de lote)
    └── scripts/       ← veneno-e-dlq.sh
```

## 2. Padrões recorrentes

**`comum.py` — lógica pura, sem I/O.** Cada lab separa a decisão de negócio (montar evento, validar, calcular a chave de idempotência, montar a resposta de falha parcial) da conversa com a AWS. É `comum.py` que os testes exercitam — por isso o `pytest` roda sem conta AWS nem Docker.

**Handler fino.** `lambda_handler` normaliza a entrada (via `ler_corpo`/`extrair_evento`), delega a `comum.py` e faz o I/O (publicar no SNS, gravar no DynamoDB, devolver `batchItemFailures`). Pouca lógica vive no handler.

**`template.yaml` (SAM).** Toda a topologia é infraestrutura como código: filas, tópicos, tabelas, gatilhos e políticas. Ler o `template.yaml` de um lab é ler a arquitetura dele.

**`scripts/*.sh` — a demonstração.** Cada lab tem um script que exercita o fluxo ponta a ponta. Todos aceitam `LOCALSTACK=1` (ver [Setup local](../00-comece-aqui/setup-local.md)): no modo LocalStack o HttpApi (recurso Pro) é contornado invocando a Lambda diretamente; o comportamento demonstrado é o mesmo.

## 3. O que observar antes de cada lab

| Lab | Foco | Sinal a observar |
|-----|------|------------------|
| U1-LAB01 | ciclo de vida, cold start | `Init Duration` no CloudWatch; ordem Go < Python < Java |
| U1-LAB02 | fan-out | os dois consumidores reagindo ao mesmo pedido |
| U1-LAB03 | idempotência | segunda entrega detectada e descartada (write condicional) |
| U1-LAB04 | DLQ | veneno tentado 3× e movido para a DLQ; bons processados uma vez |

**U1-LAB01 é o único multilíngue** — Python, Java 21 e Go convivem para sustentar o comparativo de cold start. Os demais são Python.

---

⬅️ [Anterior: DLQ e resiliência](7-dlq-e-resiliencia.md) · 📑 [Índice](../index.md) · [Próximo: Modelo FaaS (aprofundamento)](serverless-e-mensageria/1-modelo-faas.md) ➡️
