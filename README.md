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
├── docs/unidade-1/                 ← documentação da Unidade 1 (fundamentos, demo, arquitetura, glossário)
├── Makefile                        ← interface de comandos
└── README.md
```

## Trilha de laboratórios

| Lab | Unidade | Título | Stack | Estado |
| --- | :-----: | ------ | ----- | ------ |
| [`lab-u1-01`](lab-u1-01/) | 1 | Lambda: alô mundo, gatilhos, ciclo de vida e comparativo de runtimes | Python · Java · Go + SAM | ✅ |
| `lab-u1v7` | 1 | Lambda + SNS + SQS fan-out | Python + SAM | 🔜 |
| `lab-u1v8` | 1 | Idempotência com Lambda e DynamoDB | Python + SAM | 🔜 |
| `lab-u1v9` | 1 | DLQ e resiliência com Lambda | Python + SAM | 🔜 |
| `lab-u2v7`–`u3v9` | 2–3 | Event Sourcing, CQRS, Kafka, IA | Python + SAM/Kafka | 🔜 |

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
make test              # todos (pytest + go test + mvn test)
make test-fundamentos  # Partes 1-3 (pytest)
make test-runtimes     # Parte 4 (pytest + go test + mvn test)
make test-snapstart    # Parte 5 (mvn test)

# Nuvem — requerem credenciais AWS
make deploy            # implanta os 3 stacks
make invoke-alo        # Parte 1 — alô mundo
make gatilhos          # Parte 2 — dispara os 4 gatilhos
make invoke-ciclo      # Parte 3 — ciclo de vida (3 invocações)
make medir             # Parte 4 — comparativo de cold start
make snapstart         # Parte 5 — comparativo com/sem SnapStart
make outputs           # outputs dos stacks
make clean             # remove os 3 stacks + artefatos locais

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

## Relação com a disciplina irmã

Esta disciplina usa **Python + AWS Lambda + SQS**. A disciplina **[Arquitetura Reativa e Event-Driven](https://github.com/aulas-marco/arquiteturas-reativas-event-driven)** cobre os mesmos padrões (fan-out, idempotência, DLQ) com **Java + Spring**.

O padrão é o mesmo. A plataforma é diferente.

## Aviso sobre datas

Conteúdo de curso fica no ar por anos; preços e versões envelhecem. Números concretos (custo, cold start) trazem data e região de captura — trate-os como ordem de grandeza. Reproduza com `make medir` para os valores atuais.
