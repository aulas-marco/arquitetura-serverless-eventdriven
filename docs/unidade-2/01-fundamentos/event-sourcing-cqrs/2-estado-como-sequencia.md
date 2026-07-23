# Estado como sequência de eventos — o fold do agregado

> **Pré-requisito:** [Por que Event Sourcing](1-por-que-event-sourcing.md) · **Demo:** U2-LAB01 · **Script:** `conta-e-replay.sh`

A página anterior mostrou por que o `UPDATE` é destrutivo e que a solução é persistir fatos em vez de conclusões. Agora a questão é: dado que o estado não está armazenado em lugar nenhum, como calculá-lo? A resposta é um *left fold* — em Python, um laço acumulador (`reduce`) — sobre a sequência de eventos. Esta página explica o modelo mental e mostra como ele está implementado em `dominio.py` do lab U2-LAB01.

---

## O problema: o estado não existe na tabela — precisa ser derivado

No Event Sourcing, o event store guarda apenas fatos:

```
sequencia | tipo               | valor / titular
    1     | ContaCriada        | titular="Maria"
    2     | DepositoRealizado  | valor=100.00
    3     | DepositoRealizado  | valor=50.00
    4     | SaqueRealizado      | valor=30.00
```

O saldo `R$ 120,00` não está em nenhuma coluna. Para sabê-lo, é preciso processar esses quatro eventos na ordem em que ocorreram: começar do zero, somar 100, somar 50, subtrair 30. Essa operação — aplicar uma sequência de transformações sobre um acumulador — tem nome na teoria funcional: **left fold** (ou *reduce*).

```
Fold:
  0  →  0  →  100  →  150  →  120

Saldo atual = R$ 120,00   (calculado, não armazenado)
```

## O princípio: função pura estado + evento → novo estado

A operação de fold precisa de uma função que receba o estado atual e um evento e retorne o próximo estado, sem efeitos colaterais. No lab U2-LAB01, essa função é `ContaBancaria.aplicar`, sobre um `dataclass` congelado (`frozen=True`) que nunca toca no banco:

```python
# dominio.py — fiel ao que está em lab-u2-01
@dataclass(frozen=True)
class ContaBancaria:
    contaId: str
    titular: str
    saldo: Decimal

    @staticmethod
    def inicial(contaId):
        return ContaBancaria(contaId, "", Decimal(0))

    def aplicar(self, evento):
        tipo = evento["tipo"]
        if tipo == "ContaCriada":
            return replace(self, titular=evento["titular"])
        if tipo == "DepositoRealizado":
            return replace(self, saldo=self.saldo + _dec(evento["valor"]))
        if tipo == "SaqueRealizado":
            return replace(self, saldo=self.saldo - _dec(evento["valor"]))
        raise ValueError(f"tipo de evento desconhecido: {tipo}")
```

O `dataclass(frozen=True)` garante imutabilidade: `replace(self, ...)` devolve uma cópia nova a cada aplicação, sem alterar o objeto anterior. Cada `if` trata um tipo de evento; um tipo desconhecido levanta `ValueError` em vez de retornar silenciosamente um estado errado — o discriminador é a chave `tipo`, gravada no append.

## Reconstrução: o fold em `reconstruir`

A reconstrução do estado a partir do event store combina a lista de eventos com o fold de `aplicar`:

```python
# dominio.py — fiel ao que está em lab-u2-01
def reconstruir(contaId, eventos):
    estado = ContaBancaria.inicial(contaId)
    for evento in eventos:
        estado = estado.aplicar(evento)
    return estado
```

O fluxo em três passos:

1. O handler carrega os eventos com `query` e `ScanIndexForward=True` — ordem crescente de sequência.
2. `reconstruir` parte de `ContaBancaria.inicial(contaId)` — uma conta vazia (`saldo = Decimal(0)`).
3. Cada evento é aplicado em ordem; o resultado é o estado atual — sem nunca ter lido uma coluna `saldo`.

Este `reconstruir` é chamado no caminho de escrita, antes de qualquer comando que depende do estado. Em `sacar`, por exemplo, ele reconstrói primeiro para verificar se o saldo é suficiente antes de gravar o `SaqueRealizado`.

## A ordem vem do DynamoDB

O carregamento dos eventos, em `app.py`, ordena pela *sort key* `sequencia`:

```python
# app.py — fiel ao que está em lab-u2-01
def _carregar(contaId):
    resp = tabela.query(
        KeyConditionExpression=Key("contaId").eq(contaId),
        ScanIndexForward=True,  # ordem crescente de sequência: o replay depende disso
    )
    return resp["Items"]
```

`ScanIndexForward=True` é o que garante que o fold receba os eventos na ordem correta. A partição (`contaId`) agrupa todos os eventos de uma conta; a *sort key* (`sequencia`) dá a linha do tempo.

## O que essa abordagem entrega

Dado apenas o event store, qualquer estado passado pode ser recalculado: aplique o fold até o evento de sequência N e obtenha o estado que existia naquele ponto. Se a projeção de leitura for perdida ou precisar de uma nova estrutura, basta reler os eventos e recalcular. O event store é a fonte da verdade; o estado é sempre uma derivada.

Isso tem um custo: o fold percorre todos os eventos do agregado. Para agregados de vida curta com poucas dezenas de eventos, isso é trivial. Para agregados de longa vida com milhares de eventos, o custo cresce — e a próxima página apresenta o padrão que resolve isso: replay determinístico e snapshots como atalho.

> **Rode agora:** `make eventstore` — o *script* executa criar, depositar e sacar, depois consulta por replay e exibe o estado calculado. Compare o saldo com a soma manual das linhas da tabela `eventos`.

---

⬅️ [Anterior: Por que Event Sourcing](1-por-que-event-sourcing.md) · 📑 [Índice](../../index.md) · [Próximo: Replay e snapshots](3-replay-e-snapshots.md) ➡️
