# 3 — Como ler o código

Guia de orientação: onde cada arquivo mora nos três laboratórios da Unidade 2, o que cada padrão recorrente significa, e o que observar antes de entrar nas demos.

---

## 1. Estrutura dos laboratórios

Os três labs são acumulativos: cada um amplia o anterior. O mesmo domínio (`ContaBancaria` e os três eventos) percorre todos eles — muda a infraestrutura serverless ao redor.

```
arquitetura-serverless-eventdriven/
│
├── lab-u2-01/                       ← event store append-only puro
│   ├── template.yaml                ← DynamoDB (PK=contaId, SK=sequencia) + 1 Lambda (4 rotas)
│   ├── src/
│   │   ├── dominio.py               ← puro: ContaBancaria.aplicar, reconstruir (replay)
│   │   ├── comandos.py              ← puro: criar/depositar/sacar — as invariantes
│   │   └── app.py                   ← handler HTTP: carregar → reconstruir → decidir → anexar
│   ├── tests/
│   │   ├── test_dominio.py          ← replay determinístico, Decimal exato
│   │   └── test_comandos.py         ← invariantes (saque a descoberto, valor positivo)
│   └── scripts/conta-e-replay.sh
│
├── lab-u2-02/                       ← adiciona snapshots ao event store
│   ├── template.yaml                ← + tabela snapshots + Lambda (6 rotas)
│   ├── src/
│   │   ├── dominio.py               ← + reconstruir_a_partir_de, (de)serialização de snapshot
│   │   ├── comandos.py              ← idêntico ao U2-LAB01
│   │   └── app.py                   ← + gravar snapshot, consulta via snapshot/delta
│   ├── tests/
│   │   ├── test_snapshots.py        ← snapshot + delta ≡ replay completo
│   │   └── test_comandos.py
│   └── scripts/
│       ├── snapshot-e-delta.sh
│       └── pegadinha-append-only.sh ← por que o append PRECISA de ConditionExpression
│
├── lab-u2-03/                       ← CQRS completo: Streams + projeção + rebuild
│   ├── template.yaml                ← eventos(+Stream) + saldos + 4 Lambdas
│   ├── src/
│   │   ├── dominio.py               ← idêntico ao U2-LAB02
│   │   ├── comandos.py              ← idêntico
│   │   ├── projetar.py              ← puro: projeção incremental idempotente
│   │   ├── comando.py               ← ESCRITA: grava eventos + transferência atômica
│   │   ├── projecao.py              ← gatilho do Stream → tabela saldos
│   │   ├── consulta.py              ← LEITURA: lê só a projeção
│   │   └── rebuild.py               ← reprocessa o store → reescreve a projeção
│   ├── tests/
│   │   ├── test_projecao.py         ← projeção incremental + idempotência
│   │   └── test_comandos.py
│   └── scripts/cqrs-projecao.sh
│
├── Makefile
└── docs/
```

---

## 2. Padrão: separação domínio puro × I/O

Em todos os labs, o domínio é uma camada **sem I/O** (`dominio.py`, `comandos.py`, `projetar.py`) e o handler é a **única** camada que toca o DynamoDB (`app.py`, `comando.py`, `projecao.py`, `consulta.py`, `rebuild.py`). O domínio é testável sem AWS: os `tests/` exercitam replay e invariantes com dicionários de evento, sem subir nada.

```python
# dominio.py — presente nos três labs (função pura)
def aplicar(self, evento):
    tipo = evento["tipo"]
    if tipo == "ContaCriada":       return replace(self, titular=evento["titular"])
    if tipo == "DepositoRealizado": return replace(self, saldo=self.saldo + _dec(evento["valor"]))
    if tipo == "SaqueRealizado":    return replace(self, saldo=self.saldo - _dec(evento["valor"]))
    raise ValueError(f"tipo de evento desconhecido: {tipo}")
```

O evento é um `dict` com pelo menos `tipo`. Campos extras vindos do armazenamento (`sequencia`, `criadoEm`) são ignorados de propósito.

---

## 3. Padrão: event store append-only com ConditionExpression

A tabela `eventos` tem chave composta `(contaId, sequencia)` — `contaId` como *partition key*, `sequencia` como *sort key*. O append-only é imposto pela gravação condicional:

```python
# app.py / comando.py — presente nos três labs
tabela.put_item(
    Item={**evento, "sequencia": sequencia, "criadoEm": int(time.time())},
    ConditionExpression="attribute_not_exists(contaId) AND attribute_not_exists(sequencia)",
)
```

A `ConditionExpression` é o mecanismo concreto do append-only: qualquer tentativa de gravar dois eventos no mesmo par `(contaId, sequencia)` é rejeitada pelo DynamoDB com `ConditionalCheckFailedException`. É a mesma garantia que a restrição `UNIQUE(aggregate_id, sequencia)` entrega no Postgres do curso reativo. O handler traduz esse erro em `Conflito` → HTTP 409.

> **Pegadinha do U2-LAB02:** sem a `ConditionExpression`, `put_item` vira um *upsert* — sobrescreve o evento histórico silenciosamente e corrompe a auditoria. O *script* `pegadinha-append-only.sh` demonstra isso ao vivo.

---

## 4. Padrão: replay como fold

A reconstituição do estado é um *left fold* sobre a lista de eventos ordenada por sequência:

```python
# dominio.py — presente nos três labs
def reconstruir(contaId, eventos):
    estado = ContaBancaria.inicial(contaId)
    for evento in eventos:
        estado = estado.aplicar(evento)
    return estado
```

Os eventos vêm da `query` com `ScanIndexForward=True` — ordem crescente de sequência, que o fold exige para produzir o estado correto. No U2-LAB02, o mesmo padrão aparece com snapshot em `reconstruir_a_partir_de`: parte de um estado-base (o do snapshot) e aplica só o delta (`sequencia > ultimaSequencia`).

---

## 5. Padrão: dinheiro em Decimal, nunca float

Todo valor monetário usa `decimal.Decimal`, convertido via `Decimal(str(x))` para não passar por `float`:

```python
# dominio.py — presente nos três labs
def _dec(x):
    return x if isinstance(x, Decimal) else Decimal(str(x))
```

O DynamoDB armazena números como `Decimal`; o `float` introduziria imprecisão binária (`0.1 + 0.2 = 0.30000000000000004`). O teste `test_dominio.py` fixa `0.3` exato como garantia.

---

## 6. Padrão: projeção idempotente por sequência (U2-LAB03)

O DynamoDB Streams entrega *at-least-once* — pode reentregar um registro. A projeção guarda a `ultimaSequencia` projetada e ignora eventos com sequência menor ou igual:

```python
# projetar.py — lab-u2-03
if linha_atual is not None and seq <= int(linha_atual["ultimaSequencia"]):
    return linha_atual  # já projetado — não reaplica
```

O consumidor do stream (`projecao.py`) compara a linha nova com a atual e só grava se mudou (`if nova is atual: continue`) — reaplicar um evento já projetado não dobra o saldo.

---

## 7. Padrão: transação atômica na transferência (U2-LAB03)

A transferência grava dois eventos em dois agregados — ou os dois, ou nenhum — via `TransactWriteItems`. Um detalhe importante de serialização: o *resource* `boto3.resource(...)` faz *marshaling* automático, mas `transact_write_items` é do *client* low-level e exige os itens já serializados por `TypeSerializer`:

```python
# comando.py — lab-u2-03
cliente = boto3.client("dynamodb")   # client PURO, não resource.meta.client
serializer = TypeSerializer()

cliente.transact_write_items(TransactItems=[
    {"Put": {"TableName": NOME_TABELA, "Item": _serial(saque),    "ConditionExpression": COND_SEQ}},
    {"Put": {"TableName": NOME_TABELA, "Item": _serial(deposito), "ConditionExpression": COND_SEQ}},
])
```

Misturar o *marshaling* do *resource* com o *client* low-level gera o erro `Type mismatch ... expected S actual M` — o item seria serializado duas vezes.

---

## 8. Como rodar os testes

Cada lab tem testes de unidade que rodam **sem AWS**. O `Makefile` cria o *virtualenv* sob demanda.

```bash
make test-eventstore   # U2-LAB01
make test-snapshots    # U2-LAB02
make test-cqrs         # U2-LAB03
```

---

## 9. Como rodar as demos

Cada lab tem um *script* de demonstração que implanta o *stack*, executa uma sequência de operações e imprime o resultado. Requer AWS real ou [LocalStack](../glossario.md#localstack) (`LOCALSTACK=1`).

```bash
make deploy-eventstore && make eventstore     # U2-LAB01
make deploy-snapshots  && make snapshots       # U2-LAB02
make deploy-cqrs       && make cqrs            # U2-LAB03
```

Em modo AWS real, os *scripts* chamam o `HttpApi` via `curl`. Em modo LocalStack, o `HttpApi` é recurso *Pro* — as demos invocam a Lambda diretamente com um evento sintetizado. Ver [Setup local](../00-comece-aqui/setup-local.md).

---

## 10. O que o template.yaml de cada lab declara

| Recurso | U2-LAB01 | U2-LAB02 | U2-LAB03 | Propósito |
|---|:---:|:---:|:---:|---|
| DynamoDB `eventos` (PK+SK) | ✓ | ✓ | ✓ | Event store append-only |
| Lambda + API Gateway (HttpApi) | ✓ | ✓ | ✓ | Rotas de comando e consulta |
| DynamoDB `snapshots` (PK) | | ✓ | | Cache de estado materializado |
| DynamoDB Streams em `eventos` | | | ✓ | Gatilho assíncrono da projeção |
| DynamoDB `saldos` (modelo de leitura) | | | ✓ | Projeção consultada pelo lado de leitura |
| Lambdas separadas (comando/projeção/consulta/rebuild) | | | ✓ | Separação física do CQRS |

**U2-LAB01 tem a menor superfície** — uma tabela, uma Lambda, quatro rotas. Tudo o que vem depois (snapshot, stream, projeção) é acréscimo incremental.

---

⬅️ [Anterior: Replay e snapshots](2-replay-e-snapshots.md) · 📑 [Índice](../index.md) · [Próximo: Por que Event Sourcing](event-sourcing-cqrs/1-por-que-event-sourcing.md) ➡️
