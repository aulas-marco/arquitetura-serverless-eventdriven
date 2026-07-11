# Arquitetura Serverless e Event-Driven — Laboratórios

Repositório de código dos laboratórios da disciplina de pós-graduação **Serverless Computing e Arquiteturas Event-Driven** (PUC Minas / IEC).

Cada laboratório é uma pasta autocontida (`lab-uNvV-slug/`) com seu próprio template SAM e código. A documentação é centralizada em [`docs/`](docs/), por unidade. A interface de linha de comando é o [`Makefile`](Makefile) na raiz.

## Estrutura

```
.
├── lab-u1-01/   ← U1-LAB01: alô mundo, gatilhos, ciclo de vida, runtimes, SnapStart
│   ├── fundamentos/       ← Python + pytest
│   ├── runtimes/            ← Python · Java · Go + medir.sh
│   ├── snapstart/           ← Java com/sem SnapStart
│   └── scripts/                    ← disparar-gatilhos.sh, comparar-snapstart.sh
├── lab-u1-02/   ← U1-LAB02: fan-out com SNS + SQS
│   ├── src/                        ← produtor + 2 consumidores (Python)
│   ├── tests/                      ← pytest (duplo envelope + evento)
│   └── scripts/                    ← publicar-e-observar.sh
├── lab-u1-03/   ← U1-LAB03: idempotência com Lambda + DynamoDB
│   ├── src/                        ← produtor + consumidor idempotente (Python)
│   ├── tests/                      ← pytest (chave, item+TTL, duplicata)
│   └── scripts/                    ← enviar-duplicado-e-observar.sh
├── lab-u1-04/   ← U1-LAB04: DLQ e resiliência
│   ├── src/                        ← produtor + consumidor resiliente (Python)
│   ├── tests/                      ← pytest (validação do veneno, falha parcial)
│   └── scripts/                    ← veneno-e-dlq.sh
├── docs/unidade-1/                 ← documentação da Unidade 1 (fundamentos, demos, arquitetura, glossário)
├── Makefile                        ← interface de comandos
└── README.md
```

## Trilha de laboratórios

| Lab | Unidade | Título | Stack | Estado |
| --- | :-----: | ------ | ----- | ------ |
| [`lab-u1-01`](lab-u1-01/) | 1 | Lambda: alô mundo, gatilhos, ciclo de vida e comparativo de runtimes | Python · Java · Go + SAM | ✅ |
| [`lab-u1-02`](lab-u1-02/) | 1 | Fan-out com SNS + SQS | Python + SAM | ✅ |
| [`lab-u1-03`](lab-u1-03/) | 1 | Idempotência com Lambda + DynamoDB | Python + SAM | ✅ |
| [`lab-u1-04`](lab-u1-04/) | 1 | DLQ e resiliência com Lambda | Python + SAM | ✅ |
| `lab-u2-*`–`u3-*` | 2–3 | Event Sourcing, CQRS, Kafka, IA | Python + SAM/Kafka | 🔜 |

## Pré-requisitos

Confirme as versões na data em que rodar — mudam com frequência.

| Ferramenta | Referência | Verificar |
| ---------- | ---------- | --------- |
| Conta AWS | região `us-east-1` | `aws sts get-caller-identity` |
| AWS CLI | v2 | `aws --version` |
| SAM CLI | recente | `sam --version` |
| Python | 3.12 | `python3 --version` |
| Go | 1.22+ | `go version` |
| Java + Maven | 21 | `java -version` / `mvn -v` |
| Docker | recente | `docker --version` |

Detalhes em [`docs/unidade-1/00-comece-aqui/`](docs/unidade-1/00-comece-aqui/pre-requisitos.md).

## Comandos

```bash
# Testes de unidade — não requerem AWS
make test              # todos (lab-01 + lab-02)
make test-fundamentos  # U1-LAB01 Partes 1-3 (pytest)
make test-runtimes     # U1-LAB01 Parte 4 (pytest + go test + mvn test)
make test-snapstart    # U1-LAB01 Parte 5 (mvn test)
make test-fanout       # U1-LAB02 fan-out (pytest)
make test-idempotencia # U1-LAB03 idempotência (pytest)
make test-dlq          # U1-LAB04 DLQ e resiliência (pytest)

# Nuvem — requerem credenciais AWS
make deploy            # implanta os 3 stacks do U1-LAB01
make invoke-alo        # U1-LAB01 P1 — alô mundo
make gatilhos          # U1-LAB01 P2 — dispara os 4 gatilhos
make invoke-ciclo      # U1-LAB01 P3 — ciclo de vida (3 invocações)
make medir             # U1-LAB01 P4 — comparativo de cold start
make snapstart         # U1-LAB01 P5 — comparativo com/sem SnapStart
make deploy-fanout     # U1-LAB02 — implanta o fan-out SNS+SQS
make fanout            # U1-LAB02 — publica 1 pedido e observa 2 consumidores
make deploy-idem       # U1-LAB03 — implanta a idempotência SQS+DynamoDB
make idem              # U1-LAB03 — envia o mesmo pedido 2x e prova a idempotência
make deploy-dlq        # U1-LAB04 — implanta a DLQ e resiliência
make dlq               # U1-LAB04 — envia lote com veneno e observa a DLQ
make outputs           # outputs dos stacks
make clean             # remove todos os stacks + artefatos locais

# LocalStack (opcional, Partes 1-3)
make up | make down

make help              # lista todos os alvos
```

## Guia rápido por lab

### U1-LAB01 — não precisa de AWS para os testes

Os testes de unidade rodam local (pytest, go test, mvn test), sem conta AWS:

```bash
make test
```

As Partes 1–3 rodam em AWS real **ou** LocalStack; as Partes 4–5 (cold start, SnapStart) só em AWS real. Guia completo: [docs/unidade-1/02-demos/u1-01.md](docs/unidade-1/02-demos/u1-01.md).

## Tecnologias

| Lab | Stack |
| --- | ----- |
| U1-LAB01 | Python 3.12 · Java 21 · Go (provided.al2023) · AWS SAM · Lambda · API Gateway · SQS · S3 · EventBridge · SnapStart · pytest · JUnit 5 |
| U1-LAB02 | Python 3.12 · AWS SAM · Lambda · SNS · SQS · API Gateway · pytest |
| U1-LAB03 | Python 3.12 · AWS SAM · Lambda · SQS · DynamoDB (TTL) · API Gateway · pytest |
| U1-LAB04 | Python 3.12 · AWS SAM · Lambda · SQS · DLQ (redrive) · ReportBatchItemFailures · API Gateway · pytest |

## Relação com a disciplina irmã

Esta disciplina usa **Python + AWS Lambda + SQS**. A disciplina **[Arquitetura Reativa e Event-Driven](https://github.com/aulas-marco/arquiteturas-reativas-event-driven)** cobre os mesmos padrões (fan-out, idempotência, DLQ) com **Java + Spring**.

O padrão é o mesmo. A plataforma é diferente.

## Aviso sobre datas

Conteúdo de curso fica no ar por anos; preços e versões envelhecem. Números concretos (custo, cold start) trazem data e região de captura — trate-os como ordem de grandeza. Reproduza com `make medir` para os valores atuais.
