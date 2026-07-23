# Replay determinístico e snapshots como atalho

> **Pré-requisito:** [Estado como sequência](2-estado-como-sequencia.md) · **Demo:** U2-LAB02 · **Script:** `snapshot-e-delta.sh`

A página anterior mostrou que o estado de um agregado é sempre calculado via fold sobre a lista de eventos. O fold é correto e determinístico — mas seu custo cresce linearmente com o número de eventos. Esta página explica por que o replay é determinístico e idempotente, quando esse custo se torna um problema real e como o padrão de snapshot o resolve sem comprometer a integridade do event store.

---

## O problema: o fold puro cresce com o histórico

Para um agregado com poucos eventos, o `reconstruir` do U2-LAB01 é trivial — microssegundos. Para uma conta bancária com anos de uso e dezenas de milhares de lançamentos, percorrer todo o event store antes de cada consulta é inviável. O custo do replay puro é linear: cada novo evento acrescenta uma iteração a toda reconstituição futura.

```
Conta nova       → 10 eventos      → replay em < 1 ms
Conta com 5 anos → 50.000 eventos  → replay relê os 50 mil a cada consulta
```

## O princípio: determinismo garante auditoria; snapshot elimina o custo

**Determinismo** significa que os mesmos eventos, na mesma ordem, sempre produzem o mesmo estado. Isso é o que torna o Event Sourcing auditável e reproduzível: qualquer versão do estado no passado pode ser recalculada relendo os eventos até aquele ponto. `aplicar` é uma função pura sem efeitos colaterais — não toca banco, rede ou relógio —, o que garante essa propriedade.

**Idempotência** do replay decorre do mesmo princípio: rodar o fold duas vezes sobre a mesma sequência produz o mesmo resultado. Isso permite reconstruir projeções destruídas, criar novas visões retroativamente e auditar sem risco de corrupção.

**Snapshot** é a resposta ao custo. Em vez de começar sempre do evento 1, a consulta:

1. Carrega o snapshot mais recente (estado calculado + a `ultimaSequencia` incluída naquele cálculo).
2. Carrega apenas os eventos com `sequencia > ultimaSequencia` — o delta desde o snapshot.
3. Aplica o fold somente sobre o delta.

O event store permanece inalterado e continua sendo a fonte da verdade. O snapshot é uma otimização de leitura gravada numa tabela separada — se for apagado, os eventos ainda permitem reconstruir tudo do zero.

## O replay generalizado no lab U2-LAB02

O U2-LAB02 generaliza o fold para partir de um estado-base qualquer, não só do inicial:

```python
# dominio.py — fiel ao que está em lab-u2-02
def reconstruir_a_partir_de(estado_base, eventos):
    """Com estado_base inicial, é o replay completo. Com o estado de um
    snapshot, processa só os eventos posteriores (o delta)."""
    estado = estado_base
    for evento in eventos:
        estado = estado.aplicar(evento)
    return estado

def reconstruir(contaId, eventos):
    return reconstruir_a_partir_de(ContaBancaria.inicial(contaId), eventos)
```

O snapshot precisa serializar e desserializar o estado do agregado. Duas funções puras fazem esse *round-trip*, preservando o `Decimal`:

```python
# dominio.py — fiel ao que está em lab-u2-02
def estado_para_snapshot(conta):
    return {"titular": conta.titular, "saldo": conta.saldo}

def snapshot_para_estado(contaId, estado):
    return ContaBancaria(contaId, estado["titular"], _dec(estado["saldo"]))
```

## Gravação do snapshot

Gravar um snapshot significa reconstruir o estado atual, capturar a última sequência presente e persistir os dois juntos numa segunda tabela (`snapshots`, PK=`contaId`):

```python
# app.py — fiel ao que está em lab-u2-02
def _gravar_snapshot(contaId):
    eventos = _eventos(contaId)
    if not eventos:
        return _resp(404, {"erro": "conta não encontrada"})
    conta = reconstruir(contaId, eventos)
    ultima = int(eventos[-1]["sequencia"])
    tabela_snapshots.put_item(Item={
        "contaId": contaId,
        "estado": estado_para_snapshot(conta),
        "ultimaSequencia": ultima,
        "criadoEm": int(time.time()),
    })
    return _resp(200, {"contaId": contaId, "snapshotSequencia": ultima, "saldo": _num(conta.saldo)})
```

O snapshot é gravado com `put_item` **sem** `ConditionExpression`: ao contrário do event store, ele sobrescreve deliberadamente o snapshot anterior. Snapshot é cache derivado, não fato histórico — não há concorrência otimística a proteger aqui.

## Reconstituição com delta

A consulta escolhe o caminho: se há snapshot, aplica só o delta; se não há, recai no replay completo:

```python
# app.py — fiel ao que está em lab-u2-02
def _consultar_com_snapshot(contaId):
    snap = tabela_snapshots.get_item(Key={"contaId": contaId}).get("Item")
    if snap:
        base = snapshot_para_estado(contaId, snap["estado"])
        delta = _eventos(contaId, apos_sequencia=int(snap["ultimaSequencia"]))
        conta = reconstruir_a_partir_de(base, delta)
        return conta, {"viaSnapshot": True, "snapshotSequencia": int(snap["ultimaSequencia"]),
                       "eventosReprocessados": len(delta)}
    eventos = _eventos(contaId)
    if not eventos:
        return None, None
    return reconstruir(contaId, eventos), {"viaSnapshot": False, "eventosReprocessados": len(eventos)}
```

O delta é carregado com `Key("sequencia").gt(apos_sequencia)` — estritamente maior. Se um snapshot cobre até a sequência 7, o delta são os eventos 8 em diante. A ausência de snapshot cai no `reconstruir` completo: o event store sempre tem a verdade.

> **Cuidado com o off-by-one:** o filtro do delta é `sequencia > ultimaSequencia` (estritamente maior). Trocar por `>=` reaplicaria o último evento já incluído no snapshot e corromperia o saldo — o exercício 6 da unidade prova isso.

## Tradeoff: quando o snapshot vale a pena

Snapshot adiciona complexidade: uma tabela nova, dois caminhos de consulta e o risco de um `ultimaSequencia` errado corromper a leitura.

A regra prática: **comece sem snapshot**. Implemente o replay puro, meça, e adicione snapshot quando o tempo de reconstituição virar problema mensurável. Para agregados de vida curta — pedidos de e-commerce que fecham em dias — replay puro basta. Para agregados de longa vida com alta frequência — contas bancárias, carteiras — snapshot é necessário.

Como é cache, errar a frequência do snapshot não afeta a correção, só o desempenho: se o snapshot sumir, a consulta cai no replay completo e continua correta.

> **Rode agora:** `make deploy-snapshots && make snapshots` — o *script* acumula 7 eventos, tira um snapshot, adiciona 2 depósitos e compara a consulta via snapshot (reprocessa **2** eventos) com o replay completo (relê os **9**). Os dois chegam ao mesmo saldo — o determinismo do fold.

---

⬅️ [Anterior: Estado como sequência](2-estado-como-sequencia.md) · 📑 [Índice](../../index.md) · [Próximo: CQRS — comando e consulta](4-cqrs-comando-consulta.md) ➡️
