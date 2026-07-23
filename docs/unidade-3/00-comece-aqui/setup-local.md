# Setup local

Neste passo a passo você vai clonar o repositório, rodar os testes de unidade, implantar os três labs e executar as demos — na AWS real ou no LocalStack.

---

## 1. Clonar e rodar os testes

```bash
git clone <url-do-repositório>
cd arquitetura-serverless-eventdriven
```

Os testes de unidade não tocam em AWS nem na API Anthropic — só exercitam a lógica pura de cada lab (`suporte.py`). Rode-os primeiro para confirmar o ambiente:

```bash
make test-produtor       # U3-LAB01 — montagem/validação de evento e registro Kinesis
make test-consumidor     # U3-LAB02 — decodificação de registros Kinesis
make test-classificador  # U3-LAB03 — hash, prompt e parsing da resposta IA
```

Os três alvos usam o `pytest` do *venv* da raiz. Nenhum requer Docker, AWS ou `ANTHROPIC_API_KEY`.

---

## 2. Estrutura do repositório (Unidade 3)

```
arquitetura-serverless-eventdriven/
├── lab-u3-01/          # Produtor Kinesis (roteamento por shard)
│   ├── template.yaml
│   ├── src/            # produtor.py + suporte.py
│   ├── tests/          # pytest (lógica pura)
│   └── scripts/publicar-e-rotear.sh
├── lab-u3-02/          # Consumidores Kinesis (ESM, at-least-once)
│   └── scripts/consumir-e-observar.sh
├── lab-u3-03/          # Classificador IA + cache DynamoDB
│   └── scripts/classificar-e-rotear.sh
├── Makefile            # interface única de comandos
└── docs/               # esta documentação
```

Cada lab é *standalone*: tem seu próprio `template.yaml` e é implantado como um *stack* CloudFormation independente.

---

## 3. Implantar na AWS real

Requer credenciais AWS configuradas (`aws configure`) e Docker em execução para o `sam build`.

```bash
# U3-LAB01 — cria o stream Kinesis + Lambda produtor
make deploy-produtor

# U3-LAB02 — cria os dois consumidores (depende do stream do LAB01)
make deploy-consumidor

# U3-LAB03 — exige a chave da API Anthropic
export ANTHROPIC_API_KEY=sk-ant-...
make deploy-classificador
```

O `make deploy-classificador` falha de propósito se `ANTHROPIC_API_KEY` não estiver exportada — a chave é passada ao *template* como parâmetro `NoEcho`.

Para inspecionar os *outputs* de qualquer *stack*:

```bash
make outputs
```

---

## 4. Rodar as demos

Cada lab tem um *script* que exercita o padrão central e imprime a evidência no terminal:

```bash
make produtor        # U3-LAB01 — publica 7 eventos e mostra o roteamento por shard
make consumidor      # U3-LAB02 — dois consumidores + at-least-once (bisect)
make classificador   # U3-LAB03 — classifica 10 tickets, depois demonstra o cache
```

As demos leem os *outputs* dos *stacks* e os *logs* do CloudWatch. A demo do consumidor inclui pausas (`sleep`) para aguardar o processamento assíncrono — é esperado.

---

## 5. Rodar no LocalStack (sem conta AWS)

Qualquer lab roda localmente no [LocalStack](https://localstack.cloud) com o prefixo `LOCALSTACK=1` — sem custo e sem credenciais AWS.

**Pré-requisitos do LocalStack:**

- Docker em execução.
- *Wrappers* no *venv*: `./.venv/bin/pip install awscli-local aws-sam-cli-local` (fornecem `awslocal` e `samlocal`).

```bash
# Subir o LocalStack (Community, imagem :3)
make up

# Implantar e rodar a demo do produtor no LocalStack
LOCALSTACK=1 make deploy-produtor
LOCALSTACK=1 make produtor

# Derrubar ao terminar
make down
```

O mesmo `LOCALSTACK=1` vale para todo `deploy-*` e toda demo (`produtor`, `consumidor`, `classificador`).

> **Socket do Docker.** O LocalStack precisa do *socket* do Docker para rodar as *Lambdas*. Docker Desktop usa `/var/run/docker.sock` (padrão). No Colima, use `DOCKER_SOCK=$HOME/.colima/default/docker.sock make up`.

### Limitações do LocalStack Community

- **HTTP API (API Gateway) é recurso Pro.** Como o produtor entra por HTTP API, no modo LocalStack os *scripts* invocam a *Lambda* diretamente (`lambda invoke`) em vez de `curl` — o comportamento demonstrado é o mesmo.
- **U3-LAB03 não é totalmente offline.** O LocalStack provisiona a infra do classificador (filas SQS, roteamento, tabela DynamoDB de cache), mas a classificação chama a **API Anthropic real** (*Claude Haiku*). Você ainda precisa de `ANTHROPIC_API_KEY` — não há caminho totalmente local para este lab.

Funcionam no Community: *Lambda*, SQS, DynamoDB (+ *TTL*) e Kinesis (+ *Event Source Mapping*) — que cobrem os U3-LAB01 e U3-LAB02 por completo.

---

## 6. Troubleshooting

### `make deploy-classificador` recusa rodar

Mensagem: *"exporte ANTHROPIC_API_KEY antes de..."*. A chave não está no *shell*. Rode `export ANTHROPIC_API_KEY=sk-ant-...` e tente de novo.

### O consumidor não mostra *logs*

Os *logs* do CloudWatch levam alguns segundos para aparecer. A demo já inclui `sleep` (25s a 45s). Se ainda assim vier vazio, aguarde e rode `make consumidor` de novo — o *stream* retém os eventos por 24h.

### U3-LAB02 falha por *stream* inexistente

O LAB02 depende do *stream* `u3lab01-eventos-suporte` criado pelo LAB01. Rode `make deploy-produtor` antes de `make deploy-consumidor`.

### Limpar tudo

```bash
make clean    # remove todos os stacks + artefatos locais (.aws-sam)
```

---

⬅️ [Anterior: Pré-requisitos](pre-requisitos.md) · 📑 [Índice](../index.md) · [Próximo: Streaming e Kinesis](../01-fundamentos/1-streaming-e-kinesis.md) ➡️
