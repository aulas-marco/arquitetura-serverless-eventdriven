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
├── lab-u3-01/   ← U3-LAB01: produtor Kinesis (roteamento por shard)
│   ├── src/                        ← produtor + lógica pura (Python)
│   ├── tests/                      ← pytest (PartitionKey, serialização)
│   └── scripts/                    ← publicar-e-rotear.sh
├── lab-u3-02/   ← U3-LAB02: consumidores Kinesis (ESM, at-least-once)
│   ├── src/                        ← consumidor + decodificação (Python)
│   ├── tests/                      ← pytest (decodificação de registros)
│   └── scripts/                    ← consumir-e-observar.sh
├── lab-u3-03/   ← U3-LAB03: classificador IA + cache (Lambda + Anthropic)
│   ├── src/                        ← classificador + suporte (Python)
│   ├── tests/                      ← pytest (hash, prompt, parsing JSON, TTL)
│   └── scripts/                    ← classificar-e-rotear.sh
├── lab-u3-kafka/ ← U3-KAFKA: Kafka local em Docker (partições, consumer groups, reentrega)
│   ├── src/                        ← produtor + consumidor + lógica pura (Python)
│   ├── tests/                      ← pytest (validação de evento e regra de falha)
│   └── scripts/                    ← rotear-por-chave.sh · grupos-e-rebalanceamento.sh · reentrega.sh
├── docs/unidade-1/                 ← documentação da Unidade 1 (fundamentos, demos, arquitetura, glossário)
├── docs/unidade-2/                 ← documentação da Unidade 2 (Event Sourcing e CQRS)
├── docs/unidade-3/                 ← documentação da Unidade 3 (streaming, consumidores, IA)
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
| [`lab-u3-01`](lab-u3-01/) | 3 | Produtor Kinesis (roteamento por shard) | Python + SAM · Kinesis | ✅ |
| [`lab-u3-02`](lab-u3-02/) | 3 | Consumidores Kinesis (ESM, at-least-once) | Python + SAM · Kinesis | ✅ |
| [`lab-u3-03`](lab-u3-03/) | 3 | Classificador IA + cache | Python + SAM · SQS · DynamoDB · Anthropic | ✅ |
| [`lab-u3-kafka`](lab-u3-kafka/) | 3 | Kafka local em Docker (partições, consumer groups, reentrega) | Python · Kafka · Docker | ✅ |

## Documentação

Cada unidade tem um portal com trilha ordenada — *comece aqui* → fundamentos → aprofundamento (páginas atômicas) → laboratórios → arquitetura → exercícios → glossário, com rodapé de navegação em cada página:

- [**Unidade 1** — Fundamentos: Serverless, eventos e mensageria](docs/unidade-1/index.md)
- [**Unidade 2** — Event Sourcing e CQRS](docs/unidade-2/index.md)
- [**Unidade 3** — Streaming (Kinesis), consumidores e IA](docs/unidade-3/index.md)

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
make test              # todos os labs (py + go + java)
make test-fundamentos  # U1-LAB01 Partes 1-3 (pytest)
make test-runtimes     # U1-LAB01 Parte 4 (pytest + go test + mvn test)
make test-snapstart    # U1-LAB01 Parte 5 (mvn test)
make test-fanout       # U1-LAB02 fan-out (pytest)
make test-idempotencia # U1-LAB03 idempotência (pytest)
make test-dlq          # U1-LAB04 DLQ e resiliência (pytest)
make test-eventstore   # U2-LAB01 event store (pytest)
make test-snapshots    # U2-LAB02 replay e snapshots (pytest)
make test-cqrs         # U2-LAB03 projeção CQRS (pytest)
make test-produtor     # U3-LAB01 produtor Kinesis (pytest)
make test-consumidor   # U3-LAB02 consumidores Kinesis (pytest)
make test-classificador # U3-LAB03 classificador IA + cache (pytest)
make test-kafka        # U3-KAFKA lógica pura (pytest, sem Docker)

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
make deploy-produtor   # U3-LAB01 — implanta o produtor Kinesis
make produtor          # U3-LAB01 — publica eventos e mostra o roteamento por shard
make deploy-consumidor # U3-LAB02 — implanta os consumidores Kinesis
make consumidor        # U3-LAB02 — dois consumidores + at-least-once
make deploy-classificador # U3-LAB03 — implanta o classificador (exige ANTHROPIC_API_KEY)
make classificador     # U3-LAB03 — classifica tickets e demonstra o cache
make outputs           # outputs dos stacks
make clean             # remove todos os stacks + artefatos locais

# Kafka local — Docker, sem conta AWS
make kafka-up          # sobe o broker Kafka e cria o tópico (4 partições)
make kafka-rotear      # U3-KAFKA — roteamento por chave de partição
make kafka-grupos      # U3-KAFKA — consumer groups e rebalanceamento
make kafka-reentrega   # U3-KAFKA — at-least-once com reentrega
make kafka-down        # derruba o broker e apaga os dados

# LocalStack — roda qualquer lab sem conta AWS (ver seção LocalStack)
make up                # sobe o LocalStack (Community, imagem :3)
LOCALSTACK=1 make deploy-fanout   # implanta no LocalStack em vez da AWS real
LOCALSTACK=1 make fanout          # roda a demo contra o LocalStack
make down              # derruba o LocalStack

make help              # lista todos os alvos
```

## LocalStack (rodar sem conta AWS)

Qualquer lab roda localmente no [LocalStack](https://localstack.cloud) com o prefixo `LOCALSTACK=1` — sem custo e sem credenciais AWS.

Pré-requisitos:

- **Docker** (Docker Desktop ou Colima). No Colima, o socket já resolve pelo padrão `/var/run/docker.sock` (lado da VM); se precisar, exporte `DOCKER_SOCK=$HOME/.colima/default/docker.sock`.
- **AWS CLI v2** e **SAM CLI**: `brew install awscli aws-sam-cli`.
- **Wrappers do LocalStack** no venv: `./.venv/bin/pip install awscli-local aws-sam-cli-local`.

Uso:

```bash
make up                              # sobe o LocalStack (Community, imagem :3)
LOCALSTACK=1 make deploy-eventstore  # implanta o stack no LocalStack
LOCALSTACK=1 make eventstore         # roda a demo contra o LocalStack
make down                            # derruba o LocalStack
```

O mesmo `LOCALSTACK=1` vale para todo `deploy-*` e toda demo.

**Limitação do Community:** *API Gateway (HttpApi) é recurso Pro*. Como os labs entram por HttpApi, no modo LocalStack os scripts invocam a Lambda diretamente (`lambda invoke`) em vez de `curl` — o comportamento demonstrado é o mesmo. Funcionam no Community: Lambda, SNS, SQS, DynamoDB (+ *Streams*) e Kinesis (+ *Event Source Mapping*). Ressalvas: o redrive nativo da SQS (`start-message-move-task`, U1-LAB04) é instável no Community — no modo LocalStack o script faz um redrive equivalente por `receive`/`send`; e o U3-LAB03 provisiona a infra no LocalStack, mas a classificação chama a **Anthropic API real** (exige `ANTHROPIC_API_KEY`).

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
| U3-LAB01 | Python 3.12 · AWS SAM · Lambda · Kinesis Data Streams (shards, PartitionKey) · API Gateway · pytest |
| U3-LAB02 | Python 3.12 · AWS SAM · Lambda · Kinesis (Event Source Mapping) · ParallelizationFactor · BisectBatchOnFunctionError · pytest |
| U3-LAB03 | Python 3.12 · AWS SAM · Lambda · SQS · DynamoDB (cache TTL) · Anthropic Claude Haiku · pytest |
| U3-KAFKA | Python 3 · Apache Kafka 4.2 (KRaft) · Docker Compose · confluent-kafka · consumer groups · pytest |

## Ver também

Os mesmos padrões (fan-out, idempotência, DLQ, Event Sourcing, CQRS) implementados em **Java + Spring**: **[arquiteturas-reativas-event-driven](https://github.com/aulas-marco/arquiteturas-reativas-event-driven)**.

## Aviso sobre datas

Conteúdo de curso fica no ar por anos; preços e versões envelhecem. Números concretos (custo, cold start) trazem data e região de captura — trate-os como ordem de grandeza. Reproduza com `make medir` para os valores atuais.
