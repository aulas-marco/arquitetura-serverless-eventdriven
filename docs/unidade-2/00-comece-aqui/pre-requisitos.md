# Pré-requisitos — Unidade 2

Ferramental necessário para os três laboratórios da Unidade 2 (Event Sourcing e CQRS) e como verificar cada item. Todos os labs são Python + AWS serverless (DynamoDB, DynamoDB Streams, Lambda) — não há Go nem Java nesta unidade.

---

## Ferramental

Confirme as versões na data em que fizer o lab — mudam com frequência.

| Ferramenta | Referência | Verificar | Exigido por |
|------------|-----------|-----------|-------------|
| Python | 3.12 | `python3 --version` | os três labs (domínio, testes, handlers) |
| Docker | recente | `docker --version` | *build* isolado do SAM e [LocalStack](../glossario.md#localstack) |
| AWS CLI | v2 | `aws --version` | implantar e inspecionar tabelas/streams |
| SAM CLI | recente | `sam --version` | empacotar e implantar os *stacks* |
| Conta AWS (`us-east-1`) | — | `aws sts get-caller-identity` | modo AWS real (DynamoDB Streams exige AWS ou LocalStack Pro) |

O modo **LocalStack** roda os labs sem conta AWS — ver [Setup local](setup-local.md). Para o U2-LAB03 (CQRS via Streams), o LocalStack Community tem limitações que a página de setup detalha.

---

## Instalação (macOS, Homebrew)

```bash
brew install awscli aws-sam-cli
```

O Python 3.12 costuma já vir no macOS ou pelo `brew install python@3.12`. Os testes de unidade rodam num *virtualenv* que o `Makefile` cria sob demanda.

---

## Credenciais AWS (modo AWS real)

O comando abaixo grava as chaves em `~/.aws/`. Use uma **chave de acesso de usuário IAM** (não a conta *root*; não login/senha do console):

```bash
aws configure
```

- **Access Key ID** — 20 caracteres, começa com `AKIA` (IAM → *Security credentials* → *Create access key* → CLI)
- **Secret Access Key** — 40 caracteres, mostrada uma única vez na criação
- **region**: `us-east-1`
- **output**: `json`

> ⚠️ Evite a conta **root** e nunca versione chaves. Se uma chave vazar, rotacione em IAM → *Security credentials*.

---

## Verificação rápida

```bash
aws sts get-caller-identity   # modo AWS real: deve mostrar sua conta e ARN
make test-eventstore          # roda os testes do U2-LAB01 (sem AWS)
make test-snapshots           # testes do U2-LAB02
make test-cqrs                # testes do U2-LAB03
```

Os testes de unidade não tocam a AWS — exercitam o domínio puro (replay determinístico, invariantes, projeção idempotente). Passam antes de qualquer implantação.

---

⬅️ [Índice da Unidade 2](../index.md) · 📑 [Índice](../index.md) · [Próximo: Setup local](setup-local.md) ➡️
