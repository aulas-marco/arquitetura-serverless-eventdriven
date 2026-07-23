# Pré-requisitos

Antes de rodar qualquer laboratório da Unidade 3, verifique se as ferramentas abaixo estão instaladas. A Unidade 3 constrói sobre as unidades anteriores — se você ainda não passou pela Unidade 2, revise os [pré-requisitos da Unidade 2](../../unidade-2/00-comece-aqui/pre-requisitos.md) primeiro.

---

## Ferramentas necessárias

| Ferramenta | Versão mínima | Para quê |
|---|---|---|
| Python | 3.12 | Runtime das *Lambdas* e do *pytest* (o *template* fixa `python3.12`, arquitetura `arm64`) |
| AWS SAM CLI | recente | `sam build` / `sam deploy` dos três *stacks* |
| AWS CLI | v2 | Publicar eventos, ler *logs*, inspecionar filas e *streams* |
| Docker | recente | `sam build` empacota a *Lambda* em contêiner; também necessário para o LocalStack |
| Git | qualquer | Clonar o repositório |
| Conta AWS **ou** LocalStack | — | Executar os labs na AWS real ou local (ver [Setup local](setup-local.md)) |

> **Chave da Anthropic (só o U3-LAB03).** O classificador chama a API Anthropic (*Claude Haiku*). Você precisa de uma `ANTHROPIC_API_KEY` válida — obtenha em `console.anthropic.com`. Os U3-LAB01 e U3-LAB02 não usam IA e não precisam da chave.

---

## Como verificar cada ferramenta

```bash
# Python 3.12+
python3 --version
# Saída esperada: Python 3.12.x

# AWS SAM CLI
sam --version
# Saída esperada: SAM CLI, version 1.x.x

# AWS CLI v2
aws --version
# Saída esperada: aws-cli/2.x.x ...

# Docker
docker info
# Saída esperada: Server Version: xx.x.x ...
```

Para os testes de unidade (*pytest*), o repositório usa um *venv* na raiz. Confirme que ele existe:

```bash
ls .venv/bin/pytest
```

Se não existir, crie-o:

```bash
python3 -m venv .venv
./.venv/bin/pip install pytest boto3 anthropic
```

---

## Infraestrutura da Unidade 3

Cada lab provisiona seus próprios recursos AWS via *template* SAM. Não há infra compartilhada a subir de antemão — o `sam deploy` cria tudo:

- **U3-LAB01** — um *stream* Kinesis (`u3lab01-eventos-suporte`, 4 *shards*, retenção 24h) e uma *Lambda* produtora atrás de uma HTTP API.
- **U3-LAB02** — dois *Event Source Mappings* que ligam o *stream* do LAB01 a duas *Lambdas* consumidoras. Depende do *stream* criado no LAB01.
- **U3-LAB03** — quatro filas SQS, uma tabela DynamoDB com TTL e a *Lambda* classificadora que chama a API Anthropic.

> **Todos os três labs rodam em AWS real ou no LocalStack.** O modo LocalStack (`LOCALSTACK=1`) dispensa conta AWS e custo — com a ressalva de que o U3-LAB03 provisiona a infra localmente, mas a chamada ao LLM continua sendo à API Anthropic real. Ver [Setup local](setup-local.md).

---

## Conceitos que ajudam (mas não são obrigatórios)

Você vai se sentir mais confortável se já tiver noção de:

- **Mensageria assíncrona** — SQS e SNS (cobertos na Unidade 1).
- **Event Sourcing e CQRS** — como o estado vira sequência de eventos (Unidade 2).
- ***Streaming*** — a diferença entre processar em lote e processar cada evento no instante em que chega.
- **LLM** — a ideia de chamar um modelo de linguagem por API e receber uma resposta em texto.

Não domina todos esses pontos? Tudo bem. Os laboratórios explicam cada peça nova antes de usá-la.

---

📑 [Índice](../index.md) · [Próximo: Setup local](setup-local.md) ➡️
