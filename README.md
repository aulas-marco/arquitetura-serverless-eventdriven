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
├── lab-u2-01/   ← U2-LAB01: event store append-only (Event Sourcing)
│   ├── src/                        ← domínio + comandos (puro) + handler (Python)
│   ├── tests/                      ← pytest (replay determinístico, invariantes)
│   └── scripts/                    ← conta-e-replay.sh
├── lab-u2-02/   ← U2-LAB02: replay e snapshots
│   ├── src/                        ← + snapshot (materializar estado, delta)
│   ├── tests/                      ← pytest (snapshot+delta ≡ replay completo)
│   └── scripts/                    ← snapshot-e-delta.sh
├── lab-u2-03/   ← U2-LAB03: CQRS e projeção (DynamoDB Streams)
│   ├── src/                        ← comando · projeção · consulta · rebuild (Python)
│   ├── tests/                      ← pytest (projeção incremental + idempotência)
│   └── scripts/                    ← cqrs-projecao.sh
├── docs/unidade-1/                 ← documentação da Unidade 1 (fundamentos, demos, arquitetura, glossário)
├── docs/unidade-2/                 ← documentação da Unidade 2 (Event Sourcing e CQRS)
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
| [`lab-u2-01`](lab-u2-01/) | 2 | Event store append-only (Event Sourcing) | Python + SAM · DynamoDB | ✅ |
| [`lab-u2-02`](lab-u2-02/) | 2 | Replay e snapshots | Python + SAM · DynamoDB | ✅ |
| [`lab-u2-03`](lab-u2-03/) | 2 | CQRS e projeção (DynamoDB Streams) | Python + SAM · DynamoDB | ✅ |
| `lab-u3-*` | 3 | Kafka e IA | Python + SAM/Kafka | 🔜 |

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
make test-eventstore   # U2-LAB01 event store (pytest)
make test-snapshots    # U2-LAB02 replay e snapshots (pytest)
make test-cqrs         # U2-LAB03 projeção CQRS (pytest)

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
make deploy-eventstore # U2-LAB01 — implanta o event store DynamoDB
make eventstore        # U2-LAB01 — cria conta, deposita, saca e faz replay
make deploy-snapshots  # U2-LAB02 — implanta o replay com snapshots
make snapshots         # U2-LAB02 — snapshot e reprocessa só o delta
make deploy-cqrs       # U2-LAB03 — implanta o CQRS + projeção via Streams
make cqrs              # U2-LAB03 — escreve, projeta, transfere e faz rebuild
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
| U2-LAB01 | Python 3.12 · AWS SAM · Lambda · DynamoDB (event store, conditional write) · API Gateway · pytest |
| U2-LAB02 | Python 3.12 · AWS SAM · Lambda · DynamoDB (event store + snapshots) · API Gateway · pytest |
| U2-LAB03 | Python 3.12 · AWS SAM · Lambda · DynamoDB Streams · projeção (read-model) · TransactWriteItems · API Gateway · pytest |

## Ver também

Os mesmos padrões (fan-out, idempotência, DLQ, Event Sourcing, CQRS) implementados em **Java + Spring**: **[arquiteturas-reativas-event-driven](https://github.com/aulas-marco/arquiteturas-reativas-event-driven)**.

## Aviso sobre datas

Conteúdo de curso fica no ar por anos; preços e versões envelhecem. Números concretos (custo, cold start) trazem data e região de captura — trate-os como ordem de grandeza. Reproduza com `make medir` para os valores atuais.
