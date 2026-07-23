# 2 — Replay e snapshots

## O replay é um fold

Reconstruir o estado é dobrar (*fold*) a sequência de eventos sobre um estado inicial:

```python
estado = ContaBancaria.inicial(contaId)
for evento in eventos_ordenados:
    estado = estado.aplicar(evento)
```

Como `aplicar` é [pura](../glossario.md#funcao-pura) — não toca banco, rede ou relógio —, o replay é **determinístico e idempotente**: reconstruir a mesma sequência duas vezes dá sempre o mesmo estado. Essa é a garantia que sustenta tudo o que vem a seguir.

## O custo do replay cresce com a história

Cada consulta reprocessa **todos** os eventos do agregado desde o começo. Uma conta com 10 eventos: barato. Uma conta com 50 mil eventos (anos de movimentação): cada leitura relê 50 mil eventos. O replay puro não escala com a idade do agregado.

## Snapshot: materializar o estado num ponto

A saída é guardar, de tempos em tempos, o estado já calculado numa dada sequência — o [snapshot](../glossario.md#snapshot). Em vez de reconstruir do zero, a consulta:

1. **Carrega** o snapshot mais recente (estado + `ultimaSequencia`).
2. **Reprocessa só o delta** — os eventos com sequência maior que a do snapshot.
3. Dobra o delta sobre o estado do snapshot.

```python
base = snapshot_para_estado(contaId, snap["estado"])
delta = eventos_com_sequencia_maior_que(snap["ultimaSequencia"])
estado = reconstruir_a_partir_de(base, delta)
```

Um snapshot na sequência 50.000 transforma "reler 50 mil eventos" em "ler um item + reprocessar os poucos posteriores".

## A invariante que não pode quebrar

Snapshot é **otimização**, não fonte da verdade. A regra inegociável: reconstruir via snapshot + delta tem que dar **exatamente** o mesmo estado que o replay completo. Se divergir, o snapshot corrompeu a leitura — pior que não tê-lo. O event store continua sendo a verdade; o snapshot é cache derivado, **descartável e reconstruível** a qualquer momento (basta reprocessar os eventos).

O teste do lab prova isso: para um snapshot tirado em qualquer ponto da sequência, o estado final converge com o replay completo.

## Quando e com que frequência

O snapshot troca espaço e escrita por leitura mais barata. Frequência alta = deltas curtos, mais snapshots gravados. Frequência baixa = menos escrita, deltas maiores. A política comum é "a cada N eventos" ou "a cada X tempo". Como é cache, errar a frequência não afeta a correção — só o desempenho.

## No serverless

Uma segunda tabela [DynamoDB](../glossario.md#dynamodb) (`snapshots`, PK=`contaId`) guarda um item por conta com o estado e a última sequência coberta. A consulta lê o snapshot com `get_item` e o delta com uma `query` de `sequencia > ultimaSequencia`. O [U2-LAB02](../02-demos/u2-02.md) implanta isso e mostra a mesma consulta reprocessando 2 eventos (via snapshot) em vez de 9 (replay completo), com saldo idêntico.

---

⬅️ [Event Sourcing](1-event-sourcing.md) · [Demo: U2-LAB02](../02-demos/u2-02.md) · [CQRS e projeção ➡️](3-cqrs-e-projecao.md)

---

⬅️ [Anterior: Event Sourcing](1-event-sourcing.md) · 📑 [Índice](../index.md) · [Próximo: CQRS e projeção](3-cqrs-e-projecao.md) ➡️
