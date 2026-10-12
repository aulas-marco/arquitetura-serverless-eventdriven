# ES + CQRS combinados — anatomia de uma aplicação

> **Pré-requisito:** [Projeções e consistência eventual](5-projecoes-consistencia-eventual.md) · **Demo:** U2-LAB03 · **Script:** `cqrs-projecao.sh`

Event Sourcing e CQRS são independentes — cada um resolve um problema distinto (história vs. separação leitura/escrita). Combinados, têm sinergia natural: o *event store* já é o fluxo que alimenta as projeções. Esta página descreve a anatomia da aplicação completa do U2-LAB03, camada por camada, e as duas regras de ouro que mantêm a separação honesta.

## 1. As camadas, do comando à consulta

O domínio-fio é a "Conta Bancária" com os comandos depositar, sacar e transferir.

```
  POST /depositos ─▶ Lambda comando ─▶ DynamoDB `eventos` (append-only)
   (comando.py)                              │
                                             │ StreamViewType: NEW_IMAGE
                                             ▼
                              DynamoDB Streams (INSERT)
                                             │
                                             ▼
                          Lambda projeção (projecao.py)
                                             │ put_item idempotente por sequência
                                             ▼
                              DynamoDB `saldos` (modelo de leitura)
                                             ▲
   GET /contas/{id} ─▶ Lambda consulta ──────┘
      (consulta.py)
```

Cada Lambda tem uma responsabilidade única e uma tabela de destino explícita — a separação do CQRS é **física**, não apenas lógica (ver [Como ler o código](../3-como-ler-o-codigo.md)).

## 2. Regra de ouro nº 1 — o comando nunca lê a projeção

`comando.py` reconstrói o agregado lendo a tabela `eventos` com `ConsistentRead=True` e grava o novo evento com a condição de sequência (concorrência otimística). Ele **não** consulta `saldos` — a projeção é eventualmente consistente e não serve de base para decisão de negócio.

```python
conta, eventos = _carregar_conta(contaId)   # lê o event store, não a projeção
evento = depositar(conta, valor)            # valida sobre o estado reconstruído
_append(evento, len(eventos) + 1)           # grava com ConditionExpression de sequência
```

## 3. Regra de ouro nº 2 — a consulta nunca faz replay

`consulta.py` lê uma linha pronta de `saldos` em O(1). Ele **não** conhece eventos nem reconstrói estado sob demanda. O preço é a consistência eventual; o ganho é a leitura barata e independente do volume de eventos do agregado.

## 4. `transferir` — atomicidade entre agregados

A transferência gera dois eventos (`SaqueRealizado` na origem, `DepositoRealizado` no destino) que precisam ser gravados juntos ou não gravados. O lab usa `TransactWriteItems`, cada `Put` guardado pela condição de sequência:

```python
cliente.transact_write_items(TransactItems=[
    {"Put": {"TableName": NOME_TABELA, "Item": _serial(saque),    "ConditionExpression": COND_SEQ}},
    {"Put": {"TableName": NOME_TABELA, "Item": _serial(deposito), "ConditionExpression": COND_SEQ}},
])
```

O DynamoDB Streams entrega os dois `INSERT` à Lambda de projeção, que atualiza `saldos` das duas contas — cada uma no seu tempo.

## 5. Falhas comuns e o rebuild

- Projeção fora do ar: consultas devolvem dados antigos até a Lambda voltar e drenar o *stream*. O event store não é afetado.
- Projeção corrompida ou com novo formato: `rebuild.py` faz um *scan* de `eventos`, agrupa por conta, reconstrói cada agregado e reescreve `saldos`. Prova que a projeção é **derivada e descartável** — o event store é a fonte da verdade.

## 6. Quando combinar (e quando não)

| Situação | ES + CQRS combinados? |
|----------|-----------------------|
| Domínio auditável + leitura de alto volume | Sim — a sinergia paga a complexidade |
| CRUD simples sem auditoria | Não — complexidade sem benefício |
| Precisa de história, leitura trivial | ES sozinho basta |
| Leitura pesada, sem necessidade de história | CQRS sobre CRUD basta |

---

⬅️ [Anterior: Projeções e consistência eventual](5-projecoes-consistencia-eventual.md) · 📑 [Índice](../../index.md) · [Próximo: Referências](7-referencia.md) ➡️
