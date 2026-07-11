# Exercícios — Unidade 2

Desafios cirúrgicos sobre os labs da unidade. Cada um: mude algo, observe, explique.

## 1. Reconstruir um estado passado (U2-LAB01)

**Faça:** consulte o log append-only da conta (`aws dynamodb query`) e reconstrua, na mão, o saldo **após o 2º evento** — não o atual.
**Observe:** o event store guarda o suficiente para isso? E um CRUD guardaria?
**Explique:** por que Event Sourcing permite "viajar no tempo" e o estado sobrescrito não.

## 2. Um evento novo (U2-LAB01)

**Faça:** acrescente um evento `TarifaCobrada(valor)` — um `if` em `aplicar` (subtrai) e um comando que o gera. Adicione um teste no `pytest`.
**Observe:** o replay das contas antigas continua funcionando?
**Explique:** por que adicionar um tipo de evento é retrocompatível, desde que `aplicar` conheça os tipos antigos.

## 3. Provar a concorrência otimística (U2-LAB01)

**Faça:** dispare os 5 depósitos paralelos do script algumas vezes até ver um `409`.
**Observe:** o saldo final bate com o número de `200` recebidos? Algum update se perdeu?
**Explique:** o que a chave `(contaId, sequencia)` garante que uma coluna `saldo` com `UPDATE` não garantiria.

## 4. Quebrar o guard append-only (U2-LAB01)

**Faça:** tente gravar direto no DynamoDB (`put-item`) um evento numa sequência que já existe, **sem** a `condition-expression`.
**Observe:** a gravação passa? O que acontece com o replay depois?
**Explique:** por que o *conditional write* é o que sustenta a imutabilidade do event store.

## 5. Float versus Decimal (U2-LAB01)

**Faça:** troque `Decimal` por `float` no domínio e rode o teste `test_dinheiro_sem_imprecisao_de_float`.
**Observe:** o teste quebra? Qual valor aparece?
**Explique:** por que dinheiro nunca deve ser representado em ponto flutuante binário.

## 6. Delta com `>=` em vez de `>` (U2-LAB02)

**Faça:** no handler, troque o filtro do delta de `sequencia > ultimaSequencia` para `>=`. Tire um snapshot e consulte.
**Observe:** o saldo via snapshot ainda bate com o replay completo? Qual evento entra duas vezes?
**Explique:** por que a fronteira do delta precisa ser estritamente maior que a sequência do snapshot.

## 7. Apagar o snapshot (U2-LAB02)

**Faça:** apague o item da tabela `u2lab02-snapshots` (`aws dynamodb delete-item`) e consulte a conta.
**Observe:** a consulta ainda responde? O `viaSnapshot` mudou? O saldo mudou?
**Explique:** por que apagar o snapshot é seguro — o que ele realmente é.

## 8. Política de snapshot (U2-LAB02)

**Cenário:** uma conta recebe milhares de eventos por dia.
**Descreva** duas políticas para decidir quando tirar um snapshot (a cada N eventos; a cada X tempo) e **diferencie** o que cada uma troca (escrita/espaço × tamanho do delta na leitura).

## 9. Ver a consistência eventual (U2-LAB03)

**Faça:** rode `make cqrs` e observe as tentativas de consulta logo após a escrita.
**Observe:** em quantas tentativas a projeção convergiu? O que a consulta devolvia antes disso?
**Explique:** por que a leitura fica momentaneamente atrás da escrita — e o que se ganha em troca desse lag.

## 10. Projeção não idempotente (U2-LAB03)

**Faça:** remova a checagem de `ultimaSequencia` em `projetar` (aplique sempre). Reprocese o mesmo evento (pode simular no `pytest`).
**Observe:** o saldo dobra?
**Explique:** por que a entrega *at-least-once* do stream torna a idempotência obrigatória na projeção.

## 11. Rebuild de uma projeção nova (U2-LAB03)

**Faça:** imagine uma segunda projeção — `movimentacoes` (contagem de eventos por conta) — em vez de saldo.
**Descreva** como o `rebuild` a construiria a partir do mesmo event store, sem tocar no lado de escrita.
**Explique:** por que Event Sourcing permite criar visões novas "do passado" que um CRUD não permitiria.

## 12. Transferência sem atomicidade (U2-LAB03)

**Faça:** troque o `TransactWriteItems` por dois `put_item` sequenciais (saque, depois depósito). Imagine uma falha entre os dois.
**Observe:** o que acontece com o dinheiro?
**Explique:** por que a atomicidade é inegociável numa transferência e o que o `TransactWriteItems` garante.

---

📑 [Índice](index.md) · [Glossário ➡️](glossario.md)
