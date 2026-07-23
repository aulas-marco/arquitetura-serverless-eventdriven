# Setup local (LocalStack) — Unidade 2

Os três labs da Unidade 2 têm dois modos de execução: **AWS real** e **LocalStack**. O código e o `template.yaml` são idênticos nos dois — a alternância é por variável de ambiente. Esta página mostra clonar, subir a infra, rodar os testes e implantar cada lab.

---

## Clonar e testar

```bash
git clone https://github.com/aulas-marco/arquitetura-serverless-eventdriven.git
cd arquitetura-serverless-eventdriven

make test-eventstore   # U2-LAB01 — replay determinístico + invariantes
make test-snapshots    # U2-LAB02 — snapshot + delta ≡ replay completo
make test-cqrs         # U2-LAB03 — projeção incremental + idempotência
```

Os testes de unidade não precisam de AWS nem de LocalStack — exercitam o domínio puro. Passe por eles antes de implantar.

---

## Subir o LocalStack

```bash
make up
# LocalStack em http://localhost:4566
```

Ou manualmente:

```bash
docker run -d -p 4566:4566 --name localstack localstack/localstack:3
```

O *pin* `:3` é intencional — a versão da imagem afeta o suporte a DynamoDB Streams. Requer o Docker rodando (no macOS, [Colima](../glossario.md#colima) ou Docker Desktop).

---

## Alternar para o modo local

A alternância é a variável `LOCALSTACK=1`, lida pelo `Makefile`: ele troca `sam`→`samlocal` e `aws`→`awslocal`, que apontam para o *endpoint* `http://localhost:4566`.

| Dimensão | LocalStack | AWS Real |
|----------|-----------|----------|
| Prefixo dos alvos | `LOCALSTACK=1 make ...` | `make ...` |
| CLI | `awslocal` | `aws` |
| SAM | `samlocal` | `sam` |
| `AWS_ENDPOINT_URL` | `http://localhost:4566` | (não definida) |
| Credenciais | `test` / `test` | credenciais reais |

Instale os *wrappers* uma vez, num *virtualenv*:

```bash
pip install awscli-local aws-sam-cli-local
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
awslocal sts get-caller-identity
```

---

## Implantar e rodar cada lab

Em modo AWS real, os *scripts* de demo chamam o `HttpApi` do *stack* via `curl`. Em modo LocalStack, o `HttpApi` é recurso *Pro* — por isso as demos invocam a Lambda diretamente (`awslocal lambda invoke` com um evento sintetizado), sem passar pelo API Gateway.

```bash
# AWS real
make deploy-eventstore && make eventstore     # U2-LAB01
make deploy-snapshots  && make snapshots       # U2-LAB02
make deploy-cqrs       && make cqrs            # U2-LAB03

# LocalStack (mesmos alvos, prefixados)
LOCALSTACK=1 make deploy-eventstore && LOCALSTACK=1 make eventstore
LOCALSTACK=1 make deploy-snapshots  && LOCALSTACK=1 make snapshots
LOCALSTACK=1 make deploy-cqrs       && LOCALSTACK=1 make cqrs
```

---

## Limitação a conhecer (U2-LAB03)

O U2-LAB03 depende de **DynamoDB Streams** disparando o Lambda de projeção. No LocalStack Community, o suporte a Streams é parcial e o *lag* de [consistência eventual](../glossario.md#consistencia-eventual) que a demo ilustra pode não reproduzir como na AWS. Para validar a **lógica** de projeção e idempotência sem depender disso, rode os testes de unidade (`make test-cqrs`) — eles exercitam `projetar` diretamente, sem stream. A demonstração ponta a ponta do *lag* fica melhor em AWS real.

---

## Derrubar

```bash
make down    # para o LocalStack
make clean   # remove os stacks (todos os u2lab*) + artefatos locais
```

---

⬅️ [Anterior: Pré-requisitos](pre-requisitos.md) · 📑 [Índice](../index.md) · [Próximo: Event Sourcing](../01-fundamentos/1-event-sourcing.md) ➡️
