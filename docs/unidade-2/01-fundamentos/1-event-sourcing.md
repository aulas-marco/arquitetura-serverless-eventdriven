# 1 — Event Sourcing

## O CRUD apaga a história

No modelo tradicional, o estado é uma linha que se sobrescreve. `UPDATE contas SET saldo = 120 WHERE id = 'c-1'`. Depois desse comando, **como a conta chegou a 120 é irrecuperável** — o valor anterior foi por cima. Um depósito seguido de um saque e o CRUD guarda só o número final. Auditoria, "por que o saldo está assim?", desfazer uma operação: tudo fica difícil ou impossível.

## Gravar o fato, não o resultado

Event Sourcing inverte isso: em vez de sobrescrever estado, você **anexa eventos** — fatos imutáveis, no passado. Não `saldo = 120`, mas a sequência:

```
1. ContaCriada(titular="Maria")
2. DepositoRealizado(valor=100)
3. DepositoRealizado(valor=50)
4. SaqueRealizado(valor=30)
```

O saldo (120) não é armazenado em lugar nenhum. Ele é **derivado** aplicando os eventos em ordem. O event store é [append-only](../glossario.md#append-only): eventos entram, nada é atualizado ou apagado.

## Reconstruir por replay

O estado atual é o resultado de dobrar (*reduce*) a sequência de eventos, começando do zero:

```python
estado = ContaBancaria.inicial(contaId)
for evento in eventos_ordenados:
    estado = estado.aplicar(evento)
```

`aplicar` é uma [função pura](../glossario.md#funcao-pura) — estado + evento → novo estado, sem tocar em banco. Isso é o [replay](../glossario.md#replay). Como a mesma sequência sempre produz o mesmo estado, o replay é determinístico: reconstruir a conta hoje ou daqui a um ano dá o mesmo resultado, e você pode reconstruir **qualquer estado passado** parando o replay no evento que quiser.

## O comando: decidir antes de anexar

Nem todo comando vira evento. Sacar exige saldo suficiente. O fluxo de escrita é sempre o mesmo:

1. **Carregar** os eventos da conta.
2. **Reconstruir** o estado atual (replay).
3. **Decidir**: o comando é válido? Aplica a invariante (ex.: não pode ficar negativo).
4. **Anexar** o novo evento — ou recusar.

As regras de negócio moram no passo 3, sobre o estado reconstruído. O evento só é gravado se a decisão passar.

## Concorrência otimística

Dois comandos simultâneos na mesma conta leem o mesmo estado e tentam anexar o **mesmo próximo número de sequência**. Sem defesa, um sobrescreveria o outro — *lost update*. A defesa é a chave composta `(contaId, sequencia)` com [gravação condicional](../glossario.md#concorrencia-otimista): anexar a sequência N só passa se ninguém já gravou N. O perdedor recebe um conflito e repete o comando (recarrega, redecide). Ninguém trava um registro; assume-se que conflito é raro e resolve-se quando acontece — daí "otimística".

## No serverless

O [DynamoDB](../glossario.md#dynamodb) é o event store natural: a chave de partição é o `contaId`, a chave de ordenação é a `sequencia`, e o *conditional write* dá a concorrência otimística de graça. O [U2-LAB01](../02-demos/u2-01.md) implanta exatamente isso e mostra o log append-only crescendo, o saldo sempre reconstruído por replay, o saque a descoberto recusado e o conflito de sequência virando HTTP 409.

---

📑 [Índice da Unidade 2](../index.md) · [Demo: U2-LAB01](../02-demos/u2-01.md) · [Replay e snapshots ➡️](2-replay-e-snapshots.md)
