# Como ler o código dos laboratórios da Unidade 3

Esta página é um guia de orientação: onde cada arquivo mora nos três laboratórios da Unidade 3, o que cada função faz, os padrões recorrentes e o que observar antes de entrar nas demos.

> **Pré-requisito:** leia [IA generativa e cache](3-ia-generativa-e-cache.md) antes desta página — os conceitos de *stream*, *shard*, ESM, cache e classificação por LLM são usados diretamente no código dos labs.

---

## Árvore de pastas

```text
arquitetura-serverless-eventdriven/
│
├── lab-u3-01/                          ← produtor Kinesis (roteamento por shard)
│   ├── template.yaml                   ← stream (4 shards) + Lambda produtor + HTTP API
│   ├── src/
│   │   ├── suporte.py                  ← puro: montar_evento, montar_registro, ler_corpo
│   │   └── produtor.py                 ← handler: ler_corpo → put_records → devolve shardIds
│   ├── tests/test_suporte.py
│   └── scripts/publicar-e-rotear.sh
│
├── lab-u3-02/                          ← consumidores Kinesis (ESM, at-least-once)
│   ├── template.yaml                   ← ConsumidorA (PF=4) + ConsumidorB, ambos Bisect=true
│   ├── src/
│   │   ├── suporte.py                  ← puro: decodificar_registro, decodificar_lote
│   │   └── consumidor.py               ← handler: loga shard+clienteId; FalhaIntencional
│   ├── tests/test_suporte.py
│   └── scripts/consumir-e-observar.sh
│
└── lab-u3-03/                          ← classificador IA + cache DynamoDB
    ├── template.yaml                   ← SQS (4 filas) + DynamoDB (TTL) + Lambda classificador
    ├── src/
    │   ├── suporte.py                  ← puro: hash_texto, montar_prompt, parsear_resposta, calcular_ttl
    │   ├── classificador.py            ← handler: cache → API Anthropic → parse → salva → roteia
    │   └── requirements.txt            ← anthropic>=0.49.0
    ├── tests/test_suporte.py
    └── scripts/classificar-e-rotear.sh
```

A separação é a mesma nos três labs: **`suporte.py` é lógica pura** (sem *boto3*, sem *anthropic*, testável offline) e **o *handler* orquestra I/O** (Kinesis, SQS, DynamoDB, API Anthropic). É o mesmo *seam* que os labs das unidades anteriores usam para testar sem AWS.

---

## Responsabilidade de cada função

| Função / Classe | Lab | Responsabilidade |
|---|---|---|
| `montar_evento` | u3-01 | Normaliza o evento cru; exige `clienteId` (chave de roteamento) e `mensagem` |
| `montar_registro` | u3-01 | Monta o registro para `put_records` com `PartitionKey = clienteId` e `Data` em *bytes* |
| `ler_corpo` | u3-01 | Normaliza a entrada: invocação direta (objeto/lista) ou HTTP API (`body` como *string*) |
| `lambda_handler` (produtor) | u3-01 | Lê o corpo, monta os registros, chama `put_records` e devolve `shardId` + `sequenceNumber` de cada registro |
| `decodificar_registro` | u3-02 | Extrai o `shardId` do `eventID` e deserializa o `data` (base64 → JSON) de um registro Kinesis |
| `decodificar_lote` | u3-02 | Decodifica todos os registros de um lote, preservando a ordem |
| `lambda_handler` (consumidor) | u3-02 | Loga `shard` + `clienteId` de cada registro; levanta `FalhaIntencional` se `FALHAR_EM` bater |
| `FalhaIntencional` | u3-02 | Exceção didática que dispara a reentrega do ESM (demonstra at-least-once) |
| `hash_texto` | u3-03 | SHA-256 hex do texto do ticket — chave de cache no DynamoDB |
| `montar_prompt` | u3-03 | Monta o *prompt* que instrui o *Claude Haiku* a responder apenas com JSON |
| `parsear_resposta` | u3-03 | Valida o JSON do LLM; levanta `SemClassificacao` se prioridade/categoria estiverem fora do domínio |
| `calcular_ttl` | u3-03 | *Unix timestamp* de expiração para o campo TTL do DynamoDB |
| `SemClassificacao` | u3-03 | Exceção que roteia o ticket para a fila de não classificados em vez de descartá-lo |
| `lambda_handler` (classificador) | u3-03 | Orquestra: busca cache → chama API → parseia → salva cache → roteia para a fila de prioridade |

---

## Padrões recorrentes

### `put_records` em lote e a PartitionKey (u3-01)

O produtor não publica um registro por vez: monta um lote e chama `put_records` uma vez só. A `PartitionKey` — o `clienteId` — é o que fixa o *shard*:

```python
# produtor.py — lab-u3-01
resposta = kinesis.put_records(
    StreamName=STREAM, Records=[montar_registro(e) for e in eventos]
)

publicados = []
for evento, registro in zip(eventos, resposta["Records"]):
    if "ShardId" in registro:
        publicados.append({
            "clienteId": evento["clienteId"],
            "shardId": registro["ShardId"],
            "sequenceNumber": registro["SequenceNumber"],
        })
```

O `shardId` de destino não é decidido no código — vem na resposta do Kinesis. É a evidência de que o mesmo `clienteId` sempre cai no mesmo *shard*.

### Extrair o shardId do eventID (u3-02)

O ESM entrega cada registro com o `eventID` no formato `shardId-000000000000:sequenceNumber`. A lógica pura extrai o *shard* pela parte antes do `:`:

```python
# suporte.py — lab-u3-02
def decodificar_registro(registro):
    shard_id = registro["eventID"].split(":")[0]
    dados = json.loads(base64.b64decode(registro["kinesis"]["data"]).decode("utf-8"))
    return {"shardId": shard_id, "dados": dados}
```

O `data` do Kinesis chega em base64 — decodificar e desserializar é responsabilidade do consumidor.

### Cache antes da API (u3-03)

O classificador consulta o DynamoDB **antes** de chamar o LLM. Só há chamada paga se o *hash* do texto não estiver no cache:

```python
# classificador.py — lab-u3-03
cache = _buscar_cache(chave)
if cache:
    classificacao = {"prioridade": cache["prioridade"], "categoria": cache["categoria"]}
    origem = "cache"
else:
    try:
        classificacao = _classificar_via_api(texto)
        _salvar_cache(chave, classificacao)
    except SemClassificacao as e:
        print(f"[SEM-CLASSIFICACAO] {e}")
        classificacao = None
    origem = "api"
```

O `origem` (`cache` ou `api`) vai para o *log* — é o que a demo usa para provar que a segunda rodada não chamou a API.

### Chamada ao LLM com JSON estrito (u3-03)

A chamada ao *Claude Haiku* usa o SDK oficial. `max_tokens=64` mantém a resposta curta; o *prompt* força JSON puro:

```python
# classificador.py — lab-u3-03
claude = anthropic.Anthropic()  # lê ANTHROPIC_API_KEY do ambiente

def _classificar_via_api(texto):
    resp = claude.messages.create(
        model="claude-haiku-4-5",
        max_tokens=64,
        messages=[{"role": "user", "content": montar_prompt(texto)}],
    )
    return parsear_resposta(resp.content[0].text)
```

---

## Dependências

| Dependência | u3-01 | u3-02 | u3-03 | Para quê |
|---|:---:|:---:|:---:|---|
| `boto3` | ✓ | | ✓ | Cliente Kinesis (produtor), SQS e DynamoDB (classificador) — vem no *runtime* da Lambda |
| `anthropic` (`>=0.49.0`) | | | ✓ | SDK oficial para chamar o *Claude Haiku* via `messages.create` |
| `pytest` | ✓ | ✓ | ✓ | Testes da lógica pura de `suporte.py` (via *venv* da raiz) |

> **Nota:** o consumidor (u3-02) não importa `boto3` no código — o ESM entrega o lote de registros direto ao `lambda_handler`, e a lógica pura só depende da biblioteca-padrão (`base64`, `json`).

---

## template.yaml por lab

**lab-u3-01** — *stream* de 4 *shards* + produtor atrás de HTTP API:

```yaml
StreamEventos:
  Type: AWS::Kinesis::Stream
  Properties:
    Name: u3lab01-eventos-suporte
    ShardCount: 4
    RetentionPeriodHours: 24
```

**lab-u3-02** — dois consumidores, cada um com seu ESM sobre o mesmo *stream*:

```yaml
Events:
  Kinesis:
    Type: Kinesis
    Properties:
      Stream: !Sub "arn:aws:kinesis:${AWS::Region}:${AWS::AccountId}:stream/${StreamNome}"
      StartingPosition: LATEST
      BatchSize: 10
      ParallelizationFactor: 4          # só no ConsumidorA
      BisectBatchOnFunctionError: true
```

**lab-u3-03** — SQS de entrada, tabela de cache com TTL e a chave da API como parâmetro:

```yaml
TabelaCache:
  Type: AWS::DynamoDB::Table
  Properties:
    TableName: u3lab03-cache-classificacao
    BillingMode: PAY_PER_REQUEST
    TimeToLiveSpecification:
      AttributeName: ttl
      Enabled: true

ClassificadorFunction:
  Properties:
    Environment:
      Variables:
        ANTHROPIC_API_KEY: !Ref AnthropicApiKey   # parâmetro NoEcho
    Events:
      SQS:
        Type: SQS
        Properties:
          Queue: !GetAtt FilaTickets.Arn
          BatchSize: 1
```

> **Nota:** a `ANTHROPIC_API_KEY` é um parâmetro `NoEcho` do *template*, passado no *deploy* a partir da variável de ambiente — nunca commitado no código.

---

## Ciclo dos testes

Os três labs seguem o mesmo padrão: **os testes exercitam só `suporte.py`** (lógica pura), sem AWS e sem API Anthropic.

```python
# conftest.py — idêntico nos três labs
SRC = pathlib.Path(__file__).resolve().parent.parent / "src"
sys.path.insert(0, str(SRC))
```

O `conftest.py` adiciona `src/` ao *path* para importar `suporte`. Cada lab testa o que é seu e testável offline:

- **u3-01** — validação do evento (`clienteId` obrigatório), `PartitionKey` correta, serialização em *bytes*, normalização do corpo (HTTP API vs invocação direta).
- **u3-02** — extração do `shardId` do `eventID`, decodificação base64 → JSON, preservação da ordem no lote.
- **u3-03** — determinismo do *hash*, presença do texto no *prompt*, *parsing* de JSON válido e rejeição (`SemClassificacao`) de JSON inválido ou fora do domínio, cálculo do TTL.

O *shard* de destino (u3-01), a reentrega do ESM (u3-02) e a resposta do LLM (u3-03) **não** são testados offline — dependem de infra real ou da API. É por isso que cada lab tem também um *script* de demo, que exercita esse caminho contra a AWS ou o LocalStack.

---

⬅️ [Anterior: IA generativa e cache](3-ia-generativa-e-cache.md) · 📑 [Índice](../index.md) · [Próximo: Stream e shards](kinesis-e-ia/1-stream-e-shards.md) ➡️
