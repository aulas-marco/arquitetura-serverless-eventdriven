# Pré-requisitos — Unidade 1

## Ferramental

Confirme as versões na data em que fizer o lab — mudam com frequência.

| Ferramenta | Referência | Verificar | Exigido por |
|------------|-----------|-----------|-------------|
| Conta AWS (`us-east-1`) | — | `aws sts get-caller-identity` | tudo (Partes 4 e 5 só em AWS real) |
| AWS CLI | v2 | `aws --version` | tudo |
| SAM CLI | recente | `sam --version` | tudo |
| Python | 3.12 | `python3 --version` | Partes 1-4 |
| Go | 1.22+ | `go version` | Parte 4 |
| Java | 21 + Maven | `java -version` / `mvn -v` | Partes 4, 5 |
| Docker | recente | `docker --version` | build isolado e LocalStack |

## Instalação (macOS, Homebrew)

```bash
brew install awscli aws-sam-cli go openjdk@21
```

O `openjdk@21` é *keg-only* — o `Makefile` do repositório já aponta o `JAVA_HOME` para ele nos alvos que usam Maven, então você não precisa mexer no seu Java padrão.

## Credenciais AWS

O comando abaixo grava as chaves em `~/.aws/`. Use uma **chave de acesso de usuário IAM** (não a conta root; não login/senha do console):

```bash
aws configure
```

- **Access Key ID** — 20 caracteres, começa com `AKIA` (IAM → Security credentials → Create access key → CLI)
- **Secret Access Key** — 40 caracteres, mostrada uma única vez na criação
- **region**: `us-east-1`
- **output**: `json`

> ⚠️ Evite a conta **root** e nunca versione chaves. Se uma chave vazar, rotacione em IAM → Security credentials.

## Verificação rápida

```bash
aws sts get-caller-identity   # deve mostrar sua conta e ARN
make test                     # roda os testes de unidade (sem AWS)
```

---

⬅️ [Índice da unidade](../index.md) · [Setup local ➡️](setup-local.md)
