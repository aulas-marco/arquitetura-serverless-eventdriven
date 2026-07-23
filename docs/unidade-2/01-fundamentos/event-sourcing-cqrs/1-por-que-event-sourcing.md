# Por que Event Sourcing — o problema do CRUD

> **Pré-requisito:** [Setup local](../../00-comece-aqui/setup-local.md) · **Demo:** U2-LAB01 · **Script:** `conta-e-replay.sh`

O modelo CRUD domina a persistência porque resolve bem o caso mais comum: guardar o estado atual de uma entidade. O problema aparece quando o sistema precisa responder não "qual é o estado?" mas "como o estado chegou aqui?". Esta página explica por que o `UPDATE` é uma operação destrutiva, quando essa destruição importa e como o Event Sourcing resolve isso ao persistir fatos em vez de conclusões.

---

## O problema: cada UPDATE apaga história de forma permanente

Considere uma tabela de contas bancárias:

```
contaId | saldo   | atualizadoEm
c-42    | 120.00  | 2026-01-15T08:00:00
```

O valor `120.00` chegou ali após três operações: depósito inicial de R$ 100, depósito de R$ 50, saque de R$ 30. Mas o banco sabe apenas o número final. Os três passos que levaram até ele foram destruídos por `UPDATE`s sucessivos.

A pergunta do auditor — *"qual era o saldo desta conta quando a transferência foi aprovada?"* — não tem resposta. A pergunta do suporte — *"por que o saldo caiu nesta semana?"* — também não. O `UPDATE` sobrescreve; não há desfazer.

## O princípio: persistir fatos, não conclusões

Event Sourcing inverte o modelo: o que se persiste não é o estado resultante, mas a **sequência de fatos de negócio** que o causaram. O estado atual é sempre **derivado** dessa sequência, nunca armazenado diretamente como verdade primária.

O event store é uma tabela append-only: só há `put_item` novo. Nunca `UPDATE`, nunca `DELETE`. A `ConditionExpression="attribute_not_exists(contaId) AND attribute_not_exists(sequencia)"` no DynamoDB rejeita qualquer tentativa de sobrescrever uma posição já ocupada na história — é a mesma garantia que a restrição `UNIQUE(aggregate_id, sequencia)` entrega no Postgres do curso reativo.

```
contaId | sequencia | tipo               | valor / titular      | criadoEm
c-42    |     1     | ContaCriada        | titular="Maria"      | 2026-01-10T09:00:00
c-42    |     2     | DepositoRealizado  | valor=100.00         | 2026-01-10T09:05:00
c-42    |     3     | DepositoRealizado  | valor=50.00          | 2026-01-12T14:30:00
c-42    |     4     | SaqueRealizado     | valor=30.00          | 2026-01-15T08:00:00
```

O saldo `120.00` não aparece nessa tabela. É calculado ao percorrer as linhas 2, 3 e 4 em ordem. A história está intacta; o estado é derivado.

## Eventos de domínio como fatos imutáveis

No lab U2-LAB01, os fatos de negócio são `dict`s com um campo `tipo` no passado e no vocabulário do domínio. Os comandos os produzem, sem tocar no banco:

```python
# comandos.py — fiel ao que está em lab-u2-01
def criar_conta(contaId, titular):
    if not titular:
        raise ComandoInvalido("titular é obrigatório")
    return {"tipo": "ContaCriada", "contaId": contaId, "titular": titular}

def depositar(conta, valor):
    _exigir_positivo(valor)
    return {"tipo": "DepositoRealizado", "contaId": conta.contaId, "valor": valor}
```

O nome de cada tipo está no passado (`ContaCriada`, `DepositoRealizado`), não na operação técnica (`InsertConta`, `UpdateSaldo`). Isso importa: um evento descreve o que aconteceu no mundo do negócio, não o que o sistema fez internamente.

## Gravação: append com proteção contra conflito

Em `app.py` (fiel ao que está em `lab-u2-01`), o método `_append` grava um evento na tabela via *conditional write*. A próxima sequência é `len(eventos) + 1` — calculada sobre os eventos já carregados:

```python
# app.py — fiel ao que está em lab-u2-01
def _append(evento, sequencia):
    item = {**evento, "sequencia": sequencia, "criadoEm": int(time.time())}
    try:
        tabela.put_item(
            Item=item,
            ConditionExpression="attribute_not_exists(contaId) AND attribute_not_exists(sequencia)",
        )
    except ClientError as erro:
        if erro.response["Error"]["Code"] == "ConditionalCheckFailedException":
            raise Conflito(f"conflito de sequência {sequencia} para {evento['contaId']}")
        raise
    return item
```

Se dois comandos concorrentes calcularem a mesma próxima sequência e tentarem gravar ao mesmo tempo, a `ConditionExpression` deixa **um** entrar e rejeita o outro com `ConditionalCheckFailedException`, mapeado para `Conflito` (HTTP 409). A história permanece consistente mesmo sob concorrência.

## Quando usar — e quando não usar

Event Sourcing resolve um problema específico: domínios onde a história importa. Financeiro (auditoria regulatória), jurídico (estado de contratos numa data), seguros (histórico da apólice no sinistro), e-commerce (linha do tempo de um pedido). Nesses contextos, o custo de perder a história é regulatório ou operacional.

Não use quando só o estado atual importa: cadastro de produtos, tabelas de configuração, perfis de usuário sem implicação regulatória. Event Sourcing acrescenta um event store, lógica de replay e, eventualmente, CQRS. Complexidade sem benefício é débito técnico.

A pergunta de diagnóstico é direta: **a história importa aqui?** Se sim, Event Sourcing é candidato. Se não, CRUD é a escolha certa — e é uma boa escolha.

> **Rode agora:** `make deploy-eventstore && make eventstore` — o *script* cria conta, deposita, saca, faz replay e demonstra que regravar a mesma sequência é rejeitado com `ConditionalCheckFailedException`.

---

⬅️ [Anterior: Como ler o código](../3-como-ler-o-codigo.md) · 📑 [Índice](../../index.md) · [Próximo: Estado como sequência](2-estado-como-sequencia.md) ➡️
