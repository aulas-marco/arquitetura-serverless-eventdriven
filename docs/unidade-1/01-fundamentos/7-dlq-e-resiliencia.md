# 7 — DLQ e resiliência

## Nem toda falha é duplicata

O U1-LAB03 tratou a mensagem que chega **duas vezes**. Falta o oposto: a mensagem que, por mais que chegue, **nunca** processa. Um pedido com valor negativo, um JSON corrompido, um campo obrigatório ausente. Reprocessar não muda nada — é a mensagem "veneno" (*poison message*).

Sem defesa, o veneno vira um loop: a [SQS](../glossario.md#sqs) reentrega, o consumidor falha, a mensagem volta para a fila, reentrega de novo. A fila trava girando no mesmo erro.

## maxReceiveCount e a DLQ

A saída é dar um **limite de tentativas** e um **destino** para o que estoura o limite. A *redrive policy* da SQS faz as duas coisas:

```yaml
RedrivePolicy:
  deadLetterTargetArn: <ARN da DLQ>
  maxReceiveCount: 3
```

Depois de a mensagem ser recebida `maxReceiveCount` vezes sem ser apagada (ou seja, sem ser processada com sucesso), a SQS a move sozinha para a [DLQ](../glossario.md#dlq) — a *dead-letter queue*. O fluxo principal se livra do veneno; a mensagem fica na DLQ para inspeção, alerta ou reprocessamento manual depois de corrigido o problema.

A DLQ é uma SQS comum. O que a torna "DLQ" é ser o alvo de uma *redrive policy* — e, por convenção, não ter consumidor: seu papel é **reter**, não processar.

## Falha parcial de lote

O Lambda recebe da SQS em **lotes** (`event['Records']`). Por padrão, se o handler levanta uma exceção, o lote **inteiro** é considerado falho e reentregue — inclusive as mensagens que já tinham sido processadas com sucesso. Numa fila com idempotência isso é tolerável; sem ela, é reprocessamento à toa.

`ReportBatchItemFailures` conserta isso. O handler devolve só os identificadores que falharam:

```python
return {"batchItemFailures": [{"itemIdentifier": id_falhado}, ...]}
```

A SQS apaga as mensagens bem-sucedidas e reentrega **apenas** as listadas. Uma mensagem ruim no meio de um lote bom não arrasta as outras de volta.

```
lote [bom, veneno, bom]
   ├─ bom    → sucesso → apagada
   ├─ veneno → falha   → batchItemFailures → reentregue (até virar DLQ)
   └─ bom    → sucesso → apagada
```

## O timeout de visibilidade amarra tudo

Entre uma tentativa e a próxima, a mensagem fica invisível pelo *visibility timeout* da fila. Duas regras práticas:

- **≥ timeout da função** — senão a mensagem reaparece e é entregue a uma segunda invocação enquanto a primeira ainda roda, gerando processamento concorrente da mesma mensagem.
- Curto demais acelera retries mas arrisca o problema acima; longo demais atrasa a chegada à DLQ. No lab, função de 5 s e visibilidade de 10 s deixam as tentativas rápidas e seguras.

## No lab

O [U1-LAB04](../02-demos/u1-04.md) implanta fila principal com *redrive* para uma DLQ (`maxReceiveCount=3`) e um consumidor com `ReportBatchItemFailures`. O script envia um lote com dois pedidos bons e um veneno: os bons são processados uma vez, o veneno é tentado 1 → 2 → 3 e cai na DLQ, de onde o script lê o corpo. Fecha a trilha de resiliência da unidade.

---

⬅️ [Idempotência e entrega](6-idempotencia-e-entrega.md) · [Demo: U1-LAB04 ➡️](../02-demos/u1-04.md)
